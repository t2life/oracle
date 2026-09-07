import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../core/state/state_messages.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/plan_l10n.dart';
import '../../shared/state_message_l10n.dart';

/// ホームタブ（シェル内。Scaffold/AppBarはシェルが提供）。
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OracleStateBuilder(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: state.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (state.offlineMode)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.cloud_off),
                    title: Text(
                      l10n.offlineBanner,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ),
              if (state.errorMessage != null)
                _HomeErrorCard(state: state),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.welcomeUser(state.displayName),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.workspace_premium, size: 16),
                      label: Text(
                        localizedPlanName(context, state.plan),
                        style: const TextStyle(fontSize: 12),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              _TodaysOracleHero(
                onStart: () {
                  SoundService.instance.play(OracleSound.tap);
                  Navigator.of(context).pushNamed('/deck-selection');
                },
              ),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(l10n.announcementsTitle),
                  subtitle: Text(
                    state.announcements.isEmpty
                        ? l10n.noAnnouncements
                        : state.announcements.first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/announcements'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(l10n.historyTitle),
                  subtitle: Text(l10n.historySavedCount(state.history.length)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushNamed('/history'),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                      onPressed: () => Navigator.of(context).pushNamed('/shop'),
                      label: Text(l10n.shopLabel),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.support_agent_outlined, size: 18),
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/consultation'),
                      label: Text(l10n.consultationLabel),
                    ),
                  ),
                ],
              ),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// ホームのエラーカード。無料1日1回上限のみCTAを「プラン購入」にする（⑨）。
class _HomeErrorCard extends StatelessWidget {
  const _HomeErrorCard({required this.state});

  final OracleAppState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = state.errorMessage!;
    final isFreeLimit = message == StateMessages.freeDailyLimit;
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
        title: Text(
          resolveStateMessage(context, message),
          style: const TextStyle(fontSize: 13),
        ),
        trailing: isFreeLimit
            ? FilledButton(
                onPressed: () => Navigator.of(context).pushNamed('/paywall'),
                child: Text(l10n.goToPaywall),
              )
            : TextButton(
                onPressed: state.loading ? null : state.retryLastLoad,
                child: Text(l10n.retry),
              ),
      ),
    );
  }
}

/// 「今日の託宣」ヒーローカード（金枠・カード裏面ビジュアル付き）。
class _TodaysOracleHero extends StatelessWidget {
  const _TodaysOracleHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E2752), Color(0xFF1B1633)],
        ),
        border: Border.all(color: kOracleGold.withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: kOracleGold.withValues(alpha: 0.18),
            blurRadius: 18,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todaysOracle,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: kOracleGoldBright,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.startReadingSubtitle,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFC9C0DC),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: Text(l10n.startReadingTitle),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          const OracleCardBack(width: 74, glow: true),
        ],
      ),
    );
  }
}
