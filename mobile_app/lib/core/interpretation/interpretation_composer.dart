import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 託宣文の合成器（オフライン用）。
///
/// サーバーの `src/oracle_app/services/interpretation_engine.py` と
/// **同じマスタ・同じ手順・同じ出力**になるよう移植した実装。
/// 素材の単一真実源は `DB/*.xlsx` で、同梱物は
/// `assets/interpretation_content.json`（`scripts/export_master_assets.py` が書き出す）。
///
/// 合成は3層:
///   素材層 … カードのテーマ別解釈・基本的意味・4系キーワード・組み合わせルール
///   構成層 … 相談内容→質問タイプ分類でジャンル/状況/トーンを判定し、
///            スプレッドのポジションで段落順を決める
///   文体層 … 接続表現マスタで段落を繋ぎ、体言止めの素材を文章体へ整える
///
/// サーバーとの差分が出ると同じ引きで文章が変わってしまうため、
/// 変更時は必ず両実装を同時に直し、`test/interpretation_parity_test.dart` で突き合わせる。
class InterpretationComposer {
  InterpretationComposer._(this._content);

  static const String _assetPath = 'assets/interpretation_content.json';
  static const String _fallbackGenre = '全般';
  static const String _fallbackTone = '中立トーン';

  static InterpretationComposer? _instance;

  final Map<String, dynamic> _content;

  Map<String, dynamic>? _cardById(String cardId) {
    for (final raw in (_content['cards'] as List<dynamic>? ?? const [])) {
      final card = raw as Map<String, dynamic>;
      if (card['card_id'] == cardId) {
        return card;
      }
    }
    return null;
  }

  /// 同梱素材を読み込む（初回のみ）。素材が無い環境ではnullを返す＝呼び出し側は従来表示へ。
  static Future<InterpretationComposer?> load() async {
    if (_instance != null) {
      return _instance;
    }
    try {
      final raw = await rootBundle.loadString(_assetPath);
      _instance = InterpretationComposer._(
        json.decode(raw) as Map<String, dynamic>,
      );
      return _instance;
    } catch (_) {
      return null;
    }
  }

  /// スプレッド定義の一覧（同梱素材から）。素材が無ければ空。
  static Future<List<Map<String, dynamic>>> loadSpreads() async {
    final composer = await load();
    if (composer == null) {
      return const [];
    }
    return (composer._content['spreads'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
  }

  /// 1件のスプレッド定義。未定義はnull。
  static Future<Map<String, dynamic>?> spreadFor(String spreadId) async {
    for (final spread in await loadSpreads()) {
      if (spread['spread_id'] == spreadId) {
        return spread;
      }
    }
    return null;
  }

  /// テスト用（同梱素材を使わずに構築する）。
  static InterpretationComposer forContent(Map<String, dynamic> content) =>
      InterpretationComposer._(content);

  // ---------------------------------------------------------------- 構成層
  int _stableHash(List<String> parts) {
    final digest = md5.convert(utf8.encode(parts.join('|'))).toString();
    return int.parse(digest.substring(0, 8), radix: 16);
  }

  String _genreForTheme(String themeId) {
    final genres = _content['theme_genres'] as Map<String, dynamic>? ?? const {};
    final genre = genres[themeId] as String?;
    return (genre == null || genre.isEmpty) ? _fallbackGenre : genre;
  }

  List<Map<String, dynamic>> get _questionTypes {
    final list = (_content['question_types'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    list.sort((a, b) {
      final pa = (a['priority'] as num?)?.toInt() ?? 999;
      final pb = (b['priority'] as num?)?.toInt() ?? 999;
      return pa.compareTo(pb);
    });
    return list;
  }

  Map<String, dynamic>? _toneByLabel(String label) {
    final primary = label.split('+').first.trim();
    final tones = (_content['tones'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (primary.isNotEmpty) {
      for (final tone in tones) {
        final name = tone['name'] as String? ?? '';
        if (name.startsWith(primary)) {
          return tone;
        }
      }
    }
    for (final tone in tones) {
      if (tone['name'] == _fallbackTone) {
        return tone;
      }
    }
    return null;
  }

  Map<String, dynamic>? _toneForGenre(String genre) {
    for (final entry in _questionTypes) {
      final entryGenre = entry['genre'] as String? ?? '';
      if (genre.isNotEmpty && entryGenre.contains(genre)) {
        return _toneByLabel(entry['tone'] as String? ?? '');
      }
    }
    return _toneByLabel('');
  }

  /// (ジャンル, 状況, トーン)。相談内容が無ければ状況はnull（呼び出し側が日替わりで選ぶ）。
  (String, String?, Map<String, dynamic>?) _classify(
    String? questionText,
    String themeId,
  ) {
    final themeGenre = _genreForTheme(themeId);
    final question = (questionText ?? '').trim();
    if (question.isNotEmpty) {
      int? bestScore;
      Map<String, dynamic>? best;
      for (final entry in _questionTypes) {
        final keywords =
            (entry['keywords'] as List<dynamic>? ?? const []).cast<String>();
        var hits = 0;
        for (final keyword in keywords) {
          if (keyword.isNotEmpty && question.contains(keyword)) {
            hits += 1;
          }
        }
        if (hits == 0) {
          continue;
        }
        final score = hits * 2 + (entry['genre'] == themeGenre ? 1 : 0);
        if (bestScore == null || score > bestScore) {
          bestScore = score;
          best = entry;
        }
      }
      if (best != null) {
        final situations =
            (best['situations'] as List<dynamic>? ?? const []).cast<String>();
        final situation = situations.isNotEmpty
            ? situations.first
            : best['situation'] as String?;
        final genre = best['genre'] as String?;
        return (
          (genre == null || genre.isEmpty) ? themeGenre : genre,
          (situation == null || situation.isEmpty) ? null : situation,
          _toneByLabel(best['tone'] as String? ?? ''),
        );
      }
    }
    return (themeGenre, null, _toneForGenre(themeGenre));
  }

  List<Map<String, dynamic>> positionsFor(String spreadId, int cardCount) {
    final all = _content['positions'] as Map<String, dynamic>? ?? const {};
    final defined = ((all[spreadId] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .toList();
    if (defined.length >= cardCount) {
      return defined.sublist(0, cardCount);
    }
    for (var index = defined.length; index < cardCount; index++) {
      defined.add({
        'index': index + 1,
        'name': '${index + 1}枚目',
        'meaning': '問いに寄せられたメッセージ',
        'role': '展開として補足を述べる',
      });
    }
    return defined;
  }

  // ---------------------------------------------------------------- 文体層
  /// 体言止めの列挙（「A。B。C。」）を、文へ埋め込める句（「A、B、C」）にする。
  static String asPhrase(String text) {
    final cleaned = text.trim().replaceAll(RegExp(r'[。．]\s*$'), '');
    return cleaned.replaceAll(RegExp(r'[。．]\s*'), '、').replaceAll(
          RegExp(r'、+$'),
          '',
        );
  }

  Map<String, dynamic> _connector(Map<String, dynamic>? tone) {
    final name = tone?['name'] as String? ?? _fallbackTone;
    final connectors = (_content['connectors'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final item in connectors) {
      if (item['tone'] == name) {
        return item;
      }
    }
    for (final item in connectors) {
      if (item['tone'] == _fallbackTone) {
        return item;
      }
    }
    return const {};
  }

  String _fillPlaceholders(String template, Map<String, dynamic> card) {
    final dictionary = card['keyword_dict'] as Map<String, dynamic>? ?? const {};
    List<String> pick(String key) =>
        (dictionary[key] as List<dynamic>? ?? const []).cast<String>();
    final keywords = (card['keywords'] as List<dynamic>? ?? const []).cast<String>();
    final values = <String, String>{
      '神名': card['name_ja'] as String? ?? '',
      '基本的意味': asPhrase(card['basic_meaning'] as String? ?? ''),
      'キーワード': keywords.isNotEmpty
          ? keywords.take(2).join('・')
          : (card['basic_meaning'] as String? ?? ''),
      '肯定的キーワード': pick('positive').take(2).join('・'),
      '否定的キーワード': pick('negative').take(2).join('・'),
      '中立的キーワード': pick('neutral').take(2).join('・'),
      '行動提案ワード': pick('action').take(2).join('・'),
    };
    var text = template;
    values.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });
    return text;
  }

  String _actionSentence(Map<String, dynamic> card, int seed) {
    final dictionary = card['keyword_dict'] as Map<String, dynamic>? ?? const {};
    final actions =
        (dictionary['action'] as List<dynamic>? ?? const []).cast<String>();
    if (actions.isEmpty) {
      return '';
    }
    return 'アドバイス：${actions[seed % actions.length]}ことを意識してみてください。';
  }

  String _cardParagraph(
    Map<String, dynamic> card,
    String themeId,
    Map<String, dynamic>? position,
    bool single,
  ) {
    final meanings = card['theme_meanings'] as Map<String, dynamic>? ?? const {};
    final meaning = (meanings[themeId] as String?) ??
        (card['basic_meaning'] as String? ?? '');
    final phrase = asPhrase(meaning);
    final name = card['name_ja'] as String? ?? '';
    if (single || position == null) {
      return '$nameは、$phrase、といった意味を帯びています。';
    }
    return '【${position['name'] ?? ''}】$name。'
        '${position['meaning'] ?? ''}には、$phrase、という意味合いが示されています。';
  }

  // ---------------------------------------------------------------- 合成
  /// 1枚〜N枚の託宣文を合成する。素材不足時は [fallbackText] を返す（fail-soft）。
  String composeReading({
    required List<String> cardIds,
    required String themeId,
    required String dateKey,
    required String sessionId,
    required String fallbackText,
    String spreadId = 'daily',
    String? questionText,
  }) {
    final cards = <Map<String, dynamic>>[];
    for (final cardId in cardIds) {
      final card = _cardById(cardId);
      if (card != null) {
        cards.add(card);
      }
    }
    if (cards.isEmpty) {
      return fallbackText;
    }

    final (genre, situation, tone) = _classify(questionText, themeId);
    final connector = _connector(tone);
    final positions = positionsFor(spreadId, cards.length);
    final single = cards.length == 1;
    final paragraphs = <String>[];

    final opening = connector['opening'] as String? ?? '';
    final question = (questionText ?? '').trim();
    if (opening.isNotEmpty) {
      if (question.isNotEmpty) {
        final summary =
            question.length <= 40 ? question : '${question.substring(0, 40)}…';
        paragraphs.add('「$summary」という問いに、$opening、次の流れです。');
      } else {
        paragraphs.add('$opening、次の流れです。');
      }
    }

    for (var index = 0; index < cards.length; index++) {
      final position = index < positions.length ? positions[index] : null;
      paragraphs.add(_cardParagraph(cards[index], themeId, position, single));
    }

    if (cards.length >= 2) {
      final combination = composeCombination(
        cards.first['card_id'] as String,
        cards.last['card_id'] as String,
      );
      if (combination != null) {
        final linking = connector['linking'] as String? ?? '';
        paragraphs.add(linking.isEmpty ? combination : '$linking、$combination');
      }
    }

    final patternsByGenre = <String, List<Map<String, dynamic>>>{};
    for (final raw in (_content['context_patterns'] as List<dynamic>? ?? const [])) {
      final pattern = raw as Map<String, dynamic>;
      patternsByGenre
          .putIfAbsent(pattern['genre'] as String? ?? '', () => [])
          .add(pattern);
    }
    final patterns = patternsByGenre[genre] ?? patternsByGenre[_fallbackGenre] ?? const [];
    Map<String, dynamic>? pattern;
    if (patterns.isNotEmpty) {
      if (situation != null) {
        for (final item in patterns) {
          if (item['situation'] == situation) {
            pattern = item;
            break;
          }
        }
      }
      pattern ??= patterns[_stableHash([dateKey, themeId]) % patterns.length];
    }
    if (pattern != null) {
      final templates =
          (pattern['templates'] as List<dynamic>? ?? const []).cast<String>();
      if (templates.isNotEmpty) {
        final template = templates[
            _stableHash([sessionId, cards.first['card_id'] as String]) %
                templates.length];
        paragraphs.add(_fillPlaceholders(template, cards.first));
      }
    }

    final action = _actionSentence(
      cards.last,
      _stableHash([dateKey, cards.last['card_id'] as String]),
    );
    if (action.isNotEmpty) {
      paragraphs.add(action);
    }
    final closing = connector['closing'] as String? ?? '';
    if (closing.isNotEmpty) {
      paragraphs.add(closing);
    }

    if (paragraphs.isEmpty) {
      return fallbackText;
    }
    return paragraphs.join('\n\n');
  }

  /// 2枚のカード間の組み合わせ解釈（エレメント同士→属性分類同士の順・順不同）。
  String? composeCombination(String cardIdA, String cardIdB) {
    final cardA = _cardById(cardIdA);
    final cardB = _cardById(cardIdB);
    if (cardA == null || cardB == null || cardIdA == cardIdB) {
      return null;
    }
    final rules = (_content['combination_rules'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final candidates = <List<String>>[
      [cardA['element'] as String? ?? '', cardB['element'] as String? ?? ''],
      [cardA['attribute'] as String? ?? '', cardB['attribute'] as String? ?? ''],
    ];
    for (final pair in candidates) {
      for (final rule in rules) {
        final matches = (rule['attr1'] == pair[0] && rule['attr2'] == pair[1]) ||
            (rule['attr1'] == pair[1] && rule['attr2'] == pair[0]);
        if (!matches) {
          continue;
        }
        final keywords =
            (rule['keywords'] as List<dynamic>? ?? const []).cast<String>();
        var text = '${cardA['name_ja']}と${cardB['name_ja']}の組み合わせは'
            '「${rule['interaction'] ?? ''}」の関係です。'
            '${rule['direction'] ?? ''}';
        if (keywords.isNotEmpty) {
          text += '（鍵となる言葉: ${keywords.take(3).join('・')}）';
        }
        return text;
      }
    }
    return null;
  }
}
