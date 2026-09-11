import 'package:flutter/material.dart';

import '../../../core/config/app_links.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/app_actions.dart';
import '../../shared/speaker_toggle.dart';

/// 規約・情報（U-15）。利用規約・プライバシーポリシー・特定商取引法に基づく表記と、
/// アプリの提供元を1画面にまとめる。
///
/// 公開先URLが未設定の項目は「準備中」として押せない状態で並べる
/// （押せるのに開かない項目を出さない）。URLは [AppLinks] を直すだけで有効になる。
class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entries = <({String title, String url})>[
      (title: l10n.termsOfService, url: AppLinks.termsUrl),
      (title: l10n.privacyPolicy, url: AppLinks.privacyUrl),
      (
        title: l10n.commercialTransactions,
        url: AppLinks.commercialTransactionsUrl,
      ),
    ];

    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.legalInfoTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...entries.map(
            (entry) {
              final ready = entry.url.isNotEmpty;
              return Card(
                child: ListTile(
                  enabled: ready,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(entry.title),
                  subtitle: ready ? null : Text(l10n.comingSoon),
                  trailing: ready ? const Icon(Icons.open_in_new) : null,
                  onTap: ready ? () => openAppUrl(context, entry.url) : null,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  // 提供元は固定値（AppLinks）だが、見出しは表示言語に従う
                  title: Text(l10n.appProviderLabel),
                  subtitle: const Text(AppLinks.developerName),
                ),
                ListTile(
                  // アプリ内フォームが使えないとき（オフライン等）の控えとして出す。
                  leading: const Icon(Icons.alternate_email),
                  title: Text(l10n.supportContactLabel),
                  subtitle: const SelectableText(AppLinks.supportEmail),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
