import 'package:flutter/material.dart';

import '../../../core/state/app_state.dart';
import '../../../core/state/app_state_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../shared/state_message_l10n.dart';

/// カード一覧タブ（シェル内。Scaffold/AppBarはシェルが提供）。
class CardLibraryTab extends StatefulWidget {
  const CardLibraryTab({super.key});

  @override
  State<CardLibraryTab> createState() => _CardLibraryTabState();
}

class _CardLibraryTabState extends State<CardLibraryTab> {
  late final TextEditingController _searchController;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    final state = OracleAppStateScope.of(context);
    _searchController.text = state.cardSearchQuery;
    state.loadCardLibrary();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(OracleAppState state) {
    final query = _searchController.text.trim();
    state.setCardSearchQuery(query);
    state.fetchCards(query: query, deckId: state.cardDeckFilter);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;
    return OracleStateBuilder(
        builder: (context, state) {
          final cards = state.cards;
          final decks = state.decks;

          return RefreshIndicator(
            onRefresh: () => state.fetchCards(
              query: state.cardSearchQuery,
              deckId: state.cardDeckFilter,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: l10n.searchCardsLabel,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: state.loading ? null : () => _search(state),
                    ),
                  ),
                  onSubmitted: (_) => _search(state),
                  enabled: !state.loading,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.allDecks),
                      selected: state.cardDeckFilter == null,
                      onSelected: state.loading
                          ? null
                          : (_) {
                              state.setCardDeckFilter(null);
                              state.fetchCards(
                                query: state.cardSearchQuery,
                                deckId: null,
                              );
                            },
                    ),
                    ...decks.map(
                      (deck) => ChoiceChip(
                        label: Text(deck.nameFor(lang)),
                        selected: state.cardDeckFilter == deck.deckId,
                        onSelected: state.loading
                            ? null
                            : (_) {
                                state.setCardDeckFilter(deck.deckId);
                                state.fetchCards(
                                  query: state.cardSearchQuery,
                                  deckId: deck.deckId,
                                );
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      resolveStateMessage(context, state.errorMessage!),
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                if (cards.isEmpty && state.loading)
                  const Center(child: CircularProgressIndicator()),
                if (cards.isEmpty && !state.loading) Text(l10n.noCards),
                if (cards.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.2,
                    ),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.nameFor(lang),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                card.deckId,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const Spacer(),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: card
                                    .keywordsFor(lang)
                                    .take(3)
                                    .map((keyword) => Chip(
                                          label: Text(keyword),
                                          visualDensity: VisualDensity.compact,
                                        ))
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
    );
  }
}
