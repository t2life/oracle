import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oracle_mobile_app/core/network/api_client.dart';
import 'package:oracle_mobile_app/core/offline/offline_backend.dart';
import 'package:oracle_mobile_app/core/state/app_state.dart';
import 'package:oracle_mobile_app/core/state/app_state_scope.dart';
import 'package:oracle_mobile_app/features/home/presentation/home_screen.dart';
import 'package:oracle_mobile_app/features/shell/presentation/main_shell.dart';
import 'package:oracle_mobile_app/l10n/app_localizations.dart';

/// 2026-09-09 ホーム画面6項目の是正に対する回帰テスト。
/// 目的:
///   ① 「ようこそ〜」の挨拶が表示されないこと（項目1）
///   ② 右上アイコンが縦並びで 上から ≡ / LANG / スピーカー であること（項目2）
///   ③ ≡メニューの最初の項目が上端付近にあること（項目5＝旧DrawerHeaderの撤去）
///   ④ シェルのネストNavigatorに shellRouteObserver が配線されていること（項目4）
void main() {
  OracleAppState buildState() => OracleAppState(
        remoteClient: ApiClient(baseUrl: 'http://127.0.0.1:8000'),
        offlineBackend: OfflineBackend(),
      );

  Widget wrap(Widget child, OracleAppState state) {
    return OracleAppStateScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('ja'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          endDrawer: const SecondaryMenuDrawer(),
          body: child,
        ),
      ),
    );
  }

  Finder assetImage(String name) => find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == name,
      );

  testWidgets('ホームに挨拶（ようこそ）が表示されない', (tester) async {
    final state = buildState();
    addTearDown(state.dispose);
    await tester.pumpWidget(wrap(const HomeTab(), state));
    await tester.pump();

    expect(find.textContaining('ようこそ'), findsNothing);
  });

  testWidgets('右上アイコンは縦並びで 上から ≡ / LANG / スピーカー', (tester) async {
    final state = buildState();
    addTearDown(state.dispose);
    await tester.pumpWidget(wrap(const HomeTab(), state));
    await tester.pump();

    final menu = tester.getBottomRight(assetImage('assets/home/icon_menu.png'));
    final lang = tester.getBottomRight(assetImage('assets/home/icon_lang.png'));
    final speaker =
        tester.getBottomRight(assetImage('assets/home/icon_speaker.png'));

    // 縦積み＝右端が揃っていること（アイコンごとに横幅が異なるため右端で判定）
    expect((menu.dx - lang.dx).abs(), lessThan(1.0));
    expect((menu.dx - speaker.dx).abs(), lessThan(1.0));
    // 上から ≡ → LANG → スピーカー の順であること
    expect(menu.dy, lessThan(lang.dy));
    expect(lang.dy, lessThan(speaker.dy));
    // 画面右側にあること
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(menu.dx, greaterThan(screenWidth / 2));
  });

  testWidgets('≡メニューの最初の項目が上端付近にある（旧DrawerHeaderの撤去）', (tester) async {
    final state = buildState();
    addTearDown(state.dispose);
    await tester.pumpWidget(wrap(const HomeTab(), state));
    await tester.pump();

    tester.state<ScaffoldState>(find.byType(Scaffold)).openEndDrawer();
    await tester.pumpAndSettle();

    expect(find.byType(DrawerHeader), findsNothing);
    final firstTile = tester.getTopLeft(find.byType(ListTile).first);
    // 旧実装（DrawerHeader）は約217〜241px。小見出し56px＋SafeAreaのみへ短縮。
    expect(firstTile.dy, lessThan(120.0));
  });

  testWidgets('シェルのネストNavigatorに shellRouteObserver が配線されている', (tester) async {
    final state = buildState();
    addTearDown(state.dispose);
    await tester.pumpWidget(
      OracleAppStateScope(
        state: state,
        child: const MaterialApp(
          locale: Locale('ja'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: MainShell(),
        ),
      ),
    );
    await tester.pump();

    final navigators = tester
        .widgetList<Navigator>(find.byType(Navigator))
        .where((navigator) => navigator.observers.contains(shellRouteObserver));
    expect(navigators, isNotEmpty);
  });
}
