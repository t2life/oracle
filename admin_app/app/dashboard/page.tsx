'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { DashboardResponse, fetchDashboard } from '../../lib/api';

export default function DashboardPage() {
  const [token, setToken] = useState('');
  const [data, setData] = useState<DashboardResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setToken(localStorage.getItem('admin_token') ?? '');
  }, []);

  useEffect(() => {
    if (!token) {
      return;
    }

    fetchDashboard(token)
      .then((response) => setData(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, [token]);

  return (
    <NavShell
      title="A-02 Dashboard"
      description="KPI snapshot for operational monitoring and campaign outcomes."
    >
      {!token ? <p className="text-muted">Please sign in from A-01 first.</p> : null}
      {error ? <p className="text-muted">{error}</p> : null}
      {data ? (
        <div className="kpi-grid">
          <div className="kpi-item">
            <strong>Users</strong>
            <div>{data.users_total}</div>
          </div>
          <div className="kpi-item">
            <strong>Inquiries</strong>
            <div>{data.inquiries_total}</div>
          </div>
          <div className="kpi-item">
            <strong>Announcements</strong>
            <div>{data.announcements_total}</div>
          </div>
          <div className="kpi-item">
            <strong>Campaigns</strong>
            <div>{data.campaigns_total}</div>
          </div>
          <div className="kpi-item">
            <strong>Reading Completed</strong>
            <div>{data.reading_completed}</div>
          </div>
          <div className="kpi-item">
            <strong>Ticket Purchased</strong>
            <div>{data.ticket_purchased}</div>
          </div>
          <div className="kpi-item">
            <strong>Subscription Started</strong>
            <div>{data.subscription_started}</div>
          </div>
          <div className="kpi-item">
            <strong>Updated</strong>
            <div>{data.updated_at}</div>
          </div>
        </div>
      ) : null}
    </NavShell>
  );
}
