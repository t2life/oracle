import Link from 'next/link';

import { NavShell } from '../components/nav-shell';

export default function HomePage() {
  return (
    <NavShell
      title="Admin Console Entry"
      description="This scaffold maps operational requirements A-01 to A-08."
    >
      <p>Use login first, then navigate to each operation module.</p>
      <p>
        <Link href="/login">Open login page</Link>
      </p>
    </NavShell>
  );
}
