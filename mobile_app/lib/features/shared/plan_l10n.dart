import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

/// サーバーのプランコード（free/subscription/ticket/guest/admin）を
/// 利用者向けの表示名へ変換する（内部コードを画面に露出させない）。
String localizedPlanName(BuildContext context, String plan) {
  final l10n = AppLocalizations.of(context)!;
  switch (plan) {
    case 'free':
      return l10n.planFree;
    case 'subscription':
      return l10n.planSubscription;
    case 'ticket':
      return l10n.planTicket;
    case 'guest':
      return l10n.planGuest;
    case 'admin':
      return l10n.planAdmin;
    default:
      return plan;
  }
}
