'use client';

import { useEffect, useState } from 'react';

import { NavShell } from '../../components/nav-shell';
import { UserSummary, fetchUsers } from '../../lib/api';

export default function UsersPage() {
  const [users, setUsers] = useState<UserSummary[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const token = localStorage.getItem('admin_token') ?? '';
    if (!token) {
      return;
    }

    fetchUsers(token)
      .then((response) => setUsers(response))
      .catch((caught) => {
        const message = caught instanceof Error ? caught.message : 'Unknown error';
        setError(message);
      });
  }, []);

  return (
    <NavShell
      title="A-06 User Management"
      description="Review plan mix, ticket status, and registration volume."
    >
      {error ? <p className="text-muted">{error}</p> : null}
      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>User ID</th>
              <th>Plan</th>
              <th>Tickets</th>
              <th>Created At</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user) => (
              <tr key={user.user_id}>
                <td>{user.user_id}</td>
                <td>{user.plan}</td>
                <td>{user.tickets}</td>
                <td>{user.created_at}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </NavShell>
  );
}
