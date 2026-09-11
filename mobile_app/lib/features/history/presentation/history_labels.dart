import 'package:flutter/material.dart';

import '../../../core/models/domain_models.dart';
import '../../../l10n/app_localizations.dart';

/// 履歴の日時を `YYYY/M/D HH:MM` にする（端末のタイムゾーン＝国内ならJST）。
///
/// サーバーはISO文字列（+09:00付き）を返す。そのまま画面へ出すと
/// `2026-09-12T22:21:03.123456+09:00` のように読めないため整形する。
/// 解釈できない値は**そのまま返す**（欠損で画面が壊れない）。
String formatHistoryTimestamp(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) {
    return raw;
  }
  final at = parsed.toLocal();
  final minute = at.minute.toString().padLeft(2, '0');
  final hour = at.hour.toString().padLeft(2, '0');
  return '${at.year}/${at.month}/${at.day} $hour:$minute';
}

/// 履歴の種別（託宣／リーディング）。
///
/// 新しい概念を作らず、引いた形（`spread_id`）から出す。
/// `daily` は本日の託宣、それ以外は枚数を選ぶリーディングである。
String historyKindLabel(BuildContext context, HistoryItemModel item) {
  final l10n = AppLocalizations.of(context)!;
  return item.isDaily ? l10n.historyKindOracle : l10n.historyKindReading;
}

/// 一覧・詳細で共通に使う種別の小さな札。
class HistoryKindChip extends StatelessWidget {
  const HistoryKindChip({super.key, required this.item});

  final HistoryItemModel item;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oracle = item.isDaily;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: oracle ? scheme.primaryContainer : scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        historyKindLabel(context, item),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: oracle
                  ? scheme.onPrimaryContainer
                  : scheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
