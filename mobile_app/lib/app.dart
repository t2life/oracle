import 'dart:io';

import 'package:flutter/material.dart';

import 'core/network/api_client.dart';
import 'core/offline/offline_backend.dart';
import 'core/routing/app_router.dart';
import 'core/state/app_state.dart';
import 'core/state/app_state_scope.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

class OracleMobileApp extends StatefulWidget {
  const OracleMobileApp({super.key});

  @override
  State<OracleMobileApp> createState() => _OracleMobileAppState();
}

class _OracleMobileAppState extends State<OracleMobileApp> {
  late final OracleAppState _state;

  @override
  void initState() {
    super.initState();
    _state = OracleAppState(
      remoteClient: ApiClient(
        // 接続先はビルド時に注入する（既定はローカル開発用）。
        // 例: --dart-define=ORACLE_API_BASE_URL=http://192.168.40.50:8000
        baseUrl: const String.fromEnvironment(
          'ORACLE_API_BASE_URL',
          defaultValue: 'http://127.0.0.1:8000',
        ),
      ),
      offlineBackend: OfflineBackend(),
    );
    _state.initialize();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OracleAppStateScope(
      state: _state,
      child: AnimatedBuilder(
        animation: _state,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          locale: _state.appLocale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          theme: resolveAppTheme(_state.themePreference),
          initialRoute: AppRoute.splash.path,
          onGenerateRoute: buildRoute,
          builder: (context, child) => _AppBackground(
            state: _state,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// 全画面共通の背景層。'image'選択かつ画像パスが有効ならその端末画像を、
/// それ以外はホーム画面と同じ寺院背景（キャラ・宝石を含まない素材）を全画面に敷き、
/// 可読性のためスクリム（濃度は調整可）を重ねる。
///
/// 各画面のScaffoldは透過（`app_theme.dart`）のため、ここで敷いた背景が全画面に出る。
class _AppBackground extends StatelessWidget {
  const _AppBackground({required this.state, required this.child});

  /// ホーム画面と共有する既定背景（キャラ動画・宝石を含まない寺院の素材）。
  static const String _defaultAsset = 'assets/home/bg_temple.png';

  /// 黒文字を前提とするライト系プリセット。暗いスクリムでは文字が沈むため、
  /// 白側のスクリムを敷く。
  static const Set<String> _lightPreferences = <String>{
    'light',
    'pink',
    'skyblue',
    'lime',
  };

  /// 既定背景（寺院）は明るく情報量が多いため、本文が読める濃度を下限として保証する。
  /// ユーザーが選んだ画像テーマでは従来どおり `imageScrim` をそのまま尊重する。
  static const double _defaultScrimMin = 0.55;
  static const double _lightScrimMin = 0.70;

  final OracleAppState state;
  final Widget child;

  /// ユーザー画像テーマが有効で、ファイルが実在する時だけその端末画像を使う。
  File? _userImageFile() {
    final path = state.themeImagePath;
    if (state.themePreference == 'image' && path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return file;
      }
    }
    return null;
  }

  /// スクリム。既定背景はライト系＝白／それ以外＝黒で、可読性の下限を適用する。
  Color _scrimColor({required bool useDefaultBackground}) {
    if (!useDefaultBackground) {
      return Colors.black.withValues(alpha: state.imageScrim);
    }
    final isLight = _lightPreferences.contains(state.themePreference);
    final floor = isLight ? _lightScrimMin : _defaultScrimMin;
    final alpha = state.imageScrim < floor ? floor : state.imageScrim;
    return (isLight ? Colors.white : Colors.black).withValues(alpha: alpha);
  }

  @override
  Widget build(BuildContext context) {
    final userImage = _userImageFile();
    return Stack(
      children: [
        Positioned.fill(
          child: userImage != null
              ? Image.file(userImage, fit: BoxFit.cover)
              : Image.asset(_defaultAsset, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: _scrimColor(useDefaultBackground: userImage == null),
          ),
        ),
        child,
      ],
    );
  }
}
