/// アプリが利用するバックエンド操作の抽象インターフェース。
///
/// 実装は2系統:
/// - [ApiClient]（リモート・HTTP経由の本来のバックエンド）
/// - [OfflineBackend]（サーバー到達不能時のオフライン・フォールバック）
///
/// 戻り値の形（Map/Listのキー構造）はAPI仕様書のレスポンスと同一とし、
/// domain_models の fromJson がどちらの実装でも同じように解釈できることを保証する。
abstract interface class OracleBackend {
  Future<bool> checkHealth();

  Future<Map<String, dynamic>> loginByUserId(String userId);

  Future<Map<String, dynamic>> getProfile({required String userId});

  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    required String displayName,
  });

  Future<Map<String, dynamic>> deleteHistory({
    required String userId,
    required String historyId,
  });

  /// 機種変更の引継ぎコードを発行する（`code` / `formatted_code` / `expires_at`）。
  Future<Map<String, dynamic>> issueTransferCode({required String userId});

  /// 引継ぎコードを使って発行元アカウントへ切り替える（プロフィールを返す）。
  Future<Map<String, dynamic>> redeemTransferCode({required String code});

  Future<List<dynamic>> getThemes();

  Future<List<dynamic>> getDecks();

  Future<List<dynamic>> getAnnouncements();

  Future<List<dynamic>> getCards({String? deckId, String? query});

  Future<List<dynamic>> getProducts();

  Future<List<dynamic>> getHistory({required String userId});

  /// スプレッド定義の一覧。[userId] を渡すと実行可否（プラン・チケット残数）も返る。
  Future<List<dynamic>> getSpreads({String? userId});

  Future<Map<String, dynamic>> startReading({
    required String userId,
    required String themeId,
    required String deckId,
    int drawCount = 1,
    String spreadId = 'daily',
    String questionText = '',
    String? originSessionId,
  });

  Future<Map<String, dynamic>> completeShuffle({
    required String sessionId,
    double idleSeconds = 1.2,
    bool fingerReleased = true,
    double swipeDistance = 200,
  });

  Future<Map<String, dynamic>> selectPile({
    required String sessionId,
    required int pileIndex,
  });

  /// カードを1枚確定する。必要枚数に達するまでは null（＝継続）を返す。
  Future<Map<String, dynamic>?> selectCard({
    required String sessionId,
    required int cardIndex,
  });

  Future<Map<String, dynamic>> getReadingResult(String sessionId);

  Future<Map<String, dynamic>> saveHistory({
    required String userId,
    required String sessionId,
  });

  Future<Map<String, dynamic>> restorePurchase({
    required String userId,
    required String productCode,
    required String restoreReceiptId,
  });

  Future<Map<String, dynamic>> registerNotificationToken({
    required String userId,
    required String token,
  });

  Future<Map<String, dynamic>> submitInquiry({
    required String userId,
    required String category,
    required String body,
    String? email,
  });

  Future<List<dynamic>> getShopLinks();

  Future<List<dynamic>> getConsultationLinks();

  Future<List<dynamic>> getLiveLinks();

  Future<List<dynamic>> getLiveEvents();

  Future<Map<String, dynamic>> trackAnalyticsEvent({
    required String eventName,
    String? userId,
    Map<String, String>? properties,
  });
}
