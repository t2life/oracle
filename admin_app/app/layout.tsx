import type { Metadata } from 'next';
import type { ReactNode } from 'react';

import './globals.css';

export const metadata: Metadata = {
  title: 'Oracle Admin Console',
  description: 'Operations dashboard for oracle reading service',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="ja">
      <body>
        <div className="page-backdrop" />
        <div className="page-shell">{children}</div>
      </body>
    </html>
  );
}
