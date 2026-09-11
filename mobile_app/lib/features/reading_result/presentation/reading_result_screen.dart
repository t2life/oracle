import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/models/domain_models.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// リーディング結果（U-09）。カード表面→キーワード→解釈文の順に
/// 段階的に浮かび上がる演出＋チャイム音。
///
/// 2026-09-10 の複数枚リーディング対応:
/// 結果が複数枚のときは「どの位置のカードか」が読みの意味を決めるため、
/// 相談内容と各ポジション（1.現状／2.課題…）を解釈文の前に並べる。
/// ポジション名・ポジション別のカード名はマスタが日本語のみを持つため
/// 日本語表記のまま出す（多言語カラムはマスタ側の追補課題）。
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

  /// 託宣の結果から深掘りへ進む。
  ///
  /// 引いたカードは1枚目として引き継がれる（引き直しにしない）。
  /// テーマは託宣のものを使い、枚数の選択から始める。
  void _startDeepDive(BuildContext context) {
    SoundService.instance.play(OracleSound.tap);
    OracleAppStateScope.of(context).startDeepDive();
    Navigator.of(context).pushNamed('/spread-selection');
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
                      // 複数枚は横スライドで全部見られるようにする（ご指摘③）。
                      // 1枚引きは従来どおり中央に1枚。
                      Opacity(
                        opacity: cardIn,
                        child: Transform.scale(
                          scale: 0.85 + 0.15 * cardIn,
                          child: _TopCards(
                            result: result,
                            lang: lang,
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
                      // カード情報＝属性分類とエレメント（2026-09-10 ご指摘③）
                      if (result.primaryAttribute.isNotEmpty ||
                          result.primaryElement.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: metaIn,
                          child: Text(
                            _attributeLine(
                              l10n,
                              result.primaryAttribute,
                              result.primaryElement,
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
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
                      // 相談内容（リーディングのみ。託宣は空）。
                      if (result.questionText.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: keywordsIn,
                          child: _SectionBox(
                            title: l10n.questionLabel,
                            child: Text(
                              result.questionText,
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ],
                      // ポジション別の並び（複数枚のときだけ意味を持つ）。
                      if (result.cards.length > 1) ...[
                        const SizedBox(height: 16),
                        Opacity(
                          opacity: keywordsIn,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final card in result.cards)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _PositionCard(card: card),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      Opacity(
                        opacity: textIn,
                        // 結果文は読み物のため左寄せ（他の要素は中央寄せのまま）
                        child: Text(
                          result.interpretationFor(lang),
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.left,
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
                              textAlign: TextAlign.left,
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
                        // ボタンは3つとも画面全幅で統一（2026-09-10 ご指摘③）
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FilledButton.icon(
                              icon: const Icon(Icons.bookmark_add_outlined),
                              onPressed: state.loading
                                  ? null
                                  : () => _saveHistory(context),
                              label: Text(l10n.saveToHistory),
                            ),
                            const SizedBox(height: 8),
                            // 深掘りリーディング（2026-09-11）。
                            // 託宣の結果からのみ入れる。既に複数枚のリーディングを
                            // さらに深掘りすると「引き直し」に近づくため出さない。
                            if (result.cards.length <= 1) ...[
                              OutlinedButton(
                                onPressed: state.loading
                                    ? null
                                    : () => _startDeepDive(context),
                                child: Text(l10n.deepReading),
                              ),
                              const SizedBox(height: 8),
                            ],
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

/// 「属性：別天神/創造神　エレメント：エーテル」の1行を作る。
/// 片方しか無いマスタ行でも成立するように、空の側は落とす。
String _attributeLine(AppLocalizations l10n, String attribute, String element) {
  final parts = <String>[
    if (attribute.isNotEmpty) '${l10n.cardAttributeLabel}：$attribute',
    if (element.isNotEmpty) '${l10n.cardElementLabel}：$element',
  ];
  return parts.join('　');
}

/// 見出し付きの囲み（相談内容などの補足ブロック）。
class _SectionBox extends StatelessWidget {
  const _SectionBox({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

/// ポジション1件（「1. 現状」＋カード名＋キーワード＋そのポジションの役割）。
class _PositionCard extends StatelessWidget {
  const _PositionCard({required this.card});

  final ResultCardModel card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 縮小したカード図柄。文字だけで読ませない（2026-09-11 ご指摘）。
          // 小さすぎて絵柄が読めないため、タップで画面いっぱいに開く（ご指摘④）。
          GestureDetector(
            onTap: () => showOracleCardZoom(
              context,
              cardId: card.cardId,
              cardName: card.cardName,
              reading: card.reading,
            ),
            child: OracleCardFace(
              cardId: card.cardId,
              cardName: card.cardName,
              width: 56,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: _positionBody(context, l10n, scheme)),
        ],
      ),
    );
  }

  Widget _positionBody(
    BuildContext context,
    AppLocalizations l10n,
    ColorScheme scheme,
  ) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.positionLabel(card.positionIndex, card.positionName),
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            card.nameWithReading,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.left,
          ),
          if (card.attribute.isNotEmpty || card.element.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              _attributeLine(l10n, card.attribute, card.element),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              textAlign: TextAlign.left,
            ),
          ],
          if (card.positionMeaning.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              card.positionMeaning,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.left,
            ),
          ],
          if (card.keywords.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: card.keywords
                  .map(
                    (keyword) => Chip(
                      label: Text(keyword),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
    );
  }
}

/// 結果の上部に置く札。複数枚は横スライドで全部見られる（ご指摘③）。
///
/// ★横スクロールできることが見た目で分かるよう、両隣の札を少し覗かせる。
/// 1枚引きでは並べる意味が無いため、中央に1枚だけ置く。
class _TopCards extends StatelessWidget {
  const _TopCards({required this.result, required this.lang});

  final ReadingResultModel result;
  final String lang;

  static const double _width = 196;

  @override
  Widget build(BuildContext context) {
    final cards = result.cards;
    // ルビは日本語表示のときだけ（読み仮名は日本語話者向け）
    String rubyOf(int index) {
      if (lang != 'ja') {
        return '';
      }
      return index < cards.length ? cards[index].reading : result.reading;
    }

    if (cards.length <= 1) {
      return Center(
        child: GestureDetector(
          onTap: () => showOracleCardZoom(
            context,
            cardId: result.cardId,
            cardName: result.cardNameFor(lang),
            reading: rubyOf(0),
          ),
          child: OracleCardFace(
            cardId: result.cardId,
            cardName: result.cardNameFor(lang),
            reading: rubyOf(0),
            width: _width,
          ),
        ),
      );
    }

    return SizedBox(
      height: _width * kOracleCardAspect,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.66),
        itemCount: cards.length,
        itemBuilder: (context, index) {
          final card = cards[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: GestureDetector(
              onTap: () => showOracleCardZoom(
                context,
                cardId: card.cardId,
                cardName: card.cardName,
                reading: rubyOf(index),
              ),
              child: OracleCardFace(
                cardId: card.cardId,
                cardName: card.cardName,
                reading: rubyOf(index),
                width: _width,
              ),
            ),
          );
        },
      ),
    );
  }
}
