import 'package:flutter/material.dart';

import '../../core/audio/sound_service.dart';
import '../../l10n/app_localizations.dart';
import '../shell/presentation/main_shell.dart';

/// 占いフロー（デッキ選択→テーマ→シャッフル→山選択→カード→結果）から抜けるための導線。
///
/// フローは一方通行（前の手順へは戻さない）という承認済みの設計のため、
/// 途中離脱の唯一の出口として各画面のAppBarへ置く。押すとホームタブへ戻る
/// （下部ナビのホームを押したのと同じ扱い＝フローは破棄される）。
/// iOSにはハードウェアの戻るが無いため、この導線が特に重要になる。
class FlowExitAction extends StatelessWidget {
  const FlowExitAction({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return TextButton(
      onPressed: () {
        SoundService.instance.play(OracleSound.tap);
        ShellScope.of(context)?.selectTab(0);
      },
      child: Text(l10n.cancelReadingFlow),
    );
  }
}
