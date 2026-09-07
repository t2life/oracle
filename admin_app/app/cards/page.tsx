'use client';

import { ChangeEvent, useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { Card, DeckAdmin, fetchCards, fetchDecks } from '../../lib/api';

export default function CardsPage() {
  const [decks, setDecks] = useState<DeckAdmin[]>([]);
  const [cards, setCards] = useState<Card[]>([]);
  const [selectedDeck, setSelectedDeck] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    fetchDecks(token)
      .then((response) => setDecks(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, []);

  useEffect(() => {
    fetchCards(selectedDeck || undefined)
      .then((response) => setCards(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, [selectedDeck]);

  function handleDeckChange(event: ChangeEvent<HTMLSelectElement>) {
    setSelectedDeck(event.target.value);
  }

  return (
    <NavShell
      title="A-03 Card Management"
      description="Card list and keyword surface for operations and QA checks."
    >
      <label>
        Filter Deck
        <select onChange={handleDeckChange} value={selectedDeck}>
          <option value="">All decks</option>
          {decks.map((deck) => (
            <option key={deck.deck_id} value={deck.deck_id}>
              {deck.name_ja}
            </option>
          ))}
        </select>
      </label>
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Card ID</th>
              <th>Deck</th>
              <th>Name</th>
              <th>Keywords</th>
            </tr>
          </thead>
          <tbody>
            {cards.map((card) => (
              <tr key={card.card_id}>
                <td>{card.card_id}</td>
                <td>{card.deck_id}</td>
                <td>{card.name_ja}</td>
                <td>{card.keywords.join(', ')}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
