import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/routing/app_router.dart';
import '../../../l10n/app_localizations.dart';
import '../../card_library/presentation/card_library_screen.dart';
import '../../deck_selection/presentation/deck_selection_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../my_page/presentation/my_page_screen.dart';
import '../../ron_room/presentation/ron_room_screen.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';

/// アプリの主画面シェル（2026-09-06 ネストNavigator化）。
/// - 下部ナビゲーションバーは**全画面で常時最前面**（フロー/二次画面はシェル内の
///   ネストNavigatorへpushされるため下部ナビが隠れない＝重なり・見切れを根絶）。
/// - AppBarはネスト内の各画面が自前で持つ。シェルはAppBarを持たない。
/// - Androidの戻るキーはネスト内スタックを優先pop（ルートで初めてアプリ終了）。
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const List<String> _tabRoots = [
    '/home',
    '/deck-selection',
    '/card-library',
    '/ron-room',
    '/my-page',
  ];

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  int _index = 0;

  void _onSelectTab(int value) {
    SoundService.instance.play(OracleSound.tap);
    if (value == _index) {
      // 同じタブ再タップ＝そのタブのルートまで戻す（占いフロー等を離脱）
      _navKey.currentState?.popUntil((route) => route.isFirst);
    } else {
      setState(() => _index = value);
      // タブ切替はネストのルートを差し替える（案A: フローは破棄＝一方通行の儀式性を維持）
      _navKey.currentState?.pushNamedAndRemoveUntil(
        _tabRoots[value],
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final navigator = _navKey.currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        body: Navigator(
          key: _navKey,
          initialRoute: _tabRoots[0],
          onGenerateRoute: (settings) {
            final builder = _shellTabBuilder(settings.name) ?? buildShellChild;
            return MaterialPageRoute<void>(
              settings: settings,
              builder: builder,
            );
          },
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onSelectTab,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l10n.homeTitle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.auto_awesome_outlined),
              selectedIcon: const Icon(Icons.auto_awesome),
              label: l10n.tabReading,
            ),
            NavigationDestination(
              icon: const Icon(Icons.style_outlined),
              selectedIcon: const Icon(Icons.style),
              label: l10n.tabCards,
            ),
            NavigationDestination(
              icon: const Icon(Icons.live_tv_outlined),
              selectedIcon: const Icon(Icons.live_tv),
              label: l10n.ronRoomTitle,
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: l10n.myPageTitle,
            ),
          ],
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
          );
    case '/deck-selection':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.reading,
            body: DeckSelectionBody(),
          );
    case '/card-library':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.cards,
            body: CardLibraryTab(),
          );
    case '/ron-room':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.ronRoom,
            body: RonRoomTab(),
          );
    case '/my-page':
      return (_) => const _ShellTabScaffold(
            titleKey: _ShellTitle.myPage,
            body: MyPageTab(),
          );
  }
  return null;
}

enum _ShellTitle { home, reading, cards, ronRoom, myPage }

/// タブのルート画面共通Scaffold（AppBar右端にスピーカー＋≡メニュー）。
class _ShellTabScaffold extends StatelessWidget {
  const _ShellTabScaffold({required this.titleKey, required this.body});

  final _ShellTitle titleKey;
  final Widget body;

  String _title(AppLocalizations l10n) {
    switch (titleKey) {
      case _ShellTitle.home:
        return l10n.homeTitle;
      case _ShellTitle.reading:
        return l10n.tabReading;
      case _ShellTitle.cards:
        return l10n.tabCards;
      case _ShellTitle.ronRoom:
        return l10n.ronRoomTitle;
      case _ShellTitle.myPage:
        return l10n.myPageTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(_title(l10n)),
        actions: [
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

/// ≡メニュー（二次導線）。⑦「託宣とは」「カードメッセージについて」を
/// 「お知らせ」の上に配置。
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
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2350), kOracleMidnight],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Icon(Icons.auto_awesome, color: kOracleGoldBright, size: 32),
            ),
          ),
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
            leading: const Icon(Icons.history),
            title: Text(l10n.historyTitle),
            onTap: () => _push(context, '/history'),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: Text(l10n.shopLabel),
            onTap: () => _push(context, '/shop'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_outlined),
            title: Text(l10n.consultationLabel),
            onTap: () => _push(context, '/consultation'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l10n.paywallScreenTitle),
            onTap: () => _push(context, '/paywall'),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.goToInquiry),
            onTap: () => _push(context, '/inquiry'),
          ),
        ],
      ),
    );
  }
}
