import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'A-Factor STEM Studio — Embedded simulation',
  robots: { index: false }, // embeds shouldn't compete with the real pages in search
};

// Deliberately minimal: no AppHeader, no site navigation. This layout wraps
// only the /embed/* routes, which are designed to live inside an <iframe>
// on someone else's page.
export default function EmbedLayout({ children }: { children: React.ReactNode }) {
  return <div className="min-h-screen bg-white">{children}</div>;
}
