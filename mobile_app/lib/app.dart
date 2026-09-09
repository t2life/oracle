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
          // 既定の初期ルート生成は '/splash' をパス分割し '/' も併せて積むため、
          // 既定分岐でMainShellがもう1つ生成され、ホームのキャラ動画が
          // 二重に再生され続けていた（2026-09-09の不具合）。初期ルートは1本だけにする。
          onGenerateInitialRoutes: (initial) => <Route<dynamic>>[
            buildRoute(RouteSettings(name: initial)),
          ],
          onGenerateRoute: buildRoute,
          builder: (context, child) => _ThemeImageBackground(
            state: _state,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

/// ユーザー画像テーマの背景合成。'image'選択かつ画像パスが有効な時のみ、
/// 端末画像を全画面に敷き、可読性のため暗色スクリム（濃度は調整可）を重ねる。
class _ThemeImageBackground extends StatelessWidget {
  const _ThemeImageBackground({required this.state, required this.child});

  final OracleAppState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = state.themeImagePath;
    if (state.themePreference != 'image' || path == null || path.isEmpty) {
      return child;
    }
    final file = File(path);
    if (!file.existsSync()) {
      return child;
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Image.file(file, fit: BoxFit.cover),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: Colors.black.withValues(alpha: state.imageScrim),
          ),
        ),
        child,
      ],
    );
  }
}
