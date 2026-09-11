import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/oracle_card_visuals.dart';

/// 起動時オープニング（約10秒・スキップ可）。
/// 星空→カードの扇展開→タイトル→タグライン→フェードアウトの演出を
/// プログラマティックアニメーションで行い、環境音（opening.wav）を再生する。
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _master = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );
  late final AnimationController _twinkle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _master.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _finish();
      }
    });
    _master.forward();
    SoundService.instance.ensureLoaded().then((_) {
      if (mounted && !_finished) {
        SoundService.instance.playAmbience(OracleSound.opening);
      }
    });
  }

  @override
  void dispose() {
    _master.dispose();
    _twinkle.dispose();
    super.dispose();
  }

  void _finish() {
    if (_finished || !mounted) {
      return;
    }
    _finished = true;
    SoundService.instance.stopAmbience();
    // オンボーディング（「ようこそ」）は2026-09-09に配線から外した。
    // 初回のみニックネーム設定を挟み、設定済みなら直接シェルへ入る。
    final state = OracleAppStateScope.of(context);
    Navigator.of(context).pushReplacementNamed(
      state.nicknameConfigured ? '/shell' : '/nickname',
    );
  }

  double _phase(double begin, double end, {Curve curve = Curves.easeOutCubic}) {
    return CurvedAnimation(
      parent: _master,
      curve: Interval(begin, end, curve: curve),
    ).value;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: kOracleMidnight,
      body: AnimatedBuilder(
        animation: Listenable.merge([_master, _twinkle]),
        builder: (context, _) {
          final fan = _phase(0.06, 0.40);
          final titleIn = _phase(0.24, 0.44);
          final taglineIn = _phase(0.44, 0.60);
          final fadeOut = 1.0 - _phase(0.90, 1.0, curve: Curves.easeIn);
          final pulse = 0.5 + 0.5 * math.sin(_twinkle.value * 2 * math.pi);

          // 中央の札をめくる → 画面いっぱいへ → 元の大きさへ戻る
          // （2026-09-11 ご指摘）。扇が開き切ってから始める。
          final flip = _phase(0.46, 0.58, curve: Curves.easeInOut);
          final grow = _phase(0.58, 0.68, curve: Curves.easeOutCubic);
          final shrink = _phase(0.76, 0.86, curve: Curves.easeInCubic);
          // 拡大中は扇の中央札を隠し、全画面のほうに見せ場を渡す。
          final zooming = flip > 0 && shrink < 1;
          final cardWidth = size.width * 0.24;
          // 画面を覆う倍率。縦横のうち大きいほうに合わせる。
          final fullScale = math.max(
            size.width / cardWidth,
            size.height / (cardWidth * kOracleCardAspect),
          );
          final zoomScale = 1 + (fullScale - 1) * (grow - shrink).clamp(0.0, 1.0);

          return Opacity(
            opacity: fadeOut,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xFF0E0B1A),
                          kOracleMidnight,
                          Color(0xFF241C42),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: StarfieldPainter(twinkle: _twinkle.value),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: size.width * 0.62,
                        width: size.width,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: size.width * (0.46 + 0.02 * pulse),
                              height: size.width * (0.46 + 0.02 * pulse),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: kOracleGold.withValues(
                                    alpha: 0.25 + 0.25 * pulse,
                                  ),
                                  width: 1.4,
                                ),
                              ),
                            ),
                            for (final spec in const [
                              (-0.38, -60.0, false),
                              (0.38, 60.0, false),
                              (0.0, 0.0, true),
                            ])
                              Transform.translate(
                                offset: Offset(
                                  spec.$2 * fan,
                                  (1 - fan) * 46 - (spec.$3 ? 10 * fan : 0),
                                ),
                                child: Transform.rotate(
                                  angle: spec.$1 * fan,
                                  child: Transform.scale(
                                    scale: 0.9 + 0.14 * fan,
                                    child: Opacity(
                                      // 中央札は拡大演出へ見せ場を渡す
                                      opacity: (spec.$3 && zooming) ? 0 : 1,
                                      child: OracleCardBack(
                                        width: cardWidth,
                                        glow: spec.$3 && fan > 0.95,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 26),
                      Opacity(
                        opacity: titleIn,
                        child: Transform.translate(
                          offset: Offset(0, (1 - titleIn) * 14),
                          child: Text(
                            l10n.appTitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'serif',
                              fontSize: 27,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.5,
                              color: kOracleGoldBright,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Opacity(
                        opacity: taglineIn,
                        child: Text(
                          l10n.splashTagline,
                          style: const TextStyle(
                            fontSize: 14,
                            letterSpacing: 1.6,
                            color: Color(0xFFBFB4D6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // めくって画面いっぱいに開き、また小さく戻る一連の演出。
                // 扇や文字の上に重ねる（位置合わせに悩まず、確実に主役になる）。
                if (zooming)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Transform.scale(
                          scale: zoomScale,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(flip * math.pi),
                            child: flip < 0.5
                                ? OracleCardBack(width: cardWidth)
                                : Transform(
                                    // 半分を過ぎたら表。鏡像にならないよう戻す。
                                    alignment: Alignment.center,
                                    transform: Matrix4.identity()
                                      ..rotateY(math.pi),
                                    child: OracleCardFace(
                                      cardName: l10n.appTitle,
                                      width: cardWidth,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 16,
                  bottom: 24,
                  child: SafeArea(
                    // システムナビゲーションバーとの重なりでタップが吸われるのを防ぐ
                    child: Opacity(
                      opacity: _phase(0.06, 0.14, curve: Curves.easeOut),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _finish,
                        child: Text(
                          l10n.skipLabel,
                          style: const TextStyle(
                            color: Color(0xFF9A92A8),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
