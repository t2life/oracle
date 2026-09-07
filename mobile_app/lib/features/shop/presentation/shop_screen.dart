import 'package:flutter/material.dart';

import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/external_link_helper.dart';
import '../../shared/speaker_toggle.dart';
import '../../shared/state_message_l10n.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    OracleAppStateScope.of(context).loadShopLinks();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: buildOracleAppBar(context, l10n.shopScreenTitle),
      body: OracleStateBuilder(
        builder: (context, state) {
          return RefreshIndicator(
            onRefresh: () => state.loadShopLinks(force: true),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  l10n.shopDescription,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 12),
                if (state.shopLinks.isEmpty && state.loading)
                  const Center(child: CircularProgressIndicator()),
                if (state.shopLinks.isEmpty && !state.loading)
                  Text(l10n.noShopLinks),
                ...state.shopLinks.map(
                  (link) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
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
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      resolveStateMessage(context, state.errorMessage!),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
