import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// リーディングの種別（3枚・5枚・7枚・フリー）を選ぶ画面。
///
/// 表示する枚数・必要チケット・対象プランはすべてスプレッド定義（マスタ）由来で、
/// 画面側には固定値を持たない。フリーのみ枚数を利用者が決めるため、
/// 定義の最小〜最大の範囲でスライダーを出す。
class SpreadSelectionScreen extends StatelessWidget {
  const SpreadSelectionScreen({super.key});

  String _spreadName(AppLocalizations l10n, String lang, SpreadModel spread) {
    if (spread.isVariable) {
      return l10n.spreadFreeLabel;
    }
    // 日本語はマスタの名称をそのまま使う。他言語は枚数から組み立てる
    // （スプレッド名の多言語カラムはマスタに無いため）。
    return lang == 'ja'
        ? spread.nameJa
        : l10n.spreadCardsLabel(spread.cardCount);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.spreadSelectionTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          // 深掘りでは 3／5／7 のみ。フリーは起点と枚数の整合が取りにくいため外す
          // （2026-09-11 承認）。
          final spreads = state.isDeepDive
              ? state.readingSpreads
                  .where((spread) => !spread.isVariable)
                  .toList()
              : state.readingSpreads;
          if (spreads.isEmpty) {
            return Center(
              child: state.loading
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: OutlinedButton(
                        onPressed: () => state.loadSpreads(),
                        child: Text(l10n.retry),
                      ),
                    ),
            );
          }

          final selected = state.selectedSpread;
          final canProceed = selected != null && !selected.isOracle && selected.available;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                state.isDeepDive ? l10n.deepDivePrompt : l10n.spreadPrompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (state.isDeepDive) ...[
                const SizedBox(height: 6),
                Text(
                  l10n.deepDiveCarryOver,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ...spreads.map((spread) {
                final isSelected = state.selectedSpreadId == spread.spreadId;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.22),
                      width: isSelected ? 1.6 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        enabled: spread.available,
                        title: Text(_spreadName(l10n, lang, spread)),
                        subtitle: Text(
                          spread.available
                              ? l10n.ticketsRequiredLabel(spread.requiredTickets)
                              : resolveStateMessage(
                                  context,
                                  spread.unavailableReason ?? '',
                                ),
                        ),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : const Icon(Icons.radio_button_unchecked),
                        onTap: spread.available
                            ? () {
                                SoundService.instance.play(OracleSound.tap);
                                state.selectSpread(spread.spreadId);
                              }
                            : null,
                      ),
                      // フリーのみ枚数を選ぶ（範囲はマスタの min/max）。
                      if (isSelected && spread.isVariable)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${l10n.freeDrawCountLabel}: '
                                '${l10n.spreadCardsLabel(state.plannedDrawCount)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              Slider(
                                value: state.plannedDrawCount.toDouble(),
                                min: spread.minCards.toDouble(),
                                max: spread.maxCards.toDouble(),
                                divisions: spread.maxCards - spread.minCards,
                                label: '${state.plannedDrawCount}',
                                onChanged: (value) =>
                                    state.setFreeDrawCount(value.round()),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: canProceed
                    ? () {
                        SoundService.instance.play(OracleSound.tap);
                        Navigator.of(context).pushNamed('/theme-selection');
                      }
                    : null,
                child: Text(l10n.proceedToThemeSelection),
              ),
            ],
          );
        },
      ),
    );
  }
}
