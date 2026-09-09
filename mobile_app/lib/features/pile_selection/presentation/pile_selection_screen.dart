import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/audio/sound_service.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/flow_exit_action.dart';
import '../../shared/oracle_card_visuals.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// 山選択（U-07）。3つの山がアニメーションで降りてきて、タップで選択する。
class PileSelectionScreen extends StatefulWidget {
  const PileSelectionScreen({super.key});

  @override
  State<PileSelectionScreen> createState() => _PileSelectionScreenState();
}

class _PileSelectionScreenState extends State<PileSelectionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );

  int? _selecting;

  @override
  void initState() {
    super.initState();
    _entrance.forward();
    SoundService.instance.play(OracleSound.whoosh);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  Future<void> _selectPile(int pileIndex) async {
    if (_selecting != null) {
      return;
    }
    final state = OracleAppStateScope.of(context);
    if (state.loading) {
      return;
    }
    setState(() => _selecting = pileIndex);
    SoundService.instance.play(OracleSound.whoosh);
    HapticFeedback.lightImpact();

    await state.choosePile(pileIndex);
    if (!mounted) {
      return;
    }
    if (state.errorMessage != null) {
      setState(() => _selecting = null);
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/card-spread');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.pileSelectionTitle,
          extraActions: const [FlowExitAction()]),
      body: OracleStateBuilder(
        builder: (context, state) {
          final entries = state.pileSizes.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key));

          if (entries.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.noPileInfo, textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pushReplacementNamed('/shuffle'),
                      child: Text(l10n.backToShuffle),
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 6),
                child: Text(
                  l10n.pileTapHint,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    resolveStateMessage(context, state.errorMessage!),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: AnimatedBuilder(
                  animation: _entrance,
                  builder: (context, _) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          _buildPile(context, l10n, entries[i], i),
                      ],
                    );
                  },
                ),
              ),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: CircularProgressIndicator(),
                ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPile(
    BuildContext context,
    AppLocalizations l10n,
    MapEntry<String, int> entry,
    int order,
  ) {
    final pileIndex = int.tryParse(entry.key) ?? (order + 1);
    final t = CurvedAnimation(
      parent: _entrance,
      curve: Interval(
        0.12 * order,
        0.55 + 0.12 * order,
        curve: Curves.easeOutBack,
      ),
    ).value;
    final selected = _selecting == pileIndex;
    final cardWidth =
        ((MediaQuery.sizeOf(context).width - 90) / 3).clamp(72.0, 108.0);

    return Opacity(
      opacity: t.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(0, (1 - t) * -70),
        child: GestureDetector(
          onTap: () => _selectPile(pileIndex),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 220),
                child: SizedBox(
                  width: cardWidth + 10,
                  height: cardWidth * 1.55 + 12,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 8,
                        top: 10,
                        child: OracleCardBack(width: cardWidth),
                      ),
                      Positioned(
                        left: 4,
                        top: 5,
                        child: OracleCardBack(width: cardWidth),
                      ),
                      OracleCardBack(width: cardWidth, glow: selected),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.pileLabel(pileIndex),
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.pileCountLabel(entry.value),
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
