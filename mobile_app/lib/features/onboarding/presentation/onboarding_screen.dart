import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/placeholder_scaffold.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlaceholderScaffold(
      title: l10n.onboardingTitle,
      summary: l10n.onboardingSummary,
      items: [
        l10n.onboardingItem1,
        l10n.onboardingItem2,
        l10n.onboardingItem3,
      ],
      actions: [
        FilledButton(
          onPressed: () {
            // 初回はニックネーム設定を必須で挟む。設定済みなら直接シェルへ。
            final state = OracleAppStateScope.of(context);
            final next =
                state.nicknameConfigured ? '/shell' : '/nickname';
            Navigator.of(context).pushReplacementNamed(next);
          },
          child: Text(l10n.continueLabel),
        ),
      ],
    );
  }
}
