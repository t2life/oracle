import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';
import 'history_labels.dart';

/// 履歴の詳細（U-22・2026-09-12 承認）。
///
/// 一覧に全文を出すと件数が増えたときに読めなくなるため、
/// **全文はこの画面だけ**が持つ。削除もここへ寄せた
/// （一覧のゴミ箱は押し間違えると取り返しがつかないため）。
class HistoryDetailScreen extends StatelessWidget {
  const HistoryDetailScreen({super.key, this.item});

  /// 一覧から渡される履歴。経路引数で受け取れなかった場合は [build] で拾う。
  final HistoryItemModel? item;

  Future<void> _confirmDelete(
    BuildContext context,
    OracleAppState state,
    HistoryItemModel target,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final navigator = Navigator.of(context);
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
    if (confirmed != true) {
      return;
    }
    await state.deleteHistoryItem(target.historyId);
    // 消した履歴の詳細に留まらない。一覧へ戻す。
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final argument = ModalRoute.of(context)?.settings.arguments;
    final target =
        item ?? (argument is HistoryItemModel ? argument : null);

    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.historyDetailTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          if (target == null) {
            // 経路引数が失われた場合（プロセス再生成など）。黙って空にしない。
            return Center(child: Text(l10n.noHistory));
          }
          // 一覧で消された履歴を開いたままにしない。
          final live = state.history
              .where((entry) => entry.historyId == target.historyId)
              .toList();
          final current = live.isEmpty ? target : live.first;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  HistoryKindChip(item: current),
                  const SizedBox(width: 10),
                  Text(
                    formatHistoryTimestamp(current.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SelectableText(
                current.fullText,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: state.loading
                    ? null
                    : () => _confirmDelete(context, state, current),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.historyDelete),
              ),
            ],
          );
        },
      ),
    );
  }
}
