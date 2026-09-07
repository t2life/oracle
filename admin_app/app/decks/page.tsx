'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { DeckAdmin, fetchDecks } from '../../lib/api';

export default function DecksPage() {
  const [decks, setDecks] = useState<DeckAdmin[]>([]);
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

  return (
    <NavShell
      title="A-03 Deck Management"
      description="Inspect deck publishing status and display ordering."
    >
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Deck ID</th>
              <th>Name</th>
              <th>Order</th>
              <th>Published</th>
            </tr>
          </thead>
          <tbody>
            {decks.map((deck) => (
              <tr key={deck.deck_id}>
                <td>{deck.deck_id}</td>
                <td>{deck.name_ja}</td>
                <td>{deck.sort_order}</td>
                <td>{deck.is_published ? 'yes' : 'no'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
