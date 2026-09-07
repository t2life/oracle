'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { KpiResponse, fetchKpi } from '../../lib/api';

export default function AnalyticsPage() {
  const [snapshot, setSnapshot] = useState<KpiResponse | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    fetchKpi(token)
      .then((response) => setSnapshot(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, []);

  return (
    <NavShell
      title="A-08 Analytics"
      description="Raw KPI event counters for funnel and retention tracking."
    >
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="kpi-grid">
        {snapshot
          ? Object.entries(snapshot.values).map(([name, value]) => (
              <div className="kpi-item" key={name}>
                <strong>{name}</strong>
                <div>{value}</div>
              </div>
            ))
          : null}
      </div>
    </NavShell>
  );
}
