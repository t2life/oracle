'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { ThemeAdmin, fetchThemes } from '../../lib/api';

export default function ThemesPage() {
  const [themes, setThemes] = useState<ThemeAdmin[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    fetchThemes(token)
      .then((response) => setThemes(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, []);

  return (
    <NavShell
      title="A-03 Theme Management"
      description="Review visibility state and operational theme order base."
    >
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Theme ID</th>
              <th>Name</th>
              <th>Visible</th>
            </tr>
          </thead>
          <tbody>
            {themes.map((theme) => (
              <tr key={theme.theme_id}>
                <td>{theme.theme_id}</td>
                <td>{theme.name_ja}</td>
                <td>{theme.is_visible ? 'yes' : 'no'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
