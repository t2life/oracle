'use client';

import { FormEvent, useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { Campaign, createCampaign, dispatchCampaign, fetchCampaigns } from '../../lib/api';

export default function CampaignsPage() {
  const [campaigns, setCampaigns] = useState<Campaign[]>([]);
  const [error, setError] = useState<string | null>(null);

  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [category, setCategory] = useState('キャンペーン通知');
  const [targetSegment, setTargetSegment] = useState('all');

  async function loadCampaigns() {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    try {
      const response = await fetchCampaigns(token);
      setCampaigns(response);
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    }
  }

  useEffect(() => {
    loadCampaigns();
  }, []);

  async function handleCreate(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      setError('Please sign in first.');
      return;
    }

    setError(null);

    try {
      await createCampaign(token, {
        title,
        body,
        category,
        target_segment: targetSegment,
        scheduled_at: new Date(Date.now() + 1000 * 60 * 30).toISOString(),
        is_ab_test: false,
      });
      setTitle('');
      setBody('');
      await loadCampaigns();
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    }
  }

  async function handleDispatch(campaignId: string) {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      setError('Please sign in first.');
      return;
    }

    try {
      await dispatchCampaign(token, campaignId);
      await loadCampaigns();
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    }
  }

  return (
    <NavShell
      title="A-05 Notification Campaign Management"
      description="Create push campaigns, manage schedule state, and dispatch operations."
    >
      <form className="form-grid" onSubmit={handleCreate}>
        <label>
          Title
          <input onChange={(event) => setTitle(event.target.value)} required value={title} />
        </label>
        <label>
          Body
          <textarea
            onChange={(event) => setBody(event.target.value)}
            required
            rows={3}
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
          Target Segment
          <input
            onChange={(event) => setTargetSegment(event.target.value)}
            required
            value={targetSegment}
          />
        </label>
        <button type="submit">Create Campaign</button>
      </form>
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>Status</th>
              <th>Scheduled At</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {campaigns.map((campaign) => (
              <tr key={campaign.campaign_id}>
                <td>{campaign.campaign_id}</td>
                <td>{campaign.title}</td>
                <td>{campaign.status}</td>
                <td>{campaign.scheduled_at}</td>
                <td>
                  <button
                    className="secondary"
                    disabled={campaign.status === 'dispatched'}
                    onClick={() => handleDispatch(campaign.campaign_id)}
                    type="button"
                  >
                    Dispatch
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
