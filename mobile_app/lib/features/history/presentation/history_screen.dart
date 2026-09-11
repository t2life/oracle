import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';
import 'history_labels.dart';

/// 履歴の一覧（U-12）。
///
/// ★2026-09-12 変更（承認済）: 以前は `subtitle` に**全文**を出していた。
/// 3枚引きは1件で800字を超えるため、件数が増えると読めなくなる。
/// ∴ 一覧は **種別（託宣／リーディング）＋日時の1行**だけにし、
/// 全文・削除は詳細画面（`/history-detail`）へ寄せた。
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

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
                      title: Row(
                        children: [
                          HistoryKindChip(item: item),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              formatHistoryTimestamp(item.createdAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pushNamed(
                        '/history-detail',
                        arguments: item,
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
