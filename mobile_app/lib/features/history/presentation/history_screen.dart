import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<void> _confirmDelete(
    BuildContext context,
    OracleAppState state,
    HistoryItemModel item,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.historyDeleteTitle),
        content: Text(l10n.historyDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.historyDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.deleteHistoryItem(item.historyId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.historyScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: state.fetchHistory,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.planAndSavedCount(
                    localizedPlanName(context, state.plan),
                    state.history.length,
                  ),
                ),
                const SizedBox(height: 12),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      resolveStateMessage(context, state.errorMessage!),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (state.history.isEmpty && state.loading)
                  const Center(child: CircularProgressIndicator()),
                if (state.history.isEmpty && !state.loading)
                  Text(l10n.noHistory),
                ...state.history.map(
                  (item) => Card(
                    child: ListTile(
                      title: Text(item.summary),
                      subtitle: Text('${item.createdAt}\n${item.fullText}'),
                      isThreeLine: true,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: l10n.historyDelete,
                        onPressed: state.loading
                            ? null
                            : () => _confirmDelete(context, state, item),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: FilledButton(
          onPressed: () => Navigator.of(context).pushNamed('/paywall'),
          child: Text(l10n.upgradePlan),
        ),
      ),
    );
  }
}
