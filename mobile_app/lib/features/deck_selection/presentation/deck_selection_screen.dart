import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// デッキ選択の本体（シェルの「リーディング」タブと、ホームからの
/// ルート遷移（/deck-selection）の両方で使う単一実装）。
class DeckSelectionBody extends StatelessWidget {
  const DeckSelectionBody({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return OracleStateBuilder(
      builder: (context, state) {
        if (state.decks.isEmpty && state.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              l10n.deckPrompt,
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
            ...state.decks.map(
              (deck) {
                final selected = state.selectedDeckId == deck.deckId;
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
                      width: selected ? 1.6 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    leading: OracleCardBack(width: 40, glow: selected),
                    title: Text(deck.nameFor(lang)),
                    trailing: selected
                        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                        : const Icon(Icons.radio_button_unchecked),
                    onTap: state.loading
                        ? null
                        : () {
                            SoundService.instance.play(OracleSound.tap);
                            state.selectDeck(deck.deckId);
                          },
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: state.selectedDeckId == null
                  ? null
                  : () {
                      SoundService.instance.play(OracleSound.tap);
                      Navigator.of(context).pushNamed('/theme-selection');
                    },
              child: Text(l10n.proceedToThemeSelection),
            ),
          ],
        );
      },
    );
  }
}

/// シェル内Navigatorのフォールバック用ラッパー（通常は「占う」タブ本体が
/// DeckSelectionBodyを直接描画する）。
class DeckSelectionScreen extends StatelessWidget {
  const DeckSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.deckSelectionTitle,
          extraActions: const [FlowExitAction()]),
      body: const SafeArea(top: false, child: DeckSelectionBody()),
    );
  }
}
