'use client';

import { FormEvent, useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import {
  Announcement,
  createAnnouncement,
  fetchAnnouncements,
} from '../../lib/api';

export default function AnnouncementsPage() {
  const [items, setItems] = useState<Announcement[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [category, setCategory] = useState('重要なお知らせ');
  const [linkUrl, setLinkUrl] = useState('');

  async function loadAnnouncements() {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    try {
      const response = await fetchAnnouncements(token);
      setItems(response);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    }
  }

  useEffect(() => {
    loadAnnouncements();
  }, []);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      setError('Please sign in first.');
      return;
    }

    setSaving(true);
    setError(null);

    const now = new Date();
    const end = new Date(now.getTime() + 1000 * 60 * 60 * 24 * 7);

    try {
      await createAnnouncement(token, {
        title,
        body,
        category,
        start_at: now.toISOString(),
        end_at: end.toISOString(),
        is_important: true,
        link_url: linkUrl || null,
      });
      setTitle('');
      setBody('');
      setLinkUrl('');
      await loadAnnouncements();
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <NavShell
      title="A-04 Announcement Management"
      description="Create and monitor user-facing notices and important updates."
    >
      <form className="form-grid" onSubmit={handleSubmit}>
        <label>
          Title
          <input onChange={(event) => setTitle(event.target.value)} required value={title} />
        </label>
        <label>
          Body
          <textarea
            onChange={(event) => setBody(event.target.value)}
            required
            rows={4}
            value={body}
          />
        </label>
        <label>
          Category
          <input
            onChange={(event) => setCategory(event.target.value)}
            required
            value={category}
          />
        </label>
        <label>
          Link URL
          <input onChange={(event) => setLinkUrl(event.target.value)} value={linkUrl} />
        </label>
        <button disabled={saving} type="submit">
          {saving ? 'Saving...' : 'Create Announcement'}
        </button>
      </form>
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>Category</th>
              <th>Period</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr key={item.announcement_id}>
                <td>{item.announcement_id}</td>
                <td>{item.title}</td>
                <td>{item.category}</td>
                <td>
                  {item.start_at} - {item.end_at}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
