import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../card_library/presentation/card_library_screen.dart';
import '../../consultation/presentation/consultation_screen.dart';
import '../../deck_selection/presentation/deck_selection_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../home/presentation/widgets/home_character_video.dart';
import '../../my_page/presentation/my_page_screen.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../../core/config/app_links.dart';
import '../../shared/app_actions.dart';
import '../../shop/presentation/shop_screen.dart';

/// シェル内ネストNavigatorの画面遷移を購読するオブザーバ。
/// ホームの動画（[HomeCharacterVideo]）が「別画面に覆われた／戻ってきた」を知り、
/// 覆われている間の再生を止めるために使う（覆われたまま再生し続けると、
/// 24fps・768x1024のデコードが遷移アニメと競合して切替が遅れる）。
final RouteObserver<PageRoute<dynamic>> shellRouteObserver =
    RouteObserver<PageRoute<dynamic>>();

/// 下部ナビの「選択中セル」。タップ領域が失われる退行をテストで検出するための目印。
const Key dashboardNavSelectedKey = Key('dashboard-nav-selected');

/// ホームタブの位置（戻るキーの寄せ先）。
const int _kHomeTabIndex = 0;

/// ホームで戻るキーを押してから「もう一度で終了」を受け付ける猶予。
const Duration _kExitConfirmWindow = Duration(seconds: 2);

/// 下部タブの切替を、ネストNavigator内の子孫（ホームのオーブ等）へ公開するスコープ。
/// [MainShell] がNavigatorの上位に提供する。子孫は `ShellScope.of(context)?.selectTab(i)`。
class ShellScope extends InheritedWidget {
  const ShellScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  /// 指定インデックスの下部タブへ切替える。
  final ValueChanged<int> selectTab;

  static ShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellScope>();

  @override
  bool updateShouldNotify(ShellScope oldWidget) =>
      selectTab != oldWidget.selectTab;
}

/// アプリの主画面シェル（2026-09-08 ダッシュボード画像ナビ＋タブ再編）。
/// - 下部ナビは `ダッシュボード.png`（ホーム/カード/ショップ/鑑定/マイページ）を全画面で常時表示。
/// - 占う＝ホーム中央オーブ、ロンの部屋＝≡メニューへ移動。
/// - フロー/二次画面はネストNavigatorへpushされ、下部ナビは隠れない。
/// - Androidの戻るキーはネスト内スタックを優先pop（ルートで初めてアプリ終了）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<String> _tabRoots = [
    '/home',
    '/card-library',
    '/shop',
    '/consultation',
    '/my-page',
  ];

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  int _index = _kHomeTabIndex;

  /// 直近に戻るキーを押した時刻（ホームでの2回押し終了の判定用）。
  DateTime? _lastBackAt;

  /// 指定タブへ切替（効果音は鳴らさない＝呼び出し側の責務）。
  /// タブ切替はネストのルートを差し替える（案A: フローは破棄＝一方通行の儀式性を維持）。
  void _switchTo(int value) {
    final startedAt = DateTime.now();
    setState(() => _index = value);
    _navKey.currentState?.pushNamedAndRemoveUntil(
      _tabRoots[value],
      (route) => false,
    );
    // 切替の所要時間（同期処理ぶん）を計測する。実機で遅延の切り分けに使う。
    debugPrint(
      'シェル: タブ切替 index=$value route=${_tabRoots[value]} '
      '所要=${DateTime.now().difference(startedAt).inMilliseconds}ms',
    );
  }

  /// ネスト内の画面生成（タブのルート → なければフロー/二次画面）。
  Route<dynamic> _shellRoute(RouteSettings settings) {
    final builder = _shellTabBuilder(settings.name) ?? buildShellChild;
    return MaterialPageRoute<void>(settings: settings, builder: builder);
  }

  void _onSelectTab(int value) {
    SoundService.instance.play(OracleSound.tap);
    if (value == _index) {
      // 同じタブ再タップ＝そのタブのルートまで戻す（≡から開いた画面等を離脱）
      final navigator = _navKey.currentState;
      debugPrint('シェル: 同一タブ再タップ index=$value 戻り可=${navigator?.canPop()}');
      navigator?.popUntil((route) => route.isFirst);
    } else {
      _switchTo(value);
    }
  }

  /// Androidの戻るキーの扱い（2026-09-09 A案）。
  /// ①ネスト内に戻り先があれば戻す →②ホーム以外のタブならホームタブへ →
  /// ③ホームでは「もう一度押すと終了」を出し、2秒以内の再押下でアプリを終了する。
  /// （従来は③が無く、戻るキーが何も起こさずアプリも終了できなかった）
  void _handleSystemBack(BuildContext context) {
    final navigator = _navKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
      return;
    }
    if (_index != _kHomeTabIndex) {
      _switchTo(_kHomeTabIndex);
      return;
    }
    final now = DateTime.now();
    final last = _lastBackAt;
    if (last == null || now.difference(last) > _kExitConfirmWindow) {
      _lastBackAt = now;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.exitAppConfirm),
          duration: _kExitConfirmWindow,
        ),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        _handleSystemBack(context);
      },
      child: Scaffold(
        body: ShellScope(
          selectTab: _switchTo,
          child: Navigator(
            key: _navKey,
            observers: <NavigatorObserver>[shellRouteObserver],
            initialRoute: _tabRoots[0],
            // 既定の初期ルート生成は '/home' をパス分割して '/' も積むため、
            // 最下段が既定分岐（デッキ選択）になり、同一タブ再タップやAndroidの戻るで
            // そこへ落ちていた（2026-09-09の不具合）。初期ルートは1本だけにする。
            onGenerateInitialRoutes: (_, initialRoute) => <Route<dynamic>>[
              _shellRoute(RouteSettings(name: initialRoute)),
            ],
            onGenerateRoute: _shellRoute,
          ),
        ),
        bottomNavigationBar: _DashboardNav(
          index: _index,
          onSelect: _onSelectTab,
        ),
      ),
    );
  }
}

/// タブのルート画面（Scaffold＋AppBar付き）。二次画面はapp_routerのbuildShellChild経由。
WidgetBuilder? _shellTabBuilder(String? name) {
  switch (name) {
    case '/home':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.home,
            body: HomeTab(),
            immersive: true,
          );
    case '/card-library':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.cards,
            body: CardLibraryTab(),
          );
    case '/shop':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.shop,
            body: ShopTab(),
          );
    case '/consultation':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.consultation,
            body: ConsultationTab(),
          );
    case '/my-page':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.myPage,
            body: MyPageTab(),
          );
    // 占うオーブから開始する託宣フロー（下部タブではないがネストへpushされる）。
    case '/deck-selection':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.reading,
            body: DeckSelectionBody(),
          );
  }
  return null;
}

enum _ShellTitle { home, reading, cards, shop, consultation, myPage }

/// タブのルート画面共通Scaffold（AppBar右端にスピーカー＋≡メニュー）。
class _ShellTabScaffold extends StatelessWidget {
  const _ShellTabScaffold({
    required this.titleKey,
    required this.body,
    this.immersive = false,
  });

  final _ShellTitle titleKey;
  final Widget body;

  /// 没入表示（ホーム）：AppBarを持たず本文を上端まで敷く。操作はフローティングUIが担う。
  final bool immersive;

  String _title(AppLocalizations l10n) {
    switch (titleKey) {
      case _ShellTitle.home:
        return l10n.homeTitle;
      case _ShellTitle.reading:
        return l10n.tabReading;
      case _ShellTitle.cards:
        return l10n.tabCards;
      case _ShellTitle.shop:
        return l10n.shopScreenTitle;
      case _ShellTitle.consultation:
        return l10n.consultationScreenTitle;
      case _ShellTitle.myPage:
        return l10n.myPageTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (immersive) {
      // AppBarなし＝本文が上端（ステータスバー背後）まで没入。スピーカー/≡/LANGは
      // 本文側のフローティングUIが担う。endDrawerは維持（≡から開く）。
      return Scaffold(
        endDrawer: const SecondaryMenuDrawer(),
        // ドロワーを閉じた直後はキャラ動画の描画が止まる（実機確認）ため張り直す。
        onEndDrawerChanged: (isOpen) {
          if (!isOpen) {
            requestHomeVideoRefresh();
          }
        },
        body: body,
      );
    }
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_title(l10n)),
        actions: [
          // 占いフローは一方通行のため、離脱導線をここに置く（iOSでも同じ）。
          if (titleKey == _ShellTitle.reading) const FlowExitAction(),
          const SpeakerToggle(),
          Builder(
            builder: (context) => IconButton(
              tooltip: l10n.menuTooltip,
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openEndDrawer(),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      endDrawer: const SecondaryMenuDrawer(),
      // 下部ナビと本文の間に余白を確保（edge-to-edge起因の重なり防止）
      body: SafeArea(top: false, child: body),
    );
  }
}

/// 下部ナビ（`ダッシュボード.png` ＋ 5等分のタップ判定）。
/// タブ: ホーム(0)/カード(1)/ショップ(2)/鑑定(3)/マイページ(4)。
class _DashboardNav extends StatelessWidget {
  const _DashboardNav({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // 素材の上端は透過しているため、絵柄と同じ濃紺を下地に敷く
    // （敷かないと背後のScaffold地色＝テーマ色が白い帯として覗く）。
    return ColoredBox(
      color: kOracleDashboardBase,
      child: SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 371 / 1536; // 画像アスペクト比（nav_dashboard.png）
          return SizedBox(
            width: w,
            height: h,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/home/nav_dashboard.png',
                  fit: BoxFit.fill,
                ),
                Row(
                  children: List<Widget>.generate(5, (i) {
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onSelect(i),
                        // 選択中のセルも必ず領域いっぱいに広げる。
                        // 子を持たないDecoratedBoxは0x0になり、選択中タブだけ
                        // タップ判定と発光が消えていた（2026-09-09の不具合）。
                        child: i == index
                            ? const DecoratedBox(
                                key: dashboardNavSelectedKey,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    radius: 0.85,
                                    colors: [Color(0x33FFFFFF), Color(0x00FFFFFF)],
                                  ),
                                ),
                                child: SizedBox.expand(),
                              )
                            : const SizedBox.expand(),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

/// ≡メニュー（二次導線）。「託宣とは」「カードメッセージについて」を「お知らせ」の上に。
/// ロンの部屋はここから開く（下部ナビはショップ/鑑定に譲った）。
class SecondaryMenuDrawer extends StatelessWidget {
  const SecondaryMenuDrawer({super.key});

  void _push(BuildContext context, String route) {
    SoundService.instance.play(OracleSound.tap);
    Navigator.of(context).pop();
    Navigator.of(context).pushNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Drawer(
      // ステータスバーぶんだけ避け、以降は上端から項目を並べる。
      // （旧実装のDrawerHeaderは高さ statusBar+161＋余白8 を占め、
      //   最初の項目を約220px押し下げていた＝「下寄せ」に見える原因）
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // 2026-09-10 承認: 見出し行（アプリ名）は出さない。
            // 最初の項目が上端に来る（旧DrawerHeaderの撤去と同じ狙い）。
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(l10n.aboutOracleTitle),
              onTap: () => _push(context, '/about-oracle'),
            ),
            ListTile(
              leading: const Icon(Icons.style_outlined),
              title: Text(l10n.aboutCardsTitle),
              onTap: () => _push(context, '/about-cards'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.campaign_outlined),
              title: Text(l10n.announcementsTitle),
              onTap: () => _push(context, '/announcements'),
            ),
            ListTile(
              leading: const Icon(Icons.live_tv_outlined),
              title: Text(l10n.ronRoomTitle),
              onTap: () => _push(context, '/ron-room'),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(l10n.historyTitle),
              onTap: () => _push(context, '/history'),
            ),
            const Divider(),
            // 2026-09-10 承認: 「プラン購入」を外し、アプリ本体まわりの導線を置く。
            ListTile(
              // ストア未公開のあいだは押せない（掲載前のURLは開けない）
              enabled: AppLinks.storeListingUrl.isNotEmpty,
              leading: const Icon(Icons.star_outline),
              title: Text(l10n.rateApp),
              subtitle: AppLinks.storeListingUrl.isEmpty
                  ? Text(l10n.comingSoon)
                  : null,
              onTap: AppLinks.storeListingUrl.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      openStoreListing(context);
                    },
            ),
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: Text(l10n.shareApp),
              onTap: () {
                Navigator.of(context).pop();
                shareApp(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.apps_outlined),
              title: Text(l10n.developerApps),
              onTap: () {
                Navigator.of(context).pop();
                openDeveloperApps(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l10n.goToInquiry),
              onTap: () => _push(context, '/inquiry'),
            ),
          ],
        ),
      ),
    );
  }
}

