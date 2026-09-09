import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/domain_models.dart';
import '../network/api_client.dart';
import '../network/oracle_backend.dart';
import '../offline/offline_backend.dart';
import 'state_messages.dart';

class OracleAppState extends ChangeNotifier {
  OracleAppState({
    required ApiClient remoteClient,
    required OfflineBackend offlineBackend,
    String initialUserId = 'mobile_demo_user',
  })  : _remoteClient = remoteClient,
        _offlineBackend = offlineBackend,
        _backend = remoteClient,
        _userId = initialUserId;

  /// 有料機能解放版ビルド専用フラグ。
  /// `flutter build apk --dart-define=PREMIUM_UNLOCKED=true` を指定した
  /// ビルドのみ true になり、通常ビルドの挙動には一切影響しない。
  static const bool premiumUnlocked = bool.fromEnvironment('PREMIUM_UNLOCKED');

  static const String _languagePrefsKey = 'app_language_preference';
  static const String _themePrefsKey = 'app_theme_preference';
  static const String _themeImagePrefsKey = 'app_theme_image_path';
  static const String _imageScrimPrefsKey = 'app_theme_image_scrim';
  static const String _nicknamePrefsKey = 'app_nickname';
  static const String _nicknameFlagPrefsKey = 'app_nickname_configured';
  static const List<String> supportedLanguagePreferences = [
    'system',
    'ja',
    'en',
    'zh',
  ];
  static const List<String> supportedThemePreferences = [
    'dark',
    'light',
    'pink',
    'skyblue',
    'lime',
    'image',
  ];

  final ApiClient _remoteClient;
  final OfflineBackend _offlineBackend;
  OracleBackend _backend;
  bool _offlineMode = false;

  bool _initialized = false;
  bool _loading = false;
  String? _errorMessage;
  String? _infoMessage;

  String _languagePreference = 'system';
  String _themePreference = 'dark';
  String? _themeImagePath;
  double _imageScrim = 0.55;
  String _nickname = '';
  bool _nicknameConfigured = false;

  String _userId;
  String _plan = 'free';
  int _tickets = 0;
  int _visitCount = 0;

  List<ThemeModel> _themes = const [];
  List<DeckModel> _decks = const [];
  List<AnnouncementModel> _announcements = const [];
  List<ProductModel> _products = const [];
  List<HistoryItemModel> _history = const [];
  List<CardModel> _cards = const [];
  String _cardSearchQuery = '';
  String? _cardDeckFilter;

  List<ExternalLinkModel> _shopLinks = const [];
  List<ExternalLinkModel> _consultationLinks = const [];
  List<ExternalLinkModel> _liveLinks = const [];
  List<LiveEventModel> _liveEvents = const [];

  String? _selectedDeckId;
  String? _selectedThemeId;
  String? _sessionId;
  Map<String, int> _pileSizes = const {};
  int? _selectedPile;
  int _selectedCardIndex = 1;
  ReadingResultModel? _latestResult;

  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get offlineMode => _offlineMode;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;

  String get languagePreference => _languagePreference;

  /// MaterialApp.locale へ渡す値。'system' の場合は null（端末設定に従う）。
  Locale? get appLocale =>
      _languagePreference == 'system' ? null : Locale(_languagePreference);

  String get themePreference => _themePreference;
  String? get themeImagePath => _themeImagePath;
  double get imageScrim => _imageScrim;

  String get nickname => _nickname;
  bool get nicknameConfigured => _nicknameConfigured;

  /// ホーム等で表示する呼び名。未設定時はニックネーム→内部IDの順にフォールバック。
  String get displayName => _nickname.isNotEmpty ? _nickname : _userId;

  String get userId => _userId;
  String get plan => _plan;
  int get tickets => _tickets;
  int get visitCount => _visitCount;

  List<ThemeModel> get themes => _themes;
  List<DeckModel> get decks => _decks;
  List<AnnouncementModel> get announcements => _announcements;
  List<ProductModel> get products => _products;
  List<HistoryItemModel> get history => _history;
  List<CardModel> get cards => _cards;
  String get cardSearchQuery => _cardSearchQuery;
  String? get cardDeckFilter => _cardDeckFilter;
  List<ExternalLinkModel> get shopLinks => _shopLinks;
  List<ExternalLinkModel> get consultationLinks => _consultationLinks;
  List<ExternalLinkModel> get liveLinks => _liveLinks;
  List<LiveEventModel> get liveEvents => _liveEvents;

  String? get selectedDeckId => _selectedDeckId;
  String? get selectedThemeId => _selectedThemeId;
  String? get sessionId => _sessionId;
  Map<String, int> get pileSizes => _pileSizes;
  int? get selectedPile => _selectedPile;
  int get selectedCardIndex => _selectedCardIndex;
  ReadingResultModel? get latestResult => _latestResult;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _loadLanguagePreference();
    await _runOperation(() async {
      await _chooseBackend();
      await _login(_userId);
      if (premiumUnlocked) {
        await _activatePremiumUnlock();
      }
      await _loadInitialData();
      _initialized = true;
    }, clearInfo: false);
  }

  /// リモート到達性を確認し、到達不能ならオフラインエンジンへ切り替える。
  /// Wi-Fi初回接続はウォームアップ（ARP解決等）で1回目が
  /// タイムアウトし得るため、最大2回試行して偽陰性を防ぐ。
  Future<void> _chooseBackend() async {
    for (var attempt = 0; attempt < 2; attempt++) {
      final healthy = await _remoteClient.checkHealth();
      if (healthy) {
        _backend = _remoteClient;
        _offlineMode = false;
        return;
      }
    }
    _backend = _offlineBackend;
    _offlineMode = true;
    // オフラインでも占い機能は内蔵エンジンで完結するため、状態そのものは通知しない。
    // 実際に使えない機能（問い合わせ・通知登録）の画面側で理由を示す。
    // 状態は [offlineMode] として保持し、各画面が必要に応じて参照する。
  }

  Future<void> _loadLanguagePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_languagePrefsKey);
      if (stored != null && supportedLanguagePreferences.contains(stored)) {
        _languagePreference = stored;
      }
      final storedTheme = prefs.getString(_themePrefsKey);
      if (storedTheme != null && supportedThemePreferences.contains(storedTheme)) {
        _themePreference = storedTheme;
      }
      _themeImagePath = prefs.getString(_themeImagePrefsKey);
      _imageScrim = prefs.getDouble(_imageScrimPrefsKey) ?? 0.55;
      _nickname = prefs.getString(_nicknamePrefsKey) ?? '';
      _nicknameConfigured = prefs.getBool(_nicknameFlagPrefsKey) ?? false;
    } catch (_) {
      // 表示設定の読込失敗は既定（system言語・ダークテーマ）で継続する
    }
    notifyListeners();
  }

  Future<void> setThemePreference(String preference) async {
    if (!supportedThemePreferences.contains(preference)) {
      return;
    }
    _themePreference = preference;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefsKey, preference);
    } catch (_) {
      // 保存失敗時も画面上の状態は反映済み
    }
  }

  /// ユーザー画像テーマの画像パスを設定する（端末内のみ保存・サーバー送信なし）。
  Future<void> setThemeImagePath(String path) async {
    _themeImagePath = path;
    _themePreference = 'image';
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeImagePrefsKey, path);
      await prefs.setString(_themePrefsKey, 'image');
    } catch (_) {
      // 保存失敗時も画面上の状態は反映済み
    }
  }

  /// 画像テーマのスクリム濃度（0.2〜0.85）。白飛び/暗すぎ画像の可読性調整用。
  Future<void> setImageScrim(double value) async {
    _imageScrim = value.clamp(0.2, 0.85);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_imageScrimPrefsKey, _imageScrim);
    } catch (_) {
      // 保存失敗時も画面上の状態は反映済み
    }
  }

  Future<void> saveNickname(String rawName) async {
    await _runOperation(() async {
      final result = await _backend.updateProfile(
        userId: _userId,
        displayName: rawName,
      );
      _nickname = result['display_name'] as String;
      _nicknameConfigured = true;
      _infoMessage = StateMessages.nicknameSaved;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_nicknamePrefsKey, _nickname);
        await prefs.setBool(_nicknameFlagPrefsKey, true);
      } catch (_) {
        // 保存失敗時もアプリ内の状態は反映済み
      }
    });
  }

  Future<void> deleteHistoryItem(String historyId) async {
    await _runOperation(() async {
      await _backend.deleteHistory(userId: _userId, historyId: historyId);
      final raw = await _backend.getHistory(userId: _userId);
      _history = raw
          .map((item) => HistoryItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
      _infoMessage = StateMessages.historyDeleted;
    });
  }

  Future<void> setLanguagePreference(String preference) async {
    if (!supportedLanguagePreferences.contains(preference)) {
      return;
    }
    _languagePreference = preference;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languagePrefsKey, preference);
    } catch (_) {
      // 保存失敗時もアプリ内の表示言語は反映済みのため継続する
    }
  }

  Future<void> _activatePremiumUnlock() async {
    // 有料機能解放版: 起動ごとにサブスクリプション特典を復元し、
    // 3枚引き・履歴無制限などの有料機能を解放する（restoreTicket20と同型の既存経路を流用）。
    final restored = await _backend.restorePurchase(
      userId: _userId,
      productCode: 'subscription_monthly_500',
      restoreReceiptId:
          'premium-unlock-${DateTime.now().millisecondsSinceEpoch}',
    );
    _plan = restored['plan'] as String;
    _tickets = restored['tickets'] as int;
    _infoMessage = StateMessages.premiumUnlocked;
  }

  Future<void> retryLastLoad() async {
    await refreshAll();
  }

  Future<void> refreshAll() async {
    await _runOperation(() async {
      // オフライン中の再読込では、リモート復帰を試みる（復帰できればオンラインへ戻る）
      if (_offlineMode) {
        final healthy = await _remoteClient.checkHealth();
        if (healthy) {
          _backend = _remoteClient;
          _offlineMode = false;
          await _login(_userId);
          if (premiumUnlocked) {
            await _activatePremiumUnlock();
          }
        }
      }
      await _loadInitialData();
    }, clearInfo: false);
  }

  Future<void> fetchHistory() async {
    await _runOperation(() async {
      final raw = await _backend.getHistory(userId: _userId);
      _history = raw
          .map((item) => HistoryItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }, clearInfo: false);
  }

  void setCardSearchQuery(String query) {
    _cardSearchQuery = query;
    notifyListeners();
  }

  void setCardDeckFilter(String? deckId) {
    _cardDeckFilter = deckId;
    notifyListeners();
  }

  Future<void> loadCardLibrary({bool force = false}) async {
    if (!force && _cards.isNotEmpty) {
      return;
    }

    await fetchCards(
      query: _cardSearchQuery,
      deckId: _cardDeckFilter,
    );
  }

  Future<void> fetchCards({
    String? query,
    String? deckId,
  }) async {
    await _runOperation(() async {
      _cardSearchQuery = query ?? _cardSearchQuery;
      _cardDeckFilter = deckId;

      final raw = await _backend.getCards(
        deckId: _cardDeckFilter,
        query: _cardSearchQuery,
      );
      _cards = raw
          .map((item) => CardModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }, clearInfo: false);
  }

  Future<void> loadRonRoomData({bool force = false}) async {
    if (!force && _liveLinks.isNotEmpty && _liveEvents.isNotEmpty) {
      return;
    }

    await _runOperation(() async {
      final liveLinksRaw = await _backend.getLiveLinks();
      final liveEventsRaw = await _backend.getLiveEvents();

      _liveLinks = liveLinksRaw
          .map((item) => ExternalLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();
      _liveEvents = liveEventsRaw
          .map((item) => LiveEventModel.fromJson(item as Map<String, dynamic>))
          .toList();

      // U-14表示時の主要導線イベント
      await _backend.trackAnalyticsEvent(
        eventName: 'live_room_opened',
        userId: _userId,
        properties: {'source': 'ron_room_screen'},
      );
    }, clearInfo: false);
  }

  Future<void> loadShopLinks({bool force = false}) async {
    if (!force && _shopLinks.isNotEmpty) {
      return;
    }

    await _runOperation(() async {
      final raw = await _backend.getShopLinks();
      _shopLinks = raw
          .map((item) => ExternalLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }, clearInfo: false);
  }

  Future<void> loadConsultationLinks({bool force = false}) async {
    if (!force && _consultationLinks.isNotEmpty) {
      return;
    }

    await _runOperation(() async {
      final raw = await _backend.getConsultationLinks();
      _consultationLinks = raw
          .map((item) => ExternalLinkModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }, clearInfo: false);
  }

  Future<void> trackExternalLinkClick({
    required String category,
    required String linkId,
  }) async {
    final eventName = switch (category) {
      'shop' => 'shop_link_clicked',
      'consultation' => 'consultation_link_clicked',
      'live' => 'live_room_opened',
      _ => 'app_open',
    };

    try {
      await _backend.trackAnalyticsEvent(
        eventName: eventName,
        userId: _userId,
        properties: {
          'link_id': linkId,
          'category': category,
        },
      );
    } catch (_) {
      // 分析記録失敗はユーザー操作を阻害しない
    }
  }

  void selectDeck(String deckId) {
    _selectedDeckId = deckId;
    notifyListeners();
  }

  void selectTheme(String themeId) {
    _selectedThemeId = themeId;
    notifyListeners();
  }

  void selectCardIndex(int cardIndex) {
    _selectedCardIndex = cardIndex;
    notifyListeners();
  }

  Future<void> startReadingFlow({int drawCount = 1}) async {
    await _runOperation(() async {
      if (_selectedDeckId == null || _selectedThemeId == null) {
        throw StateError(StateMessages.selectDeckTheme);
      }

      final started = await _backend.startReading(
        userId: _userId,
        themeId: _selectedThemeId!,
        deckId: _selectedDeckId!,
        drawCount: drawCount,
      );

      _sessionId = started['session_id'] as String;
      _pileSizes = const {};
      _selectedPile = null;
      _selectedCardIndex = 1;
      _latestResult = null;
      _infoMessage = StateMessages.sessionStarted;
    });
  }

  Future<void> completeShuffle({
    double idleSeconds = 1.2,
    double swipeDistance = 200,
  }) async {
    await _runOperation(() async {
      final currentSessionId = _sessionId;
      if (currentSessionId == null) {
        throw StateError(StateMessages.sessionNotStarted);
      }

      final pile = await _backend.completeShuffle(
        sessionId: currentSessionId,
        idleSeconds: idleSeconds,
        swipeDistance: swipeDistance,
      );
      _pileSizes = (pile['pile_sizes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      _infoMessage = StateMessages.shuffleCompleted;
    });
  }

  Future<void> choosePile(int pileIndex) async {
    await _runOperation(() async {
      final currentSessionId = _sessionId;
      if (currentSessionId == null) {
        throw StateError(StateMessages.sessionNotStarted);
      }

      final pile = await _backend.selectPile(
        sessionId: currentSessionId,
        pileIndex: pileIndex,
      );
      _pileSizes = (pile['pile_sizes'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
      _selectedPile = pileIndex;
      _selectedCardIndex = 1;
      _infoMessage = StateMessages.pileSelected;
    });
  }

  Future<void> revealCard() async {
    await _runOperation(() async {
      final currentSessionId = _sessionId;
      if (currentSessionId == null) {
        throw StateError(StateMessages.sessionNotStarted);
      }

      final result = await _backend.selectCard(
        sessionId: currentSessionId,
        cardIndex: _selectedCardIndex,
      );
      _latestResult = ReadingResultModel.fromJson(result);
      _infoMessage = StateMessages.cardRevealed;
    });
  }

  Future<void> reloadResult() async {
    await _runOperation(() async {
      final currentSessionId = _sessionId;
      if (currentSessionId == null) {
        throw StateError(StateMessages.sessionNotStarted);
      }

      final result = await _backend.getReadingResult(currentSessionId);
      _latestResult = ReadingResultModel.fromJson(result);
    }, clearInfo: false);
  }

  Future<void> saveCurrentHistory() async {
    await _runOperation(() async {
      final currentSessionId = _sessionId;
      if (currentSessionId == null) {
        throw StateError(StateMessages.sessionNotStarted);
      }

      await _backend.saveHistory(userId: _userId, sessionId: currentSessionId);
      final raw = await _backend.getHistory(userId: _userId);
      _history = raw
          .map((item) => HistoryItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
      _infoMessage = StateMessages.historySaved;
    });
  }

  Future<void> restoreTicket20() async {
    await _runOperation(() async {
      final receiptId = 'mobile-restore-${DateTime.now().millisecondsSinceEpoch}';
      final restored = await _backend.restorePurchase(
        userId: _userId,
        productCode: 'ticket_20',
        restoreReceiptId: receiptId,
      );
      _plan = restored['plan'] as String;
      _tickets = restored['tickets'] as int;
      _infoMessage = restored['message'] as String;
    });
  }

  Future<void> registerNotificationToken({required String token}) async {
    await _runOperation(() async {
      final result = await _backend.registerNotificationToken(
        userId: _userId,
        token: token,
      );
      _infoMessage = result['message'] as String;
    });
  }

  Future<void> submitInquiry({
    required String category,
    required String body,
    String? email,
  }) async {
    await _runOperation(() async {
      final result = await _backend.submitInquiry(
        userId: _userId,
        category: category,
        body: body,
        email: email,
      );
      _infoMessage = result['message'] as String;
    });
  }

  Future<void> _loadInitialData() async {
    final themesRaw = await _backend.getThemes();
    final decksRaw = await _backend.getDecks();
    final announcementsRaw = await _backend.getAnnouncements();
    final productsRaw = await _backend.getProducts();
    final historyRaw = await _backend.getHistory(userId: _userId);

    _themes = themesRaw
        .map((item) => ThemeModel.fromJson(item as Map<String, dynamic>))
        .toList();
    _decks = decksRaw
        .map((item) => DeckModel.fromJson(item as Map<String, dynamic>))
        .toList();
    _announcements = announcementsRaw
        .map((item) => AnnouncementModel.fromJson(item as Map<String, dynamic>))
        .toList();
    _products = productsRaw
        .map((item) => ProductModel.fromJson(item as Map<String, dynamic>))
        .toList();
    _history = historyRaw
        .map((item) => HistoryItemModel.fromJson(item as Map<String, dynamic>))
        .toList();

    _selectedDeckId ??= _decks.isNotEmpty ? _decks.first.deckId : null;
    _selectedThemeId ??= _themes.isNotEmpty ? _themes.first.themeId : null;
  }

  Future<void> _login(String userId) async {
    final response = await _backend.loginByUserId(userId);
    final profile = UserProfileModel.fromJson(response);
    _userId = profile.userId;
    _plan = profile.plan;
    _tickets = profile.tickets;
    _visitCount = profile.visitCount;
    // サーバー/オフラインが保持するニックネームを取り込む（内部IDと同一なら未設定扱い）
    final serverName = profile.displayName;
    if (serverName.isNotEmpty && serverName != profile.userId) {
      _nickname = serverName;
      _nicknameConfigured = true;
    }
  }

  Future<void> _runOperation(
    Future<void> Function() operation, {
    bool clearInfo = true,
  }) async {
    _loading = true;
    _errorMessage = null;
    if (clearInfo) {
      _infoMessage = null;
    }
    notifyListeners();

    try {
      await operation();
    } catch (error) {
      _errorMessage = _resolveErrorMessage(error);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _resolveErrorMessage(Object error) {
    if (error is ApiException) {
      try {
        final decoded = jsonDecode(error.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
          return decoded['detail'] as String;
        }
      } catch (_) {
        // JSONではないエラーレスポンスは既定文言で扱う
      }
      return StateMessages.commError(error.statusCode);
    }

    if (error is StateError) {
      return error.message.toString();
    }

    return error.toString();
  }
}
