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

  /// (ジャンル, 状況, トーン, 一致したか)。
  /// 相談内容が無ければ状況はnull（呼び出し側が日替わりで選ぶ）。
  ///
  /// 第4要素は「質問タイプ分類のどれかに当たったか」。2026-09-12 追加。
  /// 当たらないまま日付でテンプレを選ぶと**問いと無関係な段落**になる。
  (String, String?, Map<String, dynamic>?, bool) _classify(
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
          true,
        );
      }
    }
    return (themeGenre, null, _toneForGenre(themeGenre), false);
  }

  /// 神名にルビを添える（例: 須佐之男命（スサノオノミコト））。
  /// 本文は日本語専用のため括弧書きでよい。ルビが無ければ括弧を出さない。
  static String _withRuby(Map<String, dynamic> card) {
    final name = card['name_ja'] as String? ?? '';
    final reading = (card['reading'] as String? ?? '').trim();
    return (name.isNotEmpty && reading.isNotEmpty) ? '$name（$reading）' : name;
  }

  /// テーマ別の意味を1文ずつに割る（マスタは「A。B。C。」の列挙）。
  static List<String> _meaningItems(Map<String, dynamic> card, String themeId) {
    final meanings = card['theme_meanings'] as Map<String, dynamic>? ?? const {};
    final text = (meanings[themeId] as String?) ??
        (card['basic_meaning'] as String? ?? '');
    final items = text
        .split(RegExp(r'[。．]'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    return items.isEmpty ? [text.trim()] : items;
  }

  /// 意味を**1つだけ**選ぶ。[avoid] は結論文で既に使った番号。
  (String, int) _pickMeaning(
    Map<String, dynamic> card,
    String themeId,
    String seedKey, {
    int? avoid,
  }) {
    final items = _meaningItems(card, themeId);
    if (items.isEmpty) {
      return ('', -1);
    }
    var index =
        _stableHash([seedKey, card['card_id'] as String? ?? '']) % items.length;
    if (avoid != null && items.length > 1 && index == avoid) {
      index = (index + 1) % items.length;
    }
    return (asPhrase(items[index]), index);
  }

  static final RegExp _subjectPattern = RegExp(
    r'[一-龥々〆ヵヶ]{1,12}|[ァ-ヴー]{2,12}[0-9０-９]{0,3}|[A-Za-z]{2,12}[0-9０-９]{0,3}',
  );
  static const Set<String> _subjectStopwords = {
    '私', '僕', '俺', '自分', '今', '今後', '今回', '最近', '今年', '来年',
    '今月', '来月', '本当', '一番', '事', '物', '人', '方', '為', '時',
    '知', '教', '占', '聞', '思', '感', '見',
  };

  List<Map<String, dynamic>> get _questionForms =>
      ((_content['question_forms'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>());

  /// 問いの主題語。名詞らしい塊のうち**最も長いもの**（同長は先に出たほう）。
  String? questionSubject(String? questionText) {
    final question = (questionText ?? '').trim();
    if (question.isEmpty) {
      return null;
    }
    final formWords = <String>{};
    for (final entry in _questionForms) {
      formWords.addAll(
        (entry['keywords'] as List<dynamic>? ?? const []).cast<String>(),
      );
    }
    String? best;
    var bestLength = 0;
    for (final match in _subjectPattern.allMatches(question)) {
      final word = match.group(0)!;
      if (_subjectStopwords.contains(word)) {
        continue;
      }
      if (formWords.any(
        (formWord) =>
            formWord.isNotEmpty &&
            (word.contains(formWord) || formWord.contains(word)),
      )) {
        continue;
      }
      if (word.length > bestLength) {
        best = word;
        bestLength = word.length;
      }
    }
    return best;
  }

  /// 問いの型（可否・時期・方法・選択・気持ち・原因／既定）。
  Map<String, dynamic>? questionForm(String? questionText) {
    final question = (questionText ?? '').trim();
    final forms = _questionForms;
    if (question.isEmpty || forms.isEmpty) {
      return null;
    }
    Map<String, dynamic>? fallback;
    Map<String, dynamic>? best;
    var bestHits = 0;
    for (final entry in forms) {
      final keywords =
          (entry['keywords'] as List<dynamic>? ?? const []).cast<String>();
      if (keywords.isEmpty) {
        fallback ??= entry;
        continue;
      }
      var hits = 0;
      for (final keyword in keywords) {
        if (keyword.isNotEmpty && question.contains(keyword)) {
          hits += 1;
        }
      }
      if (hits > 0 && hits > bestHits) {
        bestHits = hits;
        best = entry;
      }
    }
    return best ?? fallback;
  }

  /// 結論を先に述べる一文と、そこで使った意味の番号。
  (String, int) _composeConclusion(
    List<Map<String, dynamic>> cards,
    String themeId,
    String? questionText,
    String seedKey,
  ) {
    final subject = questionSubject(questionText);
    final form = questionForm(questionText);
    if (subject == null || form == null || cards.isEmpty) {
      return ('', -1);
    }
    final template = form['template'] as String? ?? '';
    if (template.isEmpty) {
      return ('', -1);
    }
    final (meaning, index) =
        _pickMeaning(cards.last, themeId, '$seedKey|結論');
    if (meaning.isEmpty) {
      return ('', -1);
    }
    return (
      template.replaceAll('{主題}', subject).replaceAll('{意味}', meaning),
      index,
    );
  }

  static const String _stanceLuck = '運任せ';
  static const String _stanceUnmatched = '分類外';

  Map<String, dynamic>? _stanceEntry(String kind) {
    for (final raw
        in (_content['question_stances'] as List<dynamic>? ?? const [])) {
      final entry = raw as Map<String, dynamic>;
      if (entry['kind'] == kind) {
        return entry;
      }
    }
    return null;
  }

  /// 問いの扱い（`運任せ` / `分類外` / null）。サーバーの `question_stance` と同じ手順。
  String? _questionStance(String? questionText, bool matched) {
    final question = (questionText ?? '').trim();
    if (question.isEmpty) {
      return null;
    }
    final luck = _stanceEntry(_stanceLuck);
    if (luck != null) {
      final keywords =
          (luck['keywords'] as List<dynamic>? ?? const []).cast<String>();
      for (final keyword in keywords) {
        if (keyword.isNotEmpty && question.contains(keyword)) {
          return _stanceLuck;
        }
      }
    }
    if (!matched && _stanceEntry(_stanceUnmatched) != null) {
      return _stanceUnmatched;
    }
    return null;
  }

  /// 問いの扱いに沿った (語り口, 助言)。素材が無ければ空文字。
  (String, String) _stanceParagraphs(
    String stance,
    List<Map<String, dynamic>> cards,
    String seedKey,
  ) {
    final entry = _stanceEntry(stance);
    if (entry == null || cards.isEmpty) {
      return ('', '');
    }
    final voices =
        (entry['voices'] as List<dynamic>? ?? const []).cast<String>();
    final advices =
        (entry['advices'] as List<dynamic>? ?? const []).cast<String>();
    final first = cards.first;
    final last = cards.last;
    var voice = '';
    var advice = '';
    if (voices.isNotEmpty) {
      final index =
          _stableHash([seedKey, first['card_id'] as String]) % voices.length;
      voice = _fillPlaceholders(voices[index], first);
    }
    if (advices.isNotEmpty) {
      final index =
          _stableHash([seedKey, last['card_id'] as String]) % advices.length;
      advice = _fillPlaceholders(advices[index], last);
    }
    return (voice, advice);
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
      '神名': _withRuby(card),
      // 2026-09-12 追加。問いの扱いの型が属性・エレメントを語るため。
      '属性': card['attribute'] as String? ?? '',
      'エレメント': card['element'] as String? ?? '',
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

  // ------------------------------------------------------------ 番号の読み
  // サーバーの `InterpretationEngine.compose_number_reading` と同じ手順。
  // 片方だけ直すと同じ引きで文章が変わるため、必ず両方を直す。

  /// 遅い単位ほど後ろ。最頻が割れたときはより遅いほうを採る。
  static const List<String> _elementOrder = ['火', '風', '水', '地', 'エーテル'];

  /// 相談内容が期日・数量を問うているか。問うていなければ null。
  String? numberQuestionKind(String? questionText) {
    final question = (questionText ?? '').trim();
    if (question.isEmpty) {
      return null;
    }
    final entries = (_content['number_question_keywords'] as List<dynamic>? ??
            const [])
        .cast<Map<String, dynamic>>();
    // 「時期」を先に見る（両方に触れる問いは時期として読む）。
    for (final kind in const ['時期', '数量']) {
      for (final entry in entries) {
        if (entry['kind'] != kind) {
          continue;
        }
        final keyword = (entry['keyword'] as String? ?? '').trim();
        if (keyword.isNotEmpty && question.contains(keyword)) {
          return kind;
        }
      }
    }
    return null;
  }

  String? _composeNumberReading(
    List<Map<String, dynamic>> cards,
    String? questionText,
  ) {
    final kind = numberQuestionKind(questionText);
    if (kind == null || cards.isEmpty) {
      return null;
    }
    final readings = (_content['number_readings'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    if (readings.isEmpty) {
      return null;
    }
    final element = _dominantElement(cards);
    Map<String, dynamic>? reading;
    for (final item in readings) {
      if (item['element'] == element) {
        reading = item;
        break;
      }
    }
    if (reading == null) {
      return null;
    }

    // 数は最後に引いた札（未来を指す位置）を使う。
    final number = (cards.last['no'] as num?)?.toInt() ?? 0;
    if (number <= 0) {
      return null;
    }

    if (kind == '数量') {
      final template = reading['quantity_template'] as String? ?? '';
      return template.isEmpty ? null : template.replaceAll('{n}', '$number');
    }

    final unit = reading['unit'] as String? ?? '';
    final limit = (reading['max_value'] as num?)?.toInt() ?? 0;
    if (unit.isEmpty || (limit > 0 && number > limit)) {
      final over = reading['over_template'] as String? ?? '';
      return over.isEmpty ? null : over;
    }
    final template = reading['template'] as String? ?? '';
    if (template.isEmpty) {
      return null;
    }
    return template.replaceAll('{n}', '$number').replaceAll('{unit}', unit);
  }

  String _dominantElement(List<Map<String, dynamic>> cards) {
    final counts = <String, int>{};
    for (final card in cards) {
      final element = card['element'] as String? ?? '';
      if (element.isNotEmpty) {
        counts[element] = (counts[element] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) {
      return '';
    }
    final best = counts.values.reduce((a, b) => a > b ? a : b);
    final tied = counts.entries
        .where((entry) => entry.value == best)
        .map((entry) => entry.key)
        .toList();
    tied.sort(
      (a, b) => _elementOrder.indexOf(a).compareTo(_elementOrder.indexOf(b)),
    );
    return tied.last;
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
    bool single, {
    String seedKey = '',
    int? avoid,
  }) {
    // 位置ごとの語り口（サーバーの `_card_paragraph` と同じ手順）。
    // 全位置で同じ文末だと「一覧を読み上げた」印象になるため位置で変える。
    final positionName =
        position == null ? '本日の一枚' : (position['name'] as String? ?? '');
    // 意味は**1つだけ**選ぶ（マスタの列挙を全部並べると羅列に見えるため）。
    final (phrase, _) =
        _pickMeaning(card, themeId, '$seedKey|$positionName', avoid: avoid);
    final name = _withRuby(card);
    final voices = ((_content['position_voices']
                as Map<String, dynamic>? ??
            const {})[positionName] as List<dynamic>? ??
        const []).cast<String>();
    if (voices.isNotEmpty) {
      // 同じ位置でもカードごとに言い方が変わるよう決定的に選ぶ。
      final voice = voices[
          _stableHash([card['card_id'] as String? ?? '', positionName]) %
              voices.length];
      return voice
          .replaceAll('{name}', name)
          .replaceAll('{phrase}', phrase)
          .replaceAll('{meaning}', (position?['meaning'] as String?) ?? '');
    }
    // 語り口が未整備の位置は従来の言い方へ落ちる（fail-soft）。
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

    final (genre, situation, tone, matched) = _classify(questionText, themeId);
    final stance = _questionStance(questionText, matched);
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

    // 1.5 結論（2026-09-12）。**問いがあるときだけ**先に答えを置く。
    final (conclusion, usedMeaning) =
        _composeConclusion(cards, themeId, questionText, sessionId);
    if (conclusion.isNotEmpty) {
      paragraphs.add(conclusion);
    }

    // 最後の1枚は結論で使った意味を外す（同じ文を二度言わない）。
    for (var index = 0; index < cards.length; index++) {
      final position = index < positions.length ? positions[index] : null;
      final avoid =
          (index == cards.length - 1 && conclusion.isNotEmpty) ? usedMeaning : null;
      paragraphs.add(
        _cardParagraph(
          cards[index],
          themeId,
          position,
          single,
          seedKey: sessionId,
          avoid: avoid,
        ),
      );
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

    // 4. 文脈テンプレ／問いの扱い
    //
    // 相談内容がどの質問タイプにも当たらないと、従来はここで**日付でテンプレを
    // 選んで**いた（宝くじの問いに節約の話が出た原因）。問いを読まずに語るくらいなら、
    // カードそのものを語って直感へ委ねる。
    final (stanceVoice, stanceAdvice) = stance == null
        ? ('', '')
        : _stanceParagraphs(stance, cards, sessionId);
    if (stanceVoice.isNotEmpty) {
      paragraphs.add(stanceVoice);
    } else {
      final patternsByGenre = <String, List<Map<String, dynamic>>>{};
      for (final raw
          in (_content['context_patterns'] as List<dynamic>? ?? const [])) {
        final pattern = raw as Map<String, dynamic>;
        patternsByGenre
            .putIfAbsent(pattern['genre'] as String? ?? '', () => [])
            .add(pattern);
      }
      final patterns =
          patternsByGenre[genre] ?? patternsByGenre[_fallbackGenre] ?? const [];
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
        if (pattern == null && stance == null) {
          // 問いが無い（本日の託宣）ときだけ日替わりで選ぶ。
          pattern = patterns[_stableHash([dateKey, themeId]) % patterns.length];
        }
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
    }

    // 4.5 番号の読み（期日・数量を問われたときだけ）
    final numberReading = _composeNumberReading(cards, questionText);
    if (numberReading != null) {
      paragraphs.add(numberReading);
    }

    // 問いの扱いがある場合、助言も同じ型から作る（同じ語を二度言わない）。
    final action = stanceAdvice.isNotEmpty
        ? stanceAdvice
        : _actionSentence(
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
        // ★素材の欄名をそのまま文章へ出さない（サーバーと同じ手順）。
        var direction = (rule['direction'] as String? ?? '').trim();
        if (direction.isNotEmpty &&
            !const ['。', '．', '！', '？'].contains(
              direction.substring(direction.length - 1),
            )) {
          direction = '$direction。';
        }
        var text = '${_withRuby(cardA)}と${_withRuby(cardB)}は'
            '「${rule['interaction'] ?? ''}」の関係にあります。'
            '$direction';
        if (keywords.isNotEmpty) {
          text += 'この巡り合わせを言葉にするなら、'
              '${keywords.take(3).join('・')}です。';
        }
        return text;
      }
    }
    return null;
  }
}
