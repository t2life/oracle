import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../interpretation/interpretation_composer.dart';
import '../network/api_client.dart' show ApiException;
import '../network/oracle_backend.dart';
import '../state/state_messages.dart';

/// サーバー到達不能時に単体動作するオフライン・フォールバック実装。
///
/// - マスタデータは `assets/master_data.json`
///   （scripts/export_master_assets.py がバックエンドのシードから生成）を読む。
/// - 抽選・3山分割・解釈選択はバックエンド（reading_service）と同じ規則で行う。
/// - プラン・チケット・履歴・日次回数は端末内（SharedPreferences）へ保存する。
/// - 問い合わせ・通知トークン登録などサーバー必須の機能は
///   [StateMessages.offlineFeatureUnavailable] として明示的に不可を返す。
/// - 日次制限の日付判定は端末ローカル日付を用いる（サーバーはJST。差異は仕様書に記録）。
class OfflineBackend implements OracleBackend {
  OfflineBackend();

  static const String _keyPlan = 'offline_plan';
  static const String _keyTickets = 'offline_tickets';
  static const String _keyVisits = 'offline_visits';
  static const String _keyExpiresAt = 'offline_subscription_expires_at';
  static const String _keyHistory = 'offline_history';
  static const String _keyDrawDate = 'offline_draw_date';
  static const String _keyDrawCount = 'offline_draw_count';
  static const String _keyNickname = 'offline_nickname';

  final Random _random = Random();
  final Map<String, _OfflineSession> _sessions = {};
  final Map<String, Map<String, dynamic>> _results = {};

  Map<String, dynamic>? _master;
  SharedPreferences? _prefs;

  Future<Map<String, dynamic>> _loadMaster() async {
    if (_master != null) {
      return _master!;
    }
    final raw = await rootBundle.loadString('assets/master_data.json');
    _master = jsonDecode(raw) as Map<String, dynamic>;
    return _master!;
  }

  Future<SharedPreferences> _loadPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Never _reject(int statusCode, String detail) {
    throw ApiException(
      statusCode: statusCode,
      body: jsonEncode({'detail': detail}),
    );
  }

  /// JSTの日付キー（サーバーの date_key_jst と同じ規則＝同じ日は同じ文になる）。
  String _dateKeyJst(DateTime now) {
    final jst = now.toUtc().add(const Duration(hours: 9));
    return '${jst.year}-${jst.month.toString().padLeft(2, '0')}-'
        '${jst.day.toString().padLeft(2, '0')}';
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<String> _currentPlan() async {
    final prefs = await _loadPrefs();
    var plan = prefs.getString(_keyPlan) ?? 'free';
    if (plan == 'subscription') {
      final expiresRaw = prefs.getString(_keyExpiresAt);
      final expires = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
      if (expires == null || expires.isBefore(DateTime.now())) {
        plan = 'free';
        await prefs.setString(_keyPlan, plan);
        await prefs.remove(_keyExpiresAt);
      }
    }
    return plan;
  }

  @override
  Future<bool> checkHealth() async => true;

  @override
  Future<Map<String, dynamic>> loginByUserId(String userId) async {
    final prefs = await _loadPrefs();
    final plan = await _currentPlan();
    final visits = (prefs.getInt(_keyVisits) ?? 0) + 1;
    await prefs.setInt(_keyVisits, visits);
    return {
      'user_id': userId,
      'plan': plan,
      'tickets': prefs.getInt(_keyTickets) ?? 0,
      'visit_count': visits,
      'subscription_expires_at': prefs.getString(_keyExpiresAt),
      'display_name': prefs.getString(_keyNickname) ?? userId,
    };
  }

  @override
  Future<Map<String, dynamic>> getProfile({required String userId}) async {
    final prefs = await _loadPrefs();
    return {
      'user_id': userId,
      'display_name': prefs.getString(_keyNickname) ?? userId,
    };
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String displayName,
  }) async {
    final name = displayName.trim();
    if (name.isEmpty || name.length > 20) {
      _reject(400, 'ニックネームは1〜20文字で入力してください。');
    }
    final prefs = await _loadPrefs();
    await prefs.setString(_keyNickname, name);
    return {'user_id': userId, 'display_name': name};
  }

  @override
  Future<Map<String, dynamic>> deleteHistory({
    required String userId,
    required String historyId,
  }) async {
    final prefs = await _loadPrefs();
    final raw = prefs.getString(_keyHistory);
    final items = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List<dynamic>)
            .map((entry) => entry as Map<String, dynamic>)
            .toList();
    final before = items.length;
    items.removeWhere(
      (item) =>
          item['history_id'] == historyId && item['user_id'] == userId,
    );
    if (items.length == before) {
      _reject(404, '履歴が存在しません。');
    }
    await prefs.setString(_keyHistory, jsonEncode(items));
    return {'message': StateMessages.historyDeleted};
  }

  @override
  Future<List<dynamic>> getThemes() async {
    final master = await _loadMaster();
    return master['themes'] as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getDecks() async {
    final master = await _loadMaster();
    return master['decks'] as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getAnnouncements() async {
    final master = await _loadMaster();
    final now = DateTime.now();
    return (master['announcements'] as List<dynamic>).map((raw) {
      final item = raw as Map<String, dynamic>;
      final startDays = (item['start_days_from_now'] as num?)?.toInt() ?? 0;
      final endDays = (item['end_days_from_now'] as num?)?.toInt() ?? 30;
      return {
        'announcement_id': item['announcement_id'],
        'title': item['title'],
        'body': item['body'],
        'category': item['category'],
        'start_at': now.add(Duration(days: startDays)).toIso8601String(),
        'end_at': now.add(Duration(days: endDays)).toIso8601String(),
        'is_important': item['is_important'],
        'link_url': item['link_url'],
      };
    }).toList();
  }

  @override
  Future<List<dynamic>> getCards({String? deckId, String? query}) async {
    final master = await _loadMaster();
    var cards = (master['cards'] as List<dynamic>)
        .map((raw) => raw as Map<String, dynamic>)
        .toList();

    if (deckId != null && deckId.isNotEmpty) {
      cards = cards.where((card) => card['deck_id'] == deckId).toList();
    }
    if (query != null && query.isNotEmpty) {
      final lowered = query.toLowerCase();
      bool matches(Map<String, dynamic> card) {
        final names = [
          card['name_ja'] as String? ?? '',
          card['name_en'] as String? ?? '',
          card['name_zh'] as String? ?? '',
        ];
        final keywordLists = [
          card['keywords'],
          card['keywords_en'],
          card['keywords_zh'],
        ];
        if (names.any((name) => name.toLowerCase().contains(lowered))) {
          return true;
        }
        for (final list in keywordLists) {
          if (list is List &&
              list.any(
                (keyword) =>
                    keyword.toString().toLowerCase().contains(lowered),
              )) {
            return true;
          }
        }
        return false;
      }

      cards = cards.where(matches).toList();
    }
    return cards;
  }

  @override
  Future<List<dynamic>> getProducts() async {
    final master = await _loadMaster();
    return master['products'] as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getHistory({required String userId}) async {
    final prefs = await _loadPrefs();
    final raw = prefs.getString(_keyHistory);
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final items = (jsonDecode(raw) as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .where((item) => item['user_id'] == userId)
        .toList();
    items.sort(
      (a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return items;
  }

  /// スプレッド定義（同梱の解釈素材＝マスタ由来）。サーバーの /reading/spreads と同じ形。
  @override
  Future<List<dynamic>> getSpreads({String? userId}) async {
    final spreads = await InterpretationComposer.loadSpreads();
    final plan = await _currentPlan();
    final prefs = await _loadPrefs();
    final tickets = prefs.getInt(_keyTickets) ?? 0;
    // 本日の託宣（無料枠）の消化状況。startReading と同じ判定をここでも行い、
    // 「選んでから弾かれる」を避ける（サーバーの /reading/spreads と同じ規則）。
    final master = await _loadMaster();
    final dailyLimit =
        ((master['rules'] as Map<String, dynamic>)['free_daily_draw_limit']
                as num)
            .toInt();
    final storedDate = prefs.getString(_keyDrawDate);
    final todayCount =
        storedDate == _todayKey() ? (prefs.getInt(_keyDrawCount) ?? 0) : 0;
    final result = <Map<String, dynamic>>[];
    for (final spread in spreads) {
      final allowed =
          (spread['allowed_plans'] as List<dynamic>? ?? const []).cast<String>();
      final required = (spread['required_tickets'] as num?)?.toInt() ?? 0;
      final isOracle = spread['kind'] == 'oracle';
      var available = allowed.isEmpty || allowed.contains(plan);
      String? reason;
      if (!available) {
        reason = StateMessages.paidOnlyDraw;
      } else if (plan == 'ticket' && tickets < required) {
        available = false;
        reason = StateMessages.ticketShortage;
      } else if (isOracle &&
          (plan == 'free' || plan == 'guest') &&
          todayCount >= dailyLimit) {
        available = false;
        reason = StateMessages.freeDailyLimit;
      }
      result.add({
        ...spread,
        'available': available,
        'unavailable_reason': reason,
      });
    }
    result.sort(
      (a, b) => ((a['sort_order'] as num?)?.toInt() ?? 0)
          .compareTo((b['sort_order'] as num?)?.toInt() ?? 0),
    );
    return result;
  }

  @override
  Future<Map<String, dynamic>> startReading({
    required String userId,
    required String themeId,
    required String deckId,
    int drawCount = 1,
    String spreadId = 'daily',
    String questionText = '',
    String? originSessionId,
  }) async {
    final master = await _loadMaster();
    final prefs = await _loadPrefs();
    final rules = master['rules'] as Map<String, dynamic>;
    final plan = await _currentPlan();

    final themeExists = (master['themes'] as List<dynamic>)
        .any((theme) => (theme as Map<String, dynamic>)['theme_id'] == themeId);
    if (!themeExists) {
      _reject(400, '指定されたテーマが存在しません。');
    }
    final deckExists = (master['decks'] as List<dynamic>)
        .any((deck) => (deck as Map<String, dynamic>)['deck_id'] == deckId);
    if (!deckExists) {
      _reject(400, '指定されたデッキが存在しません。');
    }

    final today = _todayKey();
    final storedDate = prefs.getString(_keyDrawDate);
    var todayCount = storedDate == today ? (prefs.getInt(_keyDrawCount) ?? 0) : 0;

    // 枚数・対象プラン・必要チケットはスプレッド定義（マスタ）が決める＝サーバーと同一規則。
    final spread = await InterpretationComposer.spreadFor(spreadId);
    if (spread == null) {
      _reject(400, '指定されたスプレッドが存在しません。');
    }
    final fixedCount = (spread['card_count'] as num?)?.toInt() ?? 0;
    if (fixedCount > 0) {
      drawCount = fixedCount;
    } else {
      final minimum = (spread['min_cards'] as num?)?.toInt() ?? 1;
      final maximum = (spread['max_cards'] as num?)?.toInt() ?? 1;
      if (drawCount < minimum || drawCount > maximum) {
        _reject(400, '枚数は$minimum〜$maximum枚で指定してください。');
      }
    }
    if (questionText.trim().length > 3000) {
      _reject(400, '相談内容は3000文字以内で入力してください。');
    }

    final allowedPlans =
        (spread['allowed_plans'] as List<dynamic>? ?? const []).cast<String>();
    final requiredTickets = (spread['required_tickets'] as num?)?.toInt() ?? 0;

    if (plan == 'free' || plan == 'guest') {
      final limit = (rules['free_daily_draw_limit'] as num).toInt();
      if (todayCount >= limit) {
        _reject(403, StateMessages.freeDailyLimit);
      }
      if (allowedPlans.isNotEmpty && !allowedPlans.contains('free')) {
        _reject(403, StateMessages.paidOnlyDraw);
      }
    }

    if (plan == 'ticket' && requiredTickets > 0) {
      final tickets = prefs.getInt(_keyTickets) ?? 0;
      if (tickets < requiredTickets) {
        _reject(403, StateMessages.ticketShortage);
      }
      await prefs.setInt(_keyTickets, tickets - requiredTickets);
    }

    final deckCards = (master['cards'] as List<dynamic>)
        .map((raw) => raw as Map<String, dynamic>)
        .where((card) => card['deck_id'] == deckId)
        .toList();
    if (deckCards.length < drawCount * 3) {
      _reject(400, 'デッキ内のカード数が不足しています。');
    }

    final cardIds =
        deckCards.map((card) => card['card_id'] as String).toList()
          ..shuffle(_random);

    // 深掘り: 起点の託宣で出たカードを1枚目として引き継ぐ（サーバーと同じ手順）。
    // 引き継いだ1枚は山から取り除き、同じカードを二度引かせない。
    String? carried;
    if (originSessionId != null && originSessionId.isNotEmpty) {
      final origin = _results[originSessionId];
      if (origin == null) {
        _reject(400, '深掘りの起点になる結果が見つかりません。');
      }
      if (origin['user_id'] != userId) {
        _reject(403, '他の利用者の結果は深掘りできません。');
      }
      carried = origin['card_id'] as String;
      cardIds.remove(carried);
    }

    final sessionId =
        'ses_offline_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(0xffff)}';
    _sessions[sessionId] = _OfflineSession(
      sessionId: sessionId,
      userId: userId,
      themeId: themeId,
      deckId: deckId,
      drawCount: drawCount,
      cardIds: cardIds,
      spreadId: spreadId,
      questionText: questionText.trim(),
      originSessionId: carried == null ? null : originSessionId,
    );
    if (carried != null) {
      _sessions[sessionId]!.selectedCardIds.add(carried);
    }

    await prefs.setString(_keyDrawDate, today);
    await prefs.setInt(_keyDrawCount, todayCount + 1);

    return {
      'session_id': sessionId,
      'status': 'started',
      'started_at': DateTime.now().toIso8601String(),
      'draw_count': drawCount,
    };
  }

  @override
  Future<Map<String, dynamic>> completeShuffle({
    required String sessionId,
    double idleSeconds = 1.2,
    bool fingerReleased = true,
    double swipeDistance = 200,
  }) async {
    final master = await _loadMaster();
    final session = _sessions[sessionId];
    if (session == null) {
      _reject(400, StateMessages.sessionNotStarted);
    }

    final shuffle =
        (master['rules'] as Map<String, dynamic>)['shuffle'] as Map<String, dynamic>;
    final idleMin = (shuffle['idle_seconds_min'] as num).toDouble();
    final idleMax = (shuffle['idle_seconds_max'] as num).toDouble();
    final minSwipe = (shuffle['min_swipe_distance'] as num).toDouble();
    if (!fingerReleased || idleSeconds < idleMin || idleSeconds > idleMax) {
      _reject(400, 'シャッフル終了判定の待機時間が仕様外です。');
    }
    if (swipeDistance < minSwipe) {
      _reject(400, '最低操作量を満たしていません。');
    }

    session.splitIntoPiles();
    return {
      'session_id': sessionId,
      'status': 'shuffled',
      'pile_sizes': session.pileSizes(),
    };
  }

  @override
  Future<Map<String, dynamic>> selectPile({
    required String sessionId,
    required int pileIndex,
  }) async {
    final session = _sessions[sessionId];
    if (session == null || session.piles.isEmpty) {
      _reject(400, StateMessages.sessionNotStarted);
    }
    if (!session.piles.containsKey(pileIndex)) {
      _reject(400, '山番号は1から3で指定してください。');
    }
    session.chosenPile = pileIndex;
    return {
      'session_id': sessionId,
      'status': 'pile_selected',
      'pile_sizes': session.pileSizes(),
    };
  }

  @override
  Future<Map<String, dynamic>?> selectCard({
    required String sessionId,
    required int cardIndex,
  }) async {
    final master = await _loadMaster();
    final session = _sessions[sessionId];
    if (session == null || session.chosenPile == null) {
      _reject(400, StateMessages.sessionNotStarted);
    }

    final pile = session.piles[session.chosenPile] ?? const <String>[];
    if (cardIndex < 1 || cardIndex > pile.length) {
      _reject(400, 'カード番号が不正です。');
    }

    final cardId = pile[cardIndex - 1];
    if (session.selectedCardIds.contains(cardId)) {
      _reject(400, '同じカードは選べません。');
    }
    session.selectedCardIds.add(cardId);
    // 必要枚数に達するまでは結果を作らない（サーバーと同じ状態機械）。
    if (session.selectedCardIds.length < session.drawCount) {
      return null;
    }

    // 単数フィールドは1枚目を指す（履歴・既存画面の互換）。
    final firstCardId = session.selectedCardIds.first;
    final card = (master['cards'] as List<dynamic>)
        .map((raw) => raw as Map<String, dynamic>)
        .firstWhere((item) => item['card_id'] == firstCardId);

    String meaning(String mapKey, String defaultKey) {
      final meanings = card[mapKey] as Map<String, dynamic>? ?? const {};
      final selected = meanings[session.themeId] as String?;
      return selected ?? (card[defaultKey] as String? ?? '');
    }

    final texts = master['texts'] as Map<String, dynamic>? ?? const {};
    // 日本語の託宣文はサーバーと同じ3層合成で組み立てる（同梱の解釈素材を使用）。
    // 素材が無い/カードが未登録の場合はテーマ別解釈をそのまま使う（fail-soft）。
    final composer = await InterpretationComposer.load();
    final baseMeaning = meaning('meanings_by_theme', 'default_meaning');
    final interpretation = composer == null
        ? baseMeaning
        : composer.composeReading(
            cardIds: List<String>.from(session.selectedCardIds),
            themeId: session.themeId,
            dateKey: _dateKeyJst(DateTime.now()),
            sessionId: sessionId,
            fallbackText: baseMeaning,
            spreadId: session.spreadId,
            questionText: session.questionText,
          );
    final positions = composer == null
        ? const <Map<String, dynamic>>[]
        : composer.positionsFor(session.spreadId, session.selectedCardIds.length);
    final resultCards = <Map<String, dynamic>>[];
    for (var index = 0; index < session.selectedCardIds.length; index++) {
      final id = session.selectedCardIds[index];
      final entry = (master['cards'] as List<dynamic>)
          .map((raw) => raw as Map<String, dynamic>)
          .firstWhere((item) => item['card_id'] == id);
      final position =
          index < positions.length ? positions[index] : const <String, dynamic>{};
      resultCards.add({
        'card_id': id,
        'card_name': entry['name_ja'],
        'keywords': entry['keywords'],
        'position_index': position['index'] ?? index + 1,
        'position_name': position['name'] ?? '',
        'position_meaning': position['meaning'] ?? '',
        'reading': entry['reading'] ?? '',
        'attribute': entry['attribute'] ?? '',
        'element': entry['element'] ?? '',
      });
    }
    final combination = (composer == null || session.selectedCardIds.length < 2)
        ? null
        : composer.composeCombination(
            session.selectedCardIds.first,
            session.selectedCardIds.last,
          );
    final result = <String, dynamic>{
      'session_id': sessionId,
      'user_id': session.userId,
      'theme_id': session.themeId,
      'deck_id': session.deckId,
      'card_id': cardId,
      'card_name': card['name_ja'],
      'keywords': card['keywords'],
      'interpretation_text': interpretation,
      'caution_text': texts['caution_ja'],
      'created_at': DateTime.now().toIso8601String(),
      'copied': false,
      'card_name_en': card['name_en'] ?? '',
      'keywords_en': card['keywords_en'] ?? const [],
      'interpretation_text_en':
          meaning('meanings_by_theme_en', 'default_meaning_en'),
      'caution_text_en': texts['caution_en'],
      'card_name_zh': card['name_zh'] ?? '',
      'keywords_zh': card['keywords_zh'] ?? const [],
      'interpretation_text_zh':
          meaning('meanings_by_theme_zh', 'default_meaning_zh'),
      'caution_text_zh': texts['caution_zh'],
      'spread_id': session.spreadId,
      'question_text': session.questionText,
      'origin_session_id': session.originSessionId,
      'cards': resultCards,
      'combination_text': combination,
    };
    _results[sessionId] = result;
    return result;
  }

  @override
  Future<Map<String, dynamic>> getReadingResult(String sessionId) async {
    final result = _results[sessionId];
    if (result == null) {
      _reject(400, StateMessages.sessionNotStarted);
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> saveHistory({
    required String userId,
    required String sessionId,
  }) async {
    final prefs = await _loadPrefs();
    final result = _results[sessionId];
    if (result == null) {
      _reject(400, StateMessages.sessionNotStarted);
    }

    final plan = await _currentPlan();
    final interpretation = result['interpretation_text'] as String;
    final item = <String, dynamic>{
      'history_id': 'his_offline_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': userId,
      'session_id': sessionId,
      'created_at': DateTime.now().toIso8601String(),
      'theme_id': result['theme_id'],
      'deck_id': result['deck_id'],
      'card_id': result['card_id'],
      'summary': interpretation.length > 60
          ? interpretation.substring(0, 60)
          : interpretation,
      'full_text': interpretation,
      'plan_at_creation': plan,
    };

    final raw = prefs.getString(_keyHistory);
    final items = raw == null || raw.isEmpty
        ? <Map<String, dynamic>>[]
        : (jsonDecode(raw) as List<dynamic>)
            .map((entry) => entry as Map<String, dynamic>)
            .toList();
    items.add(item);
    items.sort(
      (a, b) => (b['created_at'] as String).compareTo(a['created_at'] as String),
    );

    if (plan == 'free' || plan == 'guest') {
      final master = await _loadMaster();
      final limit =
          ((master['rules'] as Map<String, dynamic>)['free_history_limit'] as num)
              .toInt();
      while (items.length > limit) {
        items.removeLast();
      }
    }
    await prefs.setString(_keyHistory, jsonEncode(items));
    return {'message': StateMessages.historySaved};
  }

  @override
  Future<Map<String, dynamic>> restorePurchase({
    required String userId,
    required String productCode,
    required String restoreReceiptId,
  }) async {
    final master = await _loadMaster();
    final prefs = await _loadPrefs();
    final rules = master['rules'] as Map<String, dynamic>;
    final ticketProducts =
        (rules['ticket_products'] as Map<String, dynamic>? ?? const {});

    if (ticketProducts.containsKey(productCode)) {
      final amount = (ticketProducts[productCode] as num).toInt();
      final tickets = (prefs.getInt(_keyTickets) ?? 0) + amount;
      await prefs.setString(_keyPlan, 'ticket');
      await prefs.setInt(_keyTickets, tickets);
      return {
        'accepted': true,
        'user_id': userId,
        'plan': 'ticket',
        'tickets': tickets,
        'message': StateMessages.purchaseRestored,
      };
    }

    if (productCode == rules['subscription_product_code']) {
      final expires = DateTime.now().add(const Duration(days: 37));
      await prefs.setString(_keyPlan, 'subscription');
      await prefs.setString(_keyExpiresAt, expires.toIso8601String());
      return {
        'accepted': true,
        'user_id': userId,
        'plan': 'subscription',
        'tickets': prefs.getInt(_keyTickets) ?? 0,
        'message': StateMessages.purchaseRestored,
      };
    }

    _reject(400, '未対応の商品コードです。');
  }

  @override
  Future<Map<String, dynamic>> registerNotificationToken({
    required String userId,
    required String token,
  }) async {
    return {'message': StateMessages.offlineFeatureUnavailable};
  }

  // 引継ぎはアカウントをサーバー側で付け替える操作のため、オフラインでは扱えない。
  @override
  Future<Map<String, dynamic>> issueTransferCode({
    required String userId,
  }) async {
    _reject(400, StateMessages.offlineFeatureUnavailable);
  }

  @override
  Future<Map<String, dynamic>> redeemTransferCode({
    required String code,
  }) async {
    _reject(400, StateMessages.offlineFeatureUnavailable);
  }

  @override
  Future<Map<String, dynamic>> submitInquiry({
    required String userId,
    required String category,
    required String body,
    String? email,
  }) async {
    _reject(400, StateMessages.offlineFeatureUnavailable);
  }

  @override
  Future<List<dynamic>> getShopLinks() async => _links('shop');

  @override
  Future<List<dynamic>> getConsultationLinks() async => _links('consultation');

  @override
  Future<List<dynamic>> getLiveLinks() async => _links('live');

  Future<List<dynamic>> _links(String category) async {
    final master = await _loadMaster();
    final links = master['links'] as Map<String, dynamic>? ?? const {};
    return links[category] as List<dynamic>? ?? const [];
  }

  @override
  Future<List<dynamic>> getLiveEvents() async {
    final master = await _loadMaster();
    final now = DateTime.now();
    return (master['live_events'] as List<dynamic>).map((raw) {
      final event = raw as Map<String, dynamic>;
      final days = (event['start_days_from_now'] as num?)?.toInt() ?? 0;
      return {
        'live_event_id': event['live_event_id'],
        'title': event['title'],
        'start_at': now.add(Duration(days: days)).toIso8601String(),
        'archive_url': event['archive_url'],
      };
    }).toList();
  }

  @override
  Future<Map<String, dynamic>> trackAnalyticsEvent({
    required String eventName,
    String? userId,
    Map<String, String>? properties,
  }) async {
    // オフラインでは分析イベントを記録しない（本番同様、非致命の扱い）
    return const {};
  }
}

class _OfflineSession {
  _OfflineSession({
    required this.sessionId,
    required this.userId,
    required this.themeId,
    required this.deckId,
    required this.drawCount,
    required this.cardIds,
    this.spreadId = 'daily',
    this.questionText = '',
    this.originSessionId,
  });

  final String sessionId;
  final String userId;
  final String themeId;
  final String deckId;
  final int drawCount;
  final List<String> cardIds;
  final String spreadId;
  final String questionText;

  /// 深掘りの起点になった託宣のセッション（履歴を1件にまとめるために使う）。
  final String? originSessionId;
  final Map<int, List<String>> piles = {};
  int? chosenPile;

  /// 確定順のカード（複数枚リーディング）。
  final List<String> selectedCardIds = [];

  /// バックエンド reading_service._split_three_piles と同じラウンドロビン分配
  void splitIntoPiles() {
    piles
      ..clear()
      ..[1] = []
      ..[2] = []
      ..[3] = [];
    for (var index = 0; index < cardIds.length; index++) {
      piles[(index % 3) + 1]!.add(cardIds[index]);
    }
  }

  Map<String, int> pileSizes() {
    return piles.map((key, value) => MapEntry('$key', value.length));
  }
}
