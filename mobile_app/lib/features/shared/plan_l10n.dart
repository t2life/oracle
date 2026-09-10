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

/// そのプランで全機能が解放済みか（＝プラン購入画面で買うものが無いか）。
///
/// 月額有料プランと管理者は機能が開いているため購入項目を選ばせない。
/// チケットプランは「機能の解放」ではなく回数の購入なので、ここには含めない。
/// 判定を画面に散らすと「グレーにする条件」と「買える条件」がずれるため、
/// 単一の定義をここに置く。
bool planUnlocksAllFeatures(String plan) =>
    plan == 'subscription' || plan == 'admin';
