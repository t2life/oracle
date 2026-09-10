import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// カード展開（U-08）。仕様書9.8章の本来形＝横一列展開・左右スクロール・
/// タップで1枚確定。確定カードは3Dフリップ演出で表面へ返る。
///
/// 2026-09-10 の複数枚リーディング対応:
/// 必要枚数（スプレッド定義）に達するまで結果は返らないため、
/// 「n枚目 / 全N枚」の進捗を出し、確定済みの位置は選べないようにする
/// （同じカードは選べない＝サーバー側のルールと同じことを画面でも守る）。
class CardSpreadScreen extends StatefulWidget {
  const CardSpreadScreen({super.key});

  @override
  State<CardSpreadScreen> createState() => _CardSpreadScreenState();
}

class _CardSpreadScreenState extends State<CardSpreadScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  bool _revealing = false;

  /// 確定済みのカード位置（1始まり）。同じ位置＝同じカードなので再選択させない。
  final Set<int> _chosen = <int>{};

  @override
  void dispose() {
    _entrance.dispose();
    _flip.dispose();
    super.dispose();
  }

  Future<void> _reveal(int cardIndex) async {
    if (_revealing) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    if (state.loading) {
      return;
    }
    if (_chosen.contains(cardIndex)) {
      return;
    }
    setState(() => _revealing = true);
    state.selectCardIndex(cardIndex);
    SoundService.instance.play(OracleSound.flip);
    HapticFeedback.mediumImpact();

    await state.revealCard();
    if (!mounted) {
      return;
    }
    if (state.errorMessage != null) {
      setState(() => _revealing = false);
      return;
    }
    if (state.latestResult == null) {
      // まだ必要枚数に達していない＝この位置を確定済みにして選択を続ける。
      setState(() {
        _chosen.add(cardIndex);
        _revealing = false;
      });
      return;
    }
    await _flip.forward();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/reading-result');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.cardSpreadTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          final selectedPile = state.selectedPile;
          final pileSize =
              selectedPile == null ? 0 : (state.pileSizes['$selectedPile'] ?? 0);

          if (pileSize == 0) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.completePileFirst),
                    const SizedBox(height: 14),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.back),
                    ),
                  ],
                ),
              ),
            );
          }

          final result = state.latestResult;
          final totalCards = state.plannedDrawCount;

          return Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
                    child: Column(
                      children: [
                        Text(
                          l10n.spreadTapHint,
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        // 複数枚のときだけ進捗を出す（1枚引きの表示は従来のまま）。
                        if (totalCards > 1) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.cardProgressLabel(
                              state.selectedCardCount + 1,
                              totalCards,
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        resolveStateMessage(context, state.errorMessage!),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _entrance,
                      builder: (context, _) {
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 30,
                          ),
                          itemCount: pileSize,
                          itemBuilder: (context, index) {
                            final start = math.min(0.55, index * 0.035);
                            final t = CurvedAnimation(
                              parent: _entrance,
                              curve: Interval(
                                start,
                                math.min(1.0, start + 0.4),
                                curve: Curves.easeOutCubic,
                              ),
                            ).value;
                            return Opacity(
                              opacity: t,
                              child: Transform.translate(
                                offset: Offset(0, (1 - t) * 50),
                                child: Transform.rotate(
                                  angle: math.sin(index * 0.9) * 0.035,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                    ),
                                    child: Center(
                                      child: _chosen.contains(index + 1)
                                          ? const Opacity(
                                              opacity: 0.3,
                                              child: OracleCardBack(width: 96),
                                            )
                                          : GestureDetector(
                                              onTap: () => _reveal(index + 1),
                                              child: const OracleCardBack(
                                                width: 96,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_revealing)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _flip,
                    builder: (context, _) {
                      final angle = _flip.value * math.pi;
                      final showBack = _flip.value < 0.5;
                      return Container(
                        color: Colors.black.withValues(
                          alpha: 0.35 + 0.35 * _flip.value,
                        ),
                        alignment: Alignment.center,
                        child: result == null
                            ? const CircularProgressIndicator()
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..setEntry(3, 2, 0.0014)
                                  ..rotateY(angle),
                                child: showBack
                                    ? const OracleCardBack(
                                        width: 170,
                                        glow: true,
                                      )
                                    : Transform(
                                        alignment: Alignment.center,
                                        transform: Matrix4.identity()
                                          ..rotateY(math.pi),
                                        child: OracleCardFace(
                                          cardName: result.cardNameFor(lang),
                                          reading: lang == 'ja'
                                              ? (result.cards.isNotEmpty
                                                  ? result.cards.first.reading
                                                  : result.reading)
                                              : '',
                                          width: 170,
                                        ),
                                      ),
                              ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
