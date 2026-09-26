'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';

export function MinitabBar() {
  const pathname = usePathname();
  const router = useRouter();
  const [loggingOut, setLoggingOut] = useState(false);

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
