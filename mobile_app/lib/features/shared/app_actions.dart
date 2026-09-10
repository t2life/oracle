import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_links.dart';
import '../../l10n/app_localizations.dart';

/// マイページ・≡メニューから使う「アプリそのもの」に対する操作。
///
/// 画面ごとに `launchUrl` を書くと開けなかったときの扱いがばらつくため、
/// URLは [AppLinks]、開き方はここに集約する。
Future<void> openAppUrl(BuildContext context, String url) async {
  final l10n = AppLocalizations.of(context)!;
  final uri = Uri.tryParse(url);
  if (url.isEmpty || uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.invalidLinkFormat)),
    );
    return;
  }
  final cannotOpen = l10n.cannotOpenLink;
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cannotOpen)),
    );
  }
}

/// ストアの掲載ページを開く（「アプリを評価」）。
Future<void> openStoreListing(BuildContext context) =>
    openAppUrl(context, AppLinks.storeListingUrl);

/// 提供元の他アプリを開く（「App2Craftのアプリ」）。
Future<void> openDeveloperApps(BuildContext context) =>
    openAppUrl(context, AppLinks.developerAppsUrl);

/// アプリを共有する（OS標準の共有シート）。
Future<void> shareApp(BuildContext context) async {
  await Share.share(AppLinks.shareBody, subject: AppLinks.shareSubject);
}
