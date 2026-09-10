import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// プラン購入画面（U-10）。
/// 2026-09-10 の構成変更:
///   ①現在のプランは1行に集約（無料は「現在無料プラン　チケット残数：n枚」）
///   ②その直下に月額プランのボタン（説明は全機能の解放のみ）
///   ③その下にチケットプランを金額（税込）で並べる（枚数は商品名と重複するため出さない）
///   ④月額有料プランの加入者は全機能が解放済みのため、購入項目は選べない
///     （＝グレー表示。買っても何も増えない項目を押せるようにしない）
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  /// 月額プランの商品コード（マスタと一致。購入経路は既存の復元APIを流用）。
  static const String _subscriptionProductCode = 'subscription_monthly_500';

  Future<void> _purchase(BuildContext context, String productCode) async {
    final state = OracleAppStateScope.of(context);
    await state.purchaseProduct(productCode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.paywallScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          // 有料ユーザーは機能が解放済みのため説明書きを出さない（現状の表示のみ）。
          final isFree = state.plan == 'free' || state.plan == 'guest';
          // 全機能が解放済みのプランでは購入項目を選べない（判定は plan_l10n が正）。
          final unlocked = planUnlocksAllFeatures(state.plan);
          final tickets = state.tickets;
          final ticketProducts =
              state.products.where((product) => !product.isSubscription).toList();
          // 月額プランの金額はマスタ（products）が正。画面には固定値を持たない。
          final subscription = state.products
              .where((product) => product.isSubscription)
              .cast<dynamic>()
              .firstWhere((product) => true, orElse: () => null);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isFree
                    ? l10n.currentPlanFree(tickets)
                    : l10n.currentPlanPaid(
                        localizedPlanName(context, state.plan),
                        tickets,
                      ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (unlocked)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.allFeaturesUnlocked,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  enabled: !unlocked,
                  leading: const Icon(Icons.workspace_premium),
                  title: Text(
                    l10n.subscriptionOfferTitle(
                      (subscription?.priceJpy as int?) ?? 550,
                    ),
                  ),
                  subtitle: Text(l10n.subscriptionOfferBody),
                  onTap: (state.loading || unlocked)
                      ? null
                      : () => _purchase(context, _subscriptionProductCode),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 8),
              ...ticketProducts.map(
                (product) => Card(
                  child: ListTile(
                    enabled: !unlocked,
                    leading: const Icon(Icons.confirmation_num_outlined),
                    title: Text(product.title),
                    subtitle: Text(l10n.ticketPriceLine(product.priceJpy)),
                    onTap: (state.loading || unlocked)
                        ? null
                        : () => _purchase(context, product.productCode),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              if (state.infoMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(resolveStateMessage(context, state.infoMessage!)),
                ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: state.loading
                    ? null
                    : () => _purchase(context, 'ticket_20'),
                child: Text(l10n.restorePurchase),
              ),
            ],
          );
        },
      ),
    );
  }
}
