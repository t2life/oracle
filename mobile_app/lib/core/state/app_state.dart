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
  /// 端末に紐づくユーザーID。引継ぎコードでアカウントを移すため、
  /// 初回起動で1つ作って以後は使い回す（旧ビルドは既定IDのまま引き継ぐ）。
  static const String _userIdPrefsKey = 'app_user_id';
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

  List<SpreadModel> _spreads = const [];

  String? _selectedDeckId;
  String? _selectedThemeId;

  /// 選択中のスプレッド（占う種別）。既定は本日の託宣。
  String _selectedSpreadId = 'daily';

  /// フリーリーディングで引く枚数（他のスプレッドでは使わない）。
  int _freeDrawCount = 3;

  /// 相談内容（リーディングのみ。託宣では常に空）。
  String _questionText = '';

  String? _sessionId;
  Map<String, int> _pileSizes = const {};
  int? _selectedPile;
  int _selectedCardIndex = 1;

  /// 複数枚リーディングで確定済みの枚数（結果が出ると0へ戻る）。
  int _selectedCardCount = 0;
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

  List<SpreadModel> get spreads => _spreads;

  /// 本日の託宣のスプレッド（マスタに無ければ null）。
  SpreadModel? get oracleSpread {
    for (final spread in _spreads) {
      if (spread.isOracle) {
        return spread;
      }
    }
    return null;
  }

  /// リーディングのスプレッド一覧（3枚・5枚・7枚・フリー）。
  List<SpreadModel> get readingSpreads =>
      _spreads.where((spread) => !spread.isOracle).toList();

  /// 選択中のスプレッド定義。未取得時は null（画面は読込中を出す）。
  SpreadModel? get selectedSpread {
    for (final spread in _spreads) {
      if (spread.spreadId == _selectedSpreadId) {
        return spread;
      }
    }
    return null;
  }

  String get selectedSpreadId => _selectedSpreadId;
  int get freeDrawCount => _freeDrawCount;
  String get questionText => _questionText;

  /// いま進行中の導線が本日の託宣か（＝テーマ選択を現状維持にする分岐）。
  bool get isOracleFlow => selectedSpread?.isOracle ?? (_selectedSpreadId == 'daily');

  /// 今回引く枚数（フリーのみ利用者指定・他はスプレッド定義どおり）。
  int get plannedDrawCount =>
      selectedSpread?.drawCountFor(_freeDrawCount) ?? 1;

  String? get selectedDeckId => _selectedDeckId;
  String? get selectedThemeId => _selectedThemeId;
  String? get sessionId => _sessionId;
  Map<String, int> get pileSizes => _pileSizes;
  int? get selectedPile => _selectedPile;
  int get selectedCardIndex => _selectedCardIndex;

  /// これまでに確定した枚数（カード選択画面の「n枚目」表示に使う）。
  int get selectedCardCount => _selectedCardCount;
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
      final storedUserId = prefs.getString(_userIdPrefsKey);
      if (storedUserId != null && storedUserId.isNotEmpty) {
        _userId = storedUserId;
      } else {
        // 初回起動: 端末ごとに別のアカウントになるIDを1つ作って覚える。
        // （固定IDのままだと全端末が同じアカウントになり引継ぎが成立しない）
        _userId =
            'device_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
            '_${identityHashCode(this).toRadixString(36)}';
        await prefs.setString(_userIdPrefsKey, _userId);
      }
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

  /// スプレッド定義を取得する（実行可否＝プラン・チケット残数の判定込み）。
  /// 種別選択画面を開くたびに残数が変わり得るため既定で取り直す。
  Future<void> loadSpreads({bool force = true}) async {
    if (!force && _spreads.isNotEmpty) {
      return;
    }
    await _runOperation(() async {
      final raw = await _backend.getSpreads(userId: _userId);
      _spreads = raw
          .map((item) => SpreadModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }, clearInfo: false);
  }

  /// 占う種別を確定する（本日の託宣＝daily、リーディング＝スプレッド選択画面で確定）。
  /// 託宣へ切り替えたときは相談内容を捨てる（託宣は相談内容を持たない仕様）。
  void selectSpread(String spreadId) {
    _selectedSpreadId = spreadId;
    if (isOracleFlow) {
      _questionText = '';
    }
    notifyListeners();
  }

  /// フリーリーディングの枚数（最小〜最大はスプレッド定義が決める）。
  void setFreeDrawCount(int count) {
    _freeDrawCount = count;
    notifyListeners();
  }

  /// 相談内容。上限はサーバーと同じ3000文字（超過分は入力側で切る）。
  void setQuestionText(String text) {
    _questionText = text;
    notifyListeners();
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

  /// リーディング（または本日の託宣）を開始する。
  /// 枚数・課金条件はスプレッド定義が単一の真実源なので引数では受け取らない。
  Future<void> startReadingFlow() async {
    await _runOperation(() async {
      if (_selectedDeckId == null || _selectedThemeId == null) {
        throw StateError(StateMessages.selectDeckTheme);
      }

      final started = await _backend.startReading(
        userId: _userId,
        themeId: _selectedThemeId!,
        deckId: _selectedDeckId!,
        drawCount: plannedDrawCount,
        spreadId: _selectedSpreadId,
        questionText: isOracleFlow ? '' : _questionText,
      );

      _sessionId = started['session_id'] as String;
      _pileSizes = const {};
      _selectedPile = null;
      _selectedCardIndex = 1;
      _selectedCardCount = 0;
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
      if (result == null) {
        // 複数枚リーディングで必要枚数に未達＝カード選択を続ける（結果はまだ出ない）。
        _selectedCardCount += 1;
        _infoMessage = StateMessages.cardRevealed;
        return;
      }
      _latestResult = ReadingResultModel.fromJson(result);
      _selectedCardCount = 0;
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

  /// 商品を購入（現状はストア未接続のため既存の復元APIを流用する単一経路）。
  /// プラン購入画面の各行から商品コードで呼ぶ。
  Future<void> purchaseProduct(String productCode) async {
    await _runOperation(() async {
      final receiptId = 'mobile-restore-${DateTime.now().millisecondsSinceEpoch}';
      final restored = await _backend.restorePurchase(
        userId: _userId,
        productCode: productCode,
        restoreReceiptId: receiptId,
      );
      _plan = restored['plan'] as String;
      _tickets = restored['tickets'] as int;
      _infoMessage = restored['message'] as String;
    });
  }

  /// マイページ等から使う既存の入口（チケット20枚）。実体は [purchaseProduct]。
  Future<void> restoreTicket20() => purchaseProduct('ticket_20');

  /// 機種変更の引継ぎコードを発行する（表示用の整形済みコードと期限を返す）。
  /// 失敗時は [errorMessage] に理由が入り null を返す。
  Future<Map<String, dynamic>?> issueTransferCode() async {
    Map<String, dynamic>? issued;
    await _runOperation(() async {
      issued = await _backend.issueTransferCode(userId: _userId);
    });
    return _errorMessage == null ? issued : null;
  }

  /// 引継ぎコードで、発行元アカウントへ切り替える。
  /// 成功したらこの端末のユーザーIDを差し替えて保存し、データを読み直す。
  Future<bool> redeemTransferCode(String code) async {
    var moved = false;
    await _runOperation(() async {
      final response = await _backend.redeemTransferCode(code: code.trim());
      final profile = UserProfileModel.fromJson(response);
      _userId = profile.userId;
      _plan = profile.plan;
      _tickets = profile.tickets;
      _visitCount = profile.visitCount;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdPrefsKey, _userId);
      await _loadInitialData();
      moved = true;
      _infoMessage = StateMessages.transferCompleted;
    });
    return moved && _errorMessage == null;
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
