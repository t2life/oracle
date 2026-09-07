'use client';

import { FormEvent, useMemo, useState } from 'react';
import { useRouter } from 'next/navigation';

import { NavShell } from '../../components/nav-shell';
import { adminLogin } from '../../lib/api';

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState('admin@example.com');
  const [password, setPassword] = useState('ChangeMe123!');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submitLabel = useMemo(() => (loading ? 'Signing in...' : 'Sign In'), [loading]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const response = await adminLogin(email, password);
      localStorage.setItem('admin_token', response.token);
      localStorage.setItem('admin_user_id', response.admin_user_id);
      router.push('/dashboard');
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : 'Unknown error';
      setError(message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <NavShell
      title="A-01 Admin Login"
      description="Authenticate with admin credentials and issue API session token."
    >
      <form className="form-grid" onSubmit={handleSubmit}>
        <label>
          Email
          <input
            autoComplete="username"
            onChange={(event) => setEmail(event.target.value)}
            type="email"
            value={email}
          />
        </label>
        <label>
          Password
          <input
            autoComplete="current-password"
            onChange={(event) => setPassword(event.target.value)}
            type="password"
            value={password}
          />
        </label>
        <button disabled={loading} type="submit">
          {submitLabel}
        </button>
      </form>
      {error ? <p className="text-muted">{error}</p> : null}
    </NavShell>
  );
}
