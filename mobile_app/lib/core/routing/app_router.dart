import 'package:flutter/material.dart';

import '../../features/announcements/presentation/announcements_screen.dart';
import '../../features/card_spread/presentation/card_spread_screen.dart';
import '../../features/consultation/presentation/consultation_screen.dart';
import '../../features/deck_selection/presentation/deck_selection_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/info/presentation/static_info_screen.dart';
import '../../features/inquiry/presentation/inquiry_screen.dart';
import '../../features/nickname/presentation/nickname_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/paywall/presentation/paywall_screen.dart';
import '../../features/pile_selection/presentation/pile_selection_screen.dart';
import '../../features/reading_result/presentation/reading_result_screen.dart';
import '../../features/ron_room/presentation/ron_room_screen.dart';
import '../../features/shell/presentation/main_shell.dart';
import '../../features/shop/presentation/shop_screen.dart';
import '../../features/shuffle/presentation/shuffle_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/theme_selection/presentation/theme_selection_screen.dart';

enum AppRoute {
  splash('/splash'),
  onboarding('/onboarding'),
  nickname('/nickname'),
  shell('/shell'),
  home('/home'),
  deckSelection('/deck-selection'),
  themeSelection('/theme-selection'),
  shuffle('/shuffle'),
  pileSelection('/pile-selection'),
  cardSpread('/card-spread'),
  readingResult('/reading-result'),
  history('/history'),
  announcements('/announcements'),
  consultation('/consultation'),
  shop('/shop'),
  paywall('/paywall'),
  inquiry('/inquiry');

  const AppRoute(this.path);

  final String path;
}

Route<dynamic> buildRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/splash':
      return MaterialPageRoute<void>(builder: (_) => const SplashScreen());
    // 「ようこそ」画面は2026-09-09に起動導線から外した（スプラッシュ→ニックネーム/シェル）。
    // 画面と経路は再配線できるよう残すが、現在ここへ遷移する箇所は無い。
    case '/onboarding':
      return MaterialPageRoute<void>(builder: (_) => const OnboardingScreen());
    case '/nickname':
      return MaterialPageRoute<void>(builder: (_) => const NicknameScreen());
    case '/shell':
      return MaterialPageRoute<void>(builder: (_) => const MainShell());
    default:
      // フロー/二次画面はシェル内ネストNavigatorが解決する（buildShellChild）。
      // ルートNavigatorへ直接来た場合もシェルへ寄せる。
      return MaterialPageRoute<void>(builder: (_) => const MainShell());
  }
}

/// シェル内ネストNavigator用の画面ビルダー（フロー/二次画面）。
/// タブルート（/home等）はmain_shellの_shellTabBuilderが先に解決する。
Widget buildShellChild(BuildContext context) {
  final name = ModalRoute.of(context)?.settings.name;
  switch (name) {
    case '/theme-selection':
      return const ThemeSelectionScreen();
    case '/shuffle':
      return const ShuffleScreen();
    case '/pile-selection':
      return const PileSelectionScreen();
    case '/card-spread':
      return const CardSpreadScreen();
    case '/reading-result':
      return const ReadingResultScreen();
    case '/history':
      return const HistoryScreen();
    case '/announcements':
      return const AnnouncementsScreen();
    case '/consultation':
      return const ConsultationScreen();
    case '/shop':
      return const ShopScreen();
    case '/paywall':
      return const PaywallScreen();
    case '/inquiry':
      return const InquiryScreen();
    case '/about-oracle':
      return const AboutOracleScreen();
    case '/about-cards':
      return const AboutCardsScreen();
    case '/ron-room':
      return const RonRoomScreen();
    default:
      return const DeckSelectionScreen();
  }
}
