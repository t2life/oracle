'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { InquirySummary, fetchInquiries } from '../../lib/api';

export default function InquiriesPage() {
  const [inquiries, setInquiries] = useState<InquirySummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    fetchInquiries(token)
      .then((response) => setInquiries(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, []);

  return (
    <NavShell
      title="A-07 Inquiry Management"
      description="Support queue with category and body review."
    >
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Inquiry ID</th>
              <th>User</th>
              <th>Category</th>
              <th>Body</th>
              <th>Created At</th>
            </tr>
          </thead>
          <tbody>
            {inquiries.map((item) => (
              <tr key={item.inquiry_id}>
                <td>{item.inquiry_id}</td>
                <td>{item.user_id}</td>
                <td>{item.category}</td>
                <td>{item.body}</td>
                <td>{item.created_at}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
