import 'dart:convert';

import 'package:http/http.dart' as http;

import 'oracle_backend.dart';

class ApiClient implements OracleBackend {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _healthTimeout = Duration(seconds: 3);

  final String baseUrl;
  final http.Client _client;

  Future<dynamic> _getJson(String path, {Map<String, String>? query}) async {
    var uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }
    final response = await _client.get(uri).timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  Future<dynamic> _postJson(String path, Map<String, dynamic> body) async {
    final response = await _client
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  @override
  Future<bool> checkHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(_healthTimeout);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> loginByUserId(String userId) async {
    return await _postJson('/auth/login', {'user_id': userId})
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> getProfile({required String userId}) async {
    return await _getJson('/profile', query: {'user_id': userId})
        as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String displayName,
  }) async {
    final response = await _client
        .put(
          Uri.parse('$baseUrl/profile'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'display_name': displayName,
          }),
        )
        .timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> deleteHistory({
    required String userId,
    required String historyId,
  }) async {
    final uri = Uri.parse('$baseUrl/history/$historyId')
        .replace(queryParameters: {'user_id': userId});
    final response = await _client.delete(uri).timeout(_requestTimeout);
    _ensureSuccess(response);
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> issueTransferCode({
    required String userId,
  }) async {
    return await _postJson('/account/transfer-code', {
      'user_id': userId,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> redeemTransferCode({
    required String code,
  }) async {
    return await _postJson('/account/transfer-code/redeem', {
      'code': code,
    }) as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getThemes() async {
    return await _getJson('/themes') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getDecks() async {
    return await _getJson('/decks') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getAnnouncements() async {
    return await _getJson('/announcements') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getCards({String? deckId, String? query}) async {
    final parameters = <String, String>{};
    if (deckId != null && deckId.isNotEmpty) {
      parameters['deck_id'] = deckId;
    }
    if (query != null && query.isNotEmpty) {
      parameters['q'] = query;
    }
    return await _getJson('/cards', query: parameters) as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getProducts() async {
    return await _getJson('/products') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getHistory({required String userId}) async {
    return await _getJson('/history', query: {'user_id': userId})
        as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getSpreads({String? userId}) async {
    final query = (userId == null || userId.isEmpty) ? '' : '?user_id=$userId';
    return await _getJson('/reading/spreads$query') as List<dynamic>;
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
    return await _postJson('/reading/start', {
      'user_id': userId,
      'theme_id': themeId,
      'deck_id': deckId,
      'draw_count': drawCount,
      'spread_id': spreadId,
      'question_text': questionText,
      if (originSessionId != null) 'origin_session_id': originSessionId,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> completeShuffle({
    required String sessionId,
    double idleSeconds = 1.2,
    bool fingerReleased = true,
    double swipeDistance = 200,
  }) async {
    return await _postJson('/reading/complete-shuffle', {
      'session_id': sessionId,
      'idle_seconds': idleSeconds,
      'finger_released': fingerReleased,
      'swipe_distance': swipeDistance,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> selectPile({
    required String sessionId,
    required int pileIndex,
  }) async {
    return await _postJson('/reading/select-pile', {
      'session_id': sessionId,
      'pile_index': pileIndex,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>?> selectCard({
    required String sessionId,
    required int cardIndex,
  }) async {
    // 必要枚数に達するまではサーバーが null を返す（＝カード選択を継続）。
    return await _postJson('/reading/select-card', {
      'session_id': sessionId,
      'card_index': cardIndex,
    }) as Map<String, dynamic>?;
  }

  @override
  Future<Map<String, dynamic>> getReadingResult(String sessionId) async {
    return await _getJson('/reading/$sessionId') as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> saveHistory({
    required String userId,
    required String sessionId,
  }) async {
    return await _postJson('/reading/$sessionId/save-history', {
      'user_id': userId,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> restorePurchase({
    required String userId,
    required String productCode,
    required String restoreReceiptId,
  }) async {
    return await _postJson('/purchase/restore', {
      'user_id': userId,
      'product_code': productCode,
      'restore_receipt_id': restoreReceiptId,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> registerNotificationToken({
    required String userId,
    required String token,
  }) async {
    return await _postJson('/notifications/token', {
      'user_id': userId,
      'token': token,
    }) as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> submitInquiry({
    required String userId,
    required String category,
    required String body,
    String? email,
  }) async {
    return await _postJson('/inquiries', {
      'user_id': userId,
      'category': category,
      'body': body,
      'email': email,
    }) as Map<String, dynamic>;
  }

  @override
  Future<List<dynamic>> getShopLinks() async {
    return await _getJson('/links/shop') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getConsultationLinks() async {
    return await _getJson('/links/consultation') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getLiveLinks() async {
    return await _getJson('/links/live') as List<dynamic>;
  }

  @override
  Future<List<dynamic>> getLiveEvents() async {
    return await _getJson('/links/live-events') as List<dynamic>;
  }

  @override
  Future<Map<String, dynamic>> trackAnalyticsEvent({
    required String eventName,
    String? userId,
    Map<String, String>? properties,
  }) async {
    return await _postJson('/analytics/events', {
      'event_name': eventName,
      'user_id': userId,
      'properties': properties ?? <String, String>{},
    }) as Map<String, dynamic>;
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    throw ApiException(
      statusCode: response.statusCode,
      body: utf8.decode(response.bodyBytes),
    );
  }
}

class ApiException implements Exception {
  ApiException({required this.statusCode, required this.body});

  final int statusCode;
  final String body;

  @override
  String toString() => 'ApiException(statusCode: $statusCode, body: $body)';
}
