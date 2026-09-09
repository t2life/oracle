import 'dart:async';
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

enum _ShufflePhase { preparing, shuffling, gathering, failed }

/// シャッフル画面（U-06）。
/// 仕様書9.6章の本来形＝「ユーザーの指スワイプに連動してカード束が動く演出」を実装。
/// 抽選はセッション開始時にサーバー側で確定済みで、演出は結果に影響しない（⚡機能1）。
/// 判定3条件（スワイプ量・指離し・待機1.2秒）を実ジェスチャーから計測してAPIへ渡す。
class ShuffleScreen extends StatefulWidget {
  const ShuffleScreen({super.key});

  @override
  State<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleCardSpec {
  _ShuffleCardSpec(math.Random rng)
      : baseAngle = rng.nextDouble() * 2 * math.pi,
        radiusF = 0.55 + rng.nextDouble() * 0.55,
        spin = (rng.nextBool() ? 1 : -1) * (0.4 + rng.nextDouble() * 0.8),
        rotSpin = (rng.nextBool() ? 1 : -1) * (0.2 + rng.nextDouble() * 0.5),
        wobble = 0.5 + rng.nextDouble() * 1.5,
        phase = rng.nextDouble() * 2 * math.pi,
        baseRot = (rng.nextDouble() - 0.5) * 0.9;

  final double baseAngle;
  final double radiusF;
  final double spin;
  final double rotSpin;
  final double wobble;
  final double phase;
  final double baseRot;
}

class _ShuffleScreenState extends State<ShuffleScreen>
    with TickerProviderStateMixin {
  static const double _readyThreshold = 420.0;
  static const int _cardCount = 12;

  late final AnimationController _swirl = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();
  late final AnimationController _gather = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  late final List<_ShuffleCardSpec> _cards = () {
    final rng = math.Random();
    return List.generate(_cardCount, (_) => _ShuffleCardSpec(rng));
  }();

  _ShufflePhase _phase = _ShufflePhase.preparing;
  double _agitation = 0;
  double _swipeDistance = 0;
  bool _panning = false;
  Timer? _idleTimer;
  DateTime _lastFeedback = DateTime.fromMillisecondsSinceEpoch(0);
  List<(Offset, double)>? _frozenPoses;
  Size _lastArenaSize = Size.zero;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _swirl.addListener(_decayAgitation);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSession());
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _swirl.dispose();
    _gather.dispose();
    super.dispose();
  }

  void _decayAgitation() {
    if (!_panning && _agitation > 0) {
      _agitation = math.max(0, _agitation - 0.012);
    }
  }

  Future<void> _startSession() async {
    if (!mounted) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    await state.startReadingFlow();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = state.errorMessage != null
          ? _ShufflePhase.failed
          : _ShufflePhase.shuffling;
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase != _ShufflePhase.shuffling) {
      return;
    }
    _idleTimer?.cancel();
    _panning = true;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != _ShufflePhase.shuffling) {
      return;
    }
    _swipeDistance += details.delta.distance;
    _agitation = math.min(1.0, _agitation + details.delta.distance / 260);
    final now = DateTime.now();
    if (now.difference(_lastFeedback).inMilliseconds > 170) {
      _lastFeedback = now;
      SoundService.instance.play(OracleSound.shuffle);
      HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  void _onPanEnd(DragEndDetails details) {
    _panning = false;
    if (_phase != _ShufflePhase.shuffling) {
      return;
    }
    if (_swipeDistance >= _readyThreshold) {
      // 仕様: 最終スワイプから1.0〜2.0秒操作がない＋指が離れている＝終了判定
      _idleTimer?.cancel();
      _idleTimer = Timer(const Duration(milliseconds: 1200), _completeShuffle);
    }
  }

  (Offset, double) _cardPose(int index, Size arena) {
    final spec = _cards[index];
    final center = Offset(arena.width / 2, arena.height / 2);
    final t = _swirl.value * 2 * math.pi;
    final angle = spec.baseAngle + t * spec.spin * (0.25 + 1.75 * _agitation);
    final radius = arena.width *
        0.27 *
        spec.radiusF *
        (0.82 + 0.18 * math.sin(t * spec.wobble + spec.phase));
    final offset = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final rotation = spec.baseRot +
        t * spec.rotSpin * (0.3 + 1.7 * _agitation) +
        0.15 * math.sin(t * spec.wobble + spec.phase);
    return (offset, rotation);
  }

  Future<void> _completeShuffle() async {
    if (!mounted || _phase != _ShufflePhase.shuffling) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    final arenaSize = _lastArenaSize == Size.zero
        ? MediaQuery.sizeOf(context)
        : _lastArenaSize;
    _frozenPoses = [
      for (var i = 0; i < _cardCount; i++) _cardPose(i, arenaSize),
    ];
    setState(() => _phase = _ShufflePhase.gathering);
    SoundService.instance.play(OracleSound.whoosh);
    HapticFeedback.mediumImpact();

    await state.completeShuffle(
      idleSeconds: 1.2,
      swipeDistance: _swipeDistance.clamp(120.0, 100000.0),
    );
    if (!mounted) {
      return;
    }
    if (state.errorMessage != null) {
      setState(() => _phase = _ShufflePhase.failed);
      return;
    }
    await _gather.forward();
    if (!mounted || _navigated) {
      return;
    }
    _navigated = true;
    Navigator.of(context).pushReplacementNamed('/pile-selection');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.shuffleTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          if (_phase == _ShufflePhase.preparing) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 14),
                  Text(l10n.preparingCards),
                ],
              ),
            );
          }

          if (_phase == _ShufflePhase.failed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.nightlight_outlined,
                      size: 42,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      state.errorMessage == null
                          ? l10n.msgSessionNotStarted
                          : resolveStateMessage(context, state.errorMessage!),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n.back),
                    ),
                  ],
                ),
              ),
            );
          }

          String themeName = state.selectedThemeId ?? '-';
          for (final theme in state.themes) {
            if (theme.themeId == state.selectedThemeId) {
              themeName = theme.nameFor(lang);
              break;
            }
          }
          String deckName = state.selectedDeckId ?? '-';
          for (final deck in state.decks) {
            if (deck.deckId == state.selectedDeckId) {
              deckName = deck.nameFor(lang);
              break;
            }
          }

          final ready = _swipeDistance >= _readyThreshold;
          final gathering = _phase == _ShufflePhase.gathering;

          return Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final arena = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    _lastArenaSize = arena;
                    final cardWidth = arena.width * 0.19;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      onPanEnd: _onPanEnd,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_swirl, _gather]),
                        builder: (context, _) {
                          final center = Offset(
                            arena.width / 2,
                            arena.height / 2,
                          );
                          final gatherT =
                              Curves.easeInOut.transform(_gather.value);
                          final cardWidgets = <Widget>[];
                          for (var i = 0; i < _cardCount; i++) {
                            var (pos, rot) = _cardPose(i, arena);
                            if (gathering && _frozenPoses != null) {
                              final frozen = _frozenPoses![i];
                              pos = Offset.lerp(frozen.$1, center, gatherT)!;
                              rot = frozen.$2 * (1 - gatherT);
                            }
                            cardWidgets.add(
                              Positioned(
                                left: pos.dx - cardWidth / 2,
                                top: pos.dy - cardWidth * 1.55 / 2,
                                child: Transform.rotate(
                                  angle: rot,
                                  child: OracleCardBack(
                                    width: cardWidth,
                                    glow: ready && !gathering,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Stack(
                            clipBehavior: Clip.none,
                            children: cardWidgets,
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    Text(
                      l10n.deckAndTheme(deckName, themeName),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_swipeDistance / _readyThreshold).clamp(0.0, 1.0),
                        minHeight: 6,
                        color: Theme.of(context).colorScheme.primary,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      gathering
                          ? l10n.shuffleReady
                          : (ready ? l10n.shuffleGuideRelease : l10n.shuffleGuide),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
