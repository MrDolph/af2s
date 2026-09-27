'use client';
import { useState, useEffect, useRef } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

export function MinitabBar() {
  const pathname = usePathname();
  const router = useRouter();
  const [loggingOut, setLoggingOut] = useState(false);
  const tracked = useRef<string | null>(null);

  // Fire a visit beacon once per page load — skipped on the login page and
  // anything under /minitab/admin, since neither is a "simulation visit",
  // and the admin area has its own separate access gate anyway.
  useEffect(() => {
    if (pathname === '/minitab/login' || pathname.startsWith('/minitab/admin')) return;
    if (tracked.current === pathname) return;
    tracked.current = pathname;
    const slug = pathname.replace(/^\/minitab\/?/, '') || 'hub';
    fetch('/api/minitab-track', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ slug }),
    }).catch(() => {}); // best-effort — a failed beacon shouldn't disrupt the page
  }, [pathname]);

  // The login page has nothing to log out of yet — hide the bar there.
  if (pathname === '/minitab/login') return null;

  const isHub = pathname === '/minitab';

  const logout = async () => {
    setLoggingOut(true);
    try {
      await fetch('/api/minitab-auth', { method: 'DELETE' });
    } finally {
      router.push('/minitab/login');
      router.refresh();
    }
  };

  return (
    <div className="bg-indigo-600 text-white">
      <div className="mx-auto max-w-[100rem] px-4 sm:px-6 h-9 flex items-center justify-between text-xs">
        {isHub ? (
          <span className="opacity-90">PHY 403 Student Area</span>
        ) : (
          <Link href="/minitab" className="opacity-90 hover:opacity-100 flex items-center gap-1">
            <span aria-hidden>←</span> Simulation Library
          </Link>
        )}
        <button
          onClick={logout}
          disabled={loggingOut}
          className="opacity-90 hover:opacity-100 underline underline-offset-2 disabled:opacity-50"
        >
          {loggingOut ? 'Logging out…' : 'Logout'}
        </button>
      </div>
    </div>
  );
}
