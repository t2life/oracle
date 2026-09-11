import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';

/// 引いたカードの一斉公開（U-20）。
///
/// 複数枚のリーディングで、**選んだカードを横一列に並べて見せる**ための画面。
/// 3〜7枚は画面に収まらないため、ゆっくり横へスクロールして全部を見せてから
/// 結果画面へ送る（2026-09-11 ご指摘）。
///
/// ★ここは「見せる」だけで、状態を変えない。結果は既に確定しており、
/// この画面を飛ばしても読みの内容は変わらない（演出と情報を混ぜない）。
///
/// 1枚引き（本日の託宣）ではこの画面を通さない。並べる意味が無く、
/// カード確定時のめくり演出で足りるため。
class CardRevealScreen extends StatefulWidget {
  const CardRevealScreen({super.key});

  /// 1枚あたりの表示幅。7枚でも札の顔が分かる大きさにする。
  static const double cardWidth = 150;

  /// 札と札の間隔。
  static const double gap = 14;

  /// 横へ流す速さ（1秒あたりの論理ピクセル）。
  /// 速いと「見せた」ことにならず、遅いと待たされる。実機で調整した値。
  static const double scrollSpeed = 70;

  /// 並び終えてから流し始めるまでの間。
  static const Duration settleDelay = Duration(milliseconds: 900);

  /// ★自動では遷移しない（2026-09-11 ご指摘）。
  /// 札を見終えるまでの間合いは人によって違うため、進むのは利用者の操作に任せる。
  /// 横スクロールは自動で行い、「結果を見る」で次へ進む。

  @override
  State<CardRevealScreen> createState() => _CardRevealScreenState();
}

class _CardRevealScreenState extends State<CardRevealScreen>
    with TickerProviderStateMixin {
  /// 札が1枚ずつ立ち上がる演出。
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  final ScrollController _scroll = ScrollController();
  bool _started = false;

  @override
  void initState() {
    super.initState();
    SoundService.instance.play(OracleSound.chime);
    _entrance.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    _run();
  }

  @override
  void dispose() {
    _entrance.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// 並べる → ゆっくり流して全部見せる。**遷移はしない。**
  ///
  /// 途中で利用者が離脱しても落ちないよう、各段で `mounted` を確かめる。
  Future<void> _run() async {
    await Future<void>.delayed(CardRevealScreen.settleDelay);
    if (!mounted) {
      return;
    }

    // 見切れている分だけ流す。収まっていれば流さない（無駄に待たせない）。
    if (_scroll.hasClients) {
      final overflow = _scroll.position.maxScrollExtent;
      if (overflow > 0) {
        final seconds = overflow / CardRevealScreen.scrollSpeed;
        await _scroll.animateTo(
          overflow,
          duration: Duration(milliseconds: (seconds * 1000).round()),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  /// 結果へ進む。**唯一の遷移経路**（自動では進まない）。
  void _goToResult() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/reading-result');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.cardRevealTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          final cards = state.latestResult?.cards ?? const [];
          if (cards.isEmpty) {
            // 結果が無い＝この画面に用が無い。黙って止まらず先へ送る。
            WidgetsBinding.instance.addPostFrameCallback((_) => _goToResult());
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                child: Text(
                  l10n.cardRevealPrompt,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, _) {
                    return ListView.separated(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      itemCount: cards.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: CardRevealScreen.gap),
                      itemBuilder: (context, index) {
                        // 左から順に立ち上がる。最後の札まで必ず出る配分にする。
                        final start = cards.length == 1
                            ? 0.0
                            : (index / cards.length) * 0.6;
                        final t = CurvedAnimation(
                          parent: _entrance,
                          curve: Interval(
                            start,
                            (start + 0.4).clamp(0.0, 1.0),
                            curve: Curves.easeOutCubic,
                          ),
                        ).value;
                        final card = cards[index];
                        return Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, (1 - t) * 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                OracleCardFace(
                                  cardId: card.cardId,
                                  cardName: card.cardName,
                                  width: CardRevealScreen.cardWidth,
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: CardRevealScreen.cardWidth,
                                  child: Text(
                                    card.positionName.isEmpty
                                        ? card.cardName
                                        : l10n.positionLabel(
                                            card.positionIndex,
                                            card.positionName,
                                          ),
                                    textAlign: TextAlign.center,
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
                // 自動遷移しないため、これが唯一の出口。目立つ形にする。
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _goToResult,
                    child: Text(l10n.cardRevealNext),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
