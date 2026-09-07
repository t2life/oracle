import 'package:flutter/material.dart';

import '../../shared/placeholder_scaffold.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 未ルーティングの骨格画面（通知詳細設定は将来実装）。
    return const PlaceholderScaffold(
      title: 'Notification Settings',
      summary: 'Fine-grained push preference management.',
      items: [
        'Daily reminder toggle',
        'Campaign and announcement toggle',
        'Permission and token sync state',
      ],
    );
  }
}
