import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';

/// 静的説明ページ（⑦「託宣とは」「カードメッセージについて」）。
/// 文言はドラフト（オーナー監修前提）。3言語はl10nで供給。
class StaticInfoScreen extends StatelessWidget {
  const StaticInfoScreen({
    super.key,
    required this.title,
    required this.paragraphs,
  });

  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildOracleAppBar(context, title),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Center(
            child: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 36),
          ),
          const SizedBox(height: 20),
          for (final paragraph in paragraphs) ...[
            Text(
              paragraph,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.8),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

/// 「託宣とは」ページ。
class AboutOracleScreen extends StatelessWidget {
  const AboutOracleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StaticInfoScreen(
      title: l10n.aboutOracleTitle,
      paragraphs: [
        l10n.aboutOracleBody1,
        l10n.aboutOracleBody2,
        l10n.aboutOracleBody3,
      ],
    );
  }
}

/// 「カードメッセージについて」ページ。
class AboutCardsScreen extends StatelessWidget {
  const AboutCardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return StaticInfoScreen(
      title: l10n.aboutCardsTitle,
      paragraphs: [
        l10n.aboutCardsBody1,
        l10n.aboutCardsBody2,
        l10n.aboutCardsBody3,
      ],
    );
  }
}
