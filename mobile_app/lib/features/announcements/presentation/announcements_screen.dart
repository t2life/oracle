import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/speaker_toggle.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.announcementsScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.announcements.isEmpty)
                Text(l10n.noAnnouncementsAvailable),
              ...state.announcements.map(
                (announcement) => Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        if (announcement.isImportant)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Icon(Icons.priority_high, size: 16),
                          ),
                        Expanded(child: Text(announcement.title)),
                      ],
                    ),
                    subtitle: Text(
                      '${announcement.category}\n${announcement.body}',
                    ),
                    isThreeLine: true,
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
