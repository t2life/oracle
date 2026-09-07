import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/domain_models.dart';
import '../../core/state/app_state.dart';
import '../../l10n/app_localizations.dart';

Future<void> openExternalLink({
  required BuildContext context,
  required OracleAppState state,
  required ExternalLinkModel link,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final uri = Uri.tryParse(link.url);
  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.invalidLinkFormat)),
    );
    return;
  }

  final cannotOpenMessage = l10n.cannotOpenLink;
  await state.trackExternalLinkClick(category: link.category, linkId: link.linkId);
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(cannotOpenMessage)),
    );
  }
}
