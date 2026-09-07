import 'package:flutter/material.dart';

import '../../core/audio/sound_service.dart';
import '../../l10n/app_localizations.dart';

/// 全画面のAppBarに常時表示する効果音ON/OFFトグル（スピーカーアイコン）。
class SpeakerToggle extends StatelessWidget {
  const SpeakerToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<bool>(
      valueListenable: SoundService.instance.enabled,
      builder: (context, soundOn, _) {
        return IconButton(
          tooltip: soundOn ? l10n.soundOffTooltip : l10n.soundOnTooltip,
          icon: Icon(soundOn ? Icons.volume_up : Icons.volume_off),
          onPressed: () => SoundService.instance.toggle(),
        );
      },
    );
  }
}

/// フロー画面用の共通AppBar（タイトル＋スピーカー常時表示）。
AppBar buildOracleAppBar(
  BuildContext context,
  String title, {
  List<Widget> extraActions = const [],
}) {
  return AppBar(
    title: Text(title),
    actions: [
      ...extraActions,
      const SpeakerToggle(),
      const SizedBox(width: 4),
    ],
  );
}
