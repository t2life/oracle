import 'package:flutter/material.dart';

class PlaceholderScaffold extends StatelessWidget {
  const PlaceholderScaffold({
    super.key,
    required this.title,
    required this.summary,
    required this.items,
    this.actions = const <Widget>[],
  });

  final String title;
  final String summary;
  final List<String> items;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(summary),
            const SizedBox(height: 16),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $item'),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: actions),
          ],
        ),
      ),
    );
  }
}
