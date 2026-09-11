import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// 占う種別の分岐（本日の託宣／リーディング）。
///
/// 「占う」導線の最初の画面。ここでプランとチケット残数を先に見せ、
/// 使えない導線はその理由（有料プラン限定／チケット不足）とプラン購入への
/// 導線を出す。可否の判定はスプレッド定義（マスタ）＋サーバー（またはオフライン
/// エンジン）の `available` / `unavailable_reason` が単一の真実源で、
/// この画面は自前でプランを判定しない。
class ReadingKindScreen extends StatefulWidget {
  const ReadingKindScreen({super.key});

  @override
  State<ReadingKindScreen> createState() => _ReadingKindScreenState();
}

class _ReadingKindScreenState extends State<ReadingKindScreen> {
  bool _requested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) {
      return;
    }
    _requested = true;
    final state = OracleAppStateScope.of(context);
    // 前回の深掘りの起点を捨てる。残したままだと、新しい占いが
    // 前の託宣を引き継いでしまう。
    state.clearDeepDive();
    // 残数は購入・消費で変わるため、この画面を開くたびに取り直す。
    state.loadSpreads();
  }

  void _startOracle(BuildContext context, SpreadModel spread) {
    SoundService.instance.play(OracleSound.tap);
    OracleAppStateScope.of(context).selectSpread(spread.spreadId);
    Navigator.of(context).pushNamed('/deck-selection');
  }

  void _startReading(BuildContext context, List<SpreadModel> spreads) {
    SoundService.instance.play(OracleSound.tap);
    final state = OracleAppStateScope.of(context);
    // 種別（枚数）はデッキ選択の次で選ぶ。ここでは既定として最初の1件を仮置きする。
    state.selectSpread(spreads.first.spreadId);
    Navigator.of(context).pushNamed('/deck-selection');
  }

  void _openPlans(BuildContext context) {
    SoundService.instance.play(OracleSound.tap);
    Navigator.of(context).pushNamed('/paywall');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.readingKindTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          if (state.spreads.isEmpty && state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final oracle = state.oracleSpread;
          final readings = state.readingSpreads;
          // リーディングは一律5チケット。1件でも使えれば導線を開ける。
          final readingAvailable = readings.any((spread) => spread.available);
          final readingReason = readings
              .map((spread) => spread.unavailableReason)
              .firstWhere((reason) => reason != null, orElse: () => null);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.readingKindPrompt,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                // 残数は「見えてから選ぶ」ための情報。表記はプラン購入画面と揃える。
                (state.plan == 'free' || state.plan == 'guest')
                    ? l10n.currentPlanFree(state.tickets)
                    : l10n.currentPlanPaid(
                        localizedPlanName(context, state.plan),
                        state.tickets,
                      ),
                style: Theme.of(context).textTheme.bodySmall,
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
              if (oracle != null)
                _KindCard(
                  icon: Icons.auto_awesome,
                  title: l10n.oracleKindTitle,
                  body: l10n.oracleKindBody,
                  note: l10n.oracleDailyLimitNote,
                  available: oracle.available,
                  unavailableReason: oracle.unavailableReason,
                  onTap: () => _startOracle(context, oracle),
                  onOpenPlans: () => _openPlans(context),
                ),
              if (readings.isNotEmpty) ...[
                const SizedBox(height: 12),
                _KindCard(
                  icon: Icons.auto_stories_outlined,
                  title: l10n.readingKindLabel,
                  body: l10n.readingKindBody,
                  note: l10n.ticketsRequiredLabel(readings.first.requiredTickets),
                  available: readingAvailable,
                  unavailableReason: readingReason,
                  onTap: () => _startReading(context, readings),
                  onOpenPlans: () => _openPlans(context),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 種別1件ぶんのカード。使えないときは理由とプラン購入への導線に置き換える。
class _KindCard extends StatelessWidget {
  const _KindCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.note,
    required this.available,
    required this.unavailableReason,
    required this.onTap,
    required this.onOpenPlans,
  });

  final IconData icon;
  final String title;
  final String body;
  final String note;
  final bool available;
  final String? unavailableReason;
  final VoidCallback onTap;
  final VoidCallback onOpenPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: available
              ? scheme.primary.withValues(alpha: 0.5)
              : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: available ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: available ? scheme.primary : scheme.outline),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (available) const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              Text(body, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 6),
              Text(
                note,
                style: TextStyle(
                  fontSize: 12.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (!available) ...[
                const SizedBox(height: 10),
                Text(
                  resolveStateMessage(context, unavailableReason ?? ''),
                  style: TextStyle(color: scheme.error),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: onOpenPlans,
                    child: Text(l10n.openPlans),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
