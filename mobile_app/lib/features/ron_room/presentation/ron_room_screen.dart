import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/external_link_helper.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

/// ロンの部屋（単独画面。≡メニューから開く＝戻るボタン付き）。
class RonRoomScreen extends StatelessWidget {
  const RonRoomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.ronRoomScreenTitle),
      body: const RonRoomTab(),
    );
  }
}

/// ロンの部屋タブ本体（Scaffold/AppBarは呼び出し側が提供）。
class RonRoomTab extends StatefulWidget {
  const RonRoomTab({super.key});

  @override
  State<RonRoomTab> createState() => _RonRoomTabState();
}

class _RonRoomTabState extends State<RonRoomTab> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    OracleAppStateScope.of(context).loadRonRoomData();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OracleStateBuilder(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => state.loadRonRoomData(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primaryContainer,
                        Theme.of(context).colorScheme.secondaryContainer,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.ronRoomHeadline,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.ronRoomDescription),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.streamSchedule,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (state.liveEvents.isEmpty)
                  Text(l10n.noStreams)
                else
                  ...state.liveEvents.map(
                    (event) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: Text(event.title),
                        subtitle: Text(event.startAt),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  l10n.archivesAndLinks,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (state.liveLinks.isEmpty)
                  Text(l10n.noStreamLinks)
                else
                  ...state.liveLinks.map(
                    (link) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.live_tv_outlined),
                        title: Text(link.title),
                        subtitle: Text(link.url),
                        trailing: const Icon(Icons.open_in_new),
                        onTap: () => openExternalLink(
                          context: context,
                          state: state,
                          link: link,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.auto_awesome),
                    title: Text(l10n.limitedBannerTitle),
                    subtitle: Text(l10n.limitedBannerBody),
                  ),
                ),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      resolveStateMessage(context, state.errorMessage!),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (state.loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          );
        },
    );
  }
}
