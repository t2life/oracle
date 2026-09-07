import Link from 'next/link';
import type { ReactNode } from 'react';

type Props = {
  title: string;
  description: string;
  children: ReactNode;
};

const navItems = [
  { href: '/dashboard', label: 'A-02 Dashboard' },
  { href: '/themes', label: 'A-03 Themes' },
  { href: '/decks', label: 'A-03 Decks' },
  { href: '/cards', label: 'A-03 Cards' },
  { href: '/announcements', label: 'A-04 Announcements' },
  { href: '/campaigns', label: 'A-05 Campaigns' },
  { href: '/users', label: 'A-06 Users' },
  { href: '/inquiries', label: 'A-07 Inquiries' },
  { href: '/analytics', label: 'A-08 Analytics' },
  { href: '/login', label: 'A-01 Login' },
];

export function NavShell({ title, description, children }: Props) {
  return (
    <div className="nav-shell">
      <aside className="card nav-panel">
        <h1 className="heading">Oracle Admin</h1>
        <p className="text-muted">Operations and content governance panel</p>
        <nav className="nav-list">
          {navItems.map((item) => (
            <Link className="nav-link" key={item.href} href={item.href}>
              {item.label}
            </Link>
          ))}
        </nav>
      </aside>
      <main className="card content-panel">
        <h2 className="heading">{title}</h2>
        <p className="text-muted">{description}</p>
        {children}
      </main>
    </div>
  );
}
