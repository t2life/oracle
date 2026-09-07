import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  static const List<IconData> _themeIcons = [
    Icons.self_improvement,
    Icons.wb_twilight,
    Icons.favorite_outline,
    Icons.savings_outlined,
    Icons.work_outline,
    Icons.spa_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.themeSelectionTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          if (state.themes.isEmpty && state.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l10n.themePrompt,
                style: Theme.of(context).textTheme.titleMedium,
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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.themes.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.65,
                ),
                itemBuilder: (context, index) {
                  final theme = state.themes[index];
                  final selected = state.selectedThemeId == theme.themeId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: state.loading
                        ? null
                        : () {
                            SoundService.instance.play(OracleSound.tap);
                            state.selectTheme(theme.themeId);
                          },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: selected
                            ? kOracleGold.withValues(alpha: 0.16)
                            : Theme.of(context).colorScheme.surface,
                        border: Border.all(
                          color: selected
                              ? kOracleGold
                              : kOracleGold.withValues(alpha: 0.22),
                          width: selected ? 1.6 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _themeIcons[index % _themeIcons.length],
                            color: selected
                                ? kOracleGoldBright
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            theme.nameFor(lang),
                            style: TextStyle(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.selectedThemeId == null
                    ? null
                    : () {
                        SoundService.instance.play(OracleSound.tap);
                        Navigator.of(context).pushNamed('/shuffle');
                      },
                child: Text(l10n.proceedToShuffle),
              ),
            ],
          );
        },
      ),
    );
  }
}
