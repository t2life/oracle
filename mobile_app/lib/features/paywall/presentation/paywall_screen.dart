import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  Future<void> _restore(BuildContext context) async {
    final state = OracleAppStateScope.of(context);
    await state.restoreTicket20();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.paywallScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.currentPlanAndTickets(
                  localizedPlanName(context, state.plan),
                  state.tickets,
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...state.products.map(
                (product) => Card(
                  child: ListTile(
                    title: Text(product.title),
                    subtitle: Text(
                      l10n.productLine(
                        product.planType,
                        product.priceJpy,
                        product.ticketAmount,
                      ),
                    ),
                    trailing: product.isSubscription
                        ? const Icon(Icons.workspace_premium)
                        : const Icon(Icons.confirmation_num_outlined),
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
              FilledButton(
                onPressed: state.loading ? null : () => _restore(context),
                child: Text(l10n.restorePurchase),
              ),
            ],
          );
        },
      ),
    );
  }
}
