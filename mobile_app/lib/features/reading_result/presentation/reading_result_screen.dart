import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// リーディング結果（U-09）。カード表面→キーワード→解釈文の順に
/// 段階的に浮かび上がる演出＋チャイム音。
class ReadingResultScreen extends StatefulWidget {
  const ReadingResultScreen({super.key});

  @override
  State<ReadingResultScreen> createState() => _ReadingResultScreenState();
}

class _ReadingResultScreenState extends State<ReadingResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _stage = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 7),
  )..repeat();

  @override
  void initState() {
    super.initState();
    SoundService.instance.play(OracleSound.chime);
  }

  @override
  void dispose() {
    _stage.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  double _phase(double begin, double end) {
    return CurvedAnimation(
      parent: _stage,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    ).value;
  }

  Future<void> _saveHistory(BuildContext context) async {
    final state = OracleAppStateScope.of(context);
    SoundService.instance.play(OracleSound.tap);
    await state.saveCurrentHistory();
    if (!context.mounted || state.errorMessage != null) {
      return;
    }
    Navigator.of(context).pushNamed('/history');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.readingResultTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          final result = state.latestResult;

          if (result == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noResult),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.loading ? null : state.reloadResult,
                      child: Text(l10n.refetchResult),
                    ),
                  ],
                ),
              ),
            );
          }

          String themeName = result.themeId;
          for (final theme in state.themes) {
            if (theme.themeId == result.themeId) {
              themeName = theme.nameFor(lang);
              break;
            }
          }
          String deckName = result.deckId;
          for (final deck in state.decks) {
            if (deck.deckId == result.deckId) {
              deckName = deck.nameFor(lang);
              break;
            }
          }
          final caution = result.cautionFor(lang);

          return Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _twinkle,
                  builder: (context, _) => Opacity(
                    opacity:
                        Theme.of(context).brightness == Brightness.dark ? 0.5 : 0.2,
                    child: CustomPaint(
                      painter: StarfieldPainter(
                        twinkle: _twinkle.value,
                        starCount: 46,
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _stage,
                builder: (context, _) {
                  final cardIn = _phase(0.0, 0.38);
                  final metaIn = _phase(0.30, 0.50);
                  final keywordsIn = _phase(0.44, 0.64);
                  final textIn = _phase(0.58, 0.84);
                  final tailIn = _phase(0.74, 1.0);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
                    children: [
                      Center(
                        child: Opacity(
                          opacity: cardIn,
                          child: Transform.scale(
                            scale: 0.85 + 0.15 * cardIn,
                            child: OracleCardFace(
                              cardName: result.cardNameFor(lang),
                              width: 196,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: metaIn,
                        child: Text(
                          l10n.themeAndDeck(themeName, deckName),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: keywordsIn,
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: result
                              .keywordsFor(lang)
                              .map((keyword) => Chip(label: Text(keyword)))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: textIn,
                        child: Text(
                          result.interpretationFor(lang),
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      // 組み合わせ解釈は日本語のみ提供。ja以外は段落自体を描画しない
                      // （2026-09-06指摘事項3）。1枚引きでは値なし＝非表示。
                      if (lang == 'ja' &&
                          (result.combinationText?.isNotEmpty ?? false)) ...[
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: textIn,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              result.combinationText!,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ],
                      if (caution != null) ...[
                        const SizedBox(height: 14),
                        Opacity(
                          opacity: tailIn,
                          child: Text(
                            caution,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                      if (state.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          resolveStateMessage(context, state.errorMessage!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (state.infoMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          resolveStateMessage(context, state.infoMessage!),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Opacity(
                        opacity: tailIn,
                        child: Column(
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.bookmark_add_outlined),
                              onPressed: state.loading
                                  ? null
                                  : () => _saveHistory(context),
                              label: Text(l10n.saveToHistory),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed('/paywall'),
                              child: Text(l10n.deepReading),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                SoundService.instance.play(OracleSound.tap);
                                Navigator.of(context)
                                    .popUntil((route) => route.isFirst);
                              },
                              child: Text(l10n.backToHome),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
