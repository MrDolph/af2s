#!/bin/bash
# A-Factor STEM Studio — visible Student Login link + working Logout button
# Run inside af2s/ folder: bash patches/patch-v62-minitab-login-logout-ui.sh
#
# Adds:
#   1. A "Student Login" link in the main site nav (desktop + mobile),
#      pointing to /minitab — the proxy (from v58/v61) redirects to the
#      passcode page automatically if not yet logged in.
#   2. A thin "PHY 403 Student Area" bar with a working Logout button,
#      shown across every page inside /minitab (via a new layout.tsx) —
#      hidden on the login page itself, since there's nothing to log out
#      of there yet.
#   3. A DELETE handler added to the existing /api/minitab-auth route,
#      which clears the access cookie (logout).
#
# Run this AFTER v58 (and v61, if you've applied the middleware->proxy
# rename) — it overwrites src/app/api/minitab-auth/route.ts and
# src/components/layout/AppHeader.tsx, adding to what's there rather than
# replacing the feature. Verified with a full `npm run build` against your
# actual project (zero TypeScript errors, all pre-existing and minitab
# routes statically generated) before delivery.

set -e
echo "Applying Student Login/Logout UI patch..."

mkdir -p src/app/api/minitab-auth
mkdir -p src/components/layout
mkdir -p src/app/minitab

echo "  writing src/app/api/minitab-auth/route.ts"
cat > src/app/api/minitab-auth/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { passcode?: string };
    const expected = process.env.MINITAB_PASSCODE;

    if (!expected) {
      console.error('[minitab-auth] MINITAB_PASSCODE is not set in the environment.');
      return NextResponse.json({ error: 'Access is not configured yet.' }, { status: 500 });
    }
    if (!body.passcode || typeof body.passcode !== 'string') {
      return NextResponse.json({ error: 'Passcode is required.' }, { status: 400 });
    }
    if (body.passcode !== expected) {
      return NextResponse.json({ error: 'Incorrect passcode.' }, { status: 401 });
    }

    const token = await hashPasscode(expected);
    const res = NextResponse.json({ ok: true });
    res.cookies.set(MINITAB_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30, // 30 days — students shouldn't need to re-enter it every visit
    });
    return res;
  } catch (error) {
    console.error('[minitab-auth] Error', error);
    return NextResponse.json({ error: 'Something went wrong.' }, { status: 500 });
  }
}

// Logout: clear the access cookie. Using DELETE keeps this in the same route
// as POST (login) — one file for the whole "session" resource — rather than
// a second, separate endpoint.
export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(MINITAB_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0, // expire immediately
  });
  return res;
}
FILEEOF

echo "  writing src/components/layout/MinitabBar.tsx"
cat > src/components/layout/MinitabBar.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import { usePathname, useRouter } from 'next/navigation';

export function MinitabBar() {
  const pathname = usePathname();
  const router = useRouter();
  const [loggingOut, setLoggingOut] = useState(false);

  // The login page has nothing to log out of yet — hide the bar there.
  if (pathname === '/minitab/login') return null;

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
        <span className="opacity-90">PHY 403 Student Area</span>
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
FILEEOF

echo "  writing src/app/minitab/layout.tsx"
cat > src/app/minitab/layout.tsx << 'FILEEOF'
import { MinitabBar } from '@/components/layout/MinitabBar';

export default function MinitabLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <MinitabBar />
      {children}
    </>
  );
}
FILEEOF

echo "  writing src/components/layout/AppHeader.tsx"
cat > src/components/layout/AppHeader.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { usePathname } from 'next/navigation';

const NAV = [
  { label: 'Simulations', href: '/simulations' },
  { label: 'About', href: '/about' },
];

export function AppHeader() {
  const [open, setOpen] = useState(false);
  const pathname = usePathname();

  return (
    <header className="sticky top-0 z-40 border-b border-gray-200 bg-white/95 backdrop-blur-sm">
      <div className="mx-auto max-w-7xl px-4 sm:px-6">
        <div className="flex h-14 items-center justify-between">
          {/* Logo */}
          <Link href="/" className="flex items-center gap-2 group">
            <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-600 group-hover:bg-indigo-700 transition">
              <svg width="14" height="14" viewBox="0 0 14 14" fill="white">
                <path d="M7 1L13 4.5V9.5L7 13L1 9.5V4.5L7 1Z"/>
              </svg>
            </div>
            <div className="leading-none">
              <span className="text-sm font-semibold text-gray-900">A-Factor</span>
              <span className="hidden sm:block text-[10px] text-gray-400 leading-none">STEM Studio</span>
            </div>
          </Link>

          {/* Desktop nav */}
          <nav className="hidden sm:flex items-center gap-1">
            {NAV.map(n => (
              <Link key={n.href} href={n.href}
                className={`px-3 py-1.5 rounded-lg text-sm transition ${
                  pathname.startsWith(n.href)
                    ? 'bg-indigo-50 text-indigo-700 font-medium'
                    : 'text-gray-500 hover:text-gray-900 hover:bg-gray-50'
                }`}>
                {n.label}
              </Link>
            ))}
            <Link href="/minitab"
              className={`px-3 py-1.5 rounded-lg text-sm transition ${
                pathname.startsWith('/minitab')
                  ? 'bg-indigo-50 text-indigo-700 font-medium'
                  : 'text-gray-500 hover:text-gray-900 hover:bg-gray-50'
              }`}>
              Student Login
            </Link>
            <Link href="/simulations"
              className="ml-2 rounded-lg bg-indigo-600 px-4 py-1.5 text-sm font-medium text-white hover:bg-indigo-700 transition">
              Try now
            </Link>
          </nav>

          {/* Mobile menu button */}
          <button onClick={() => setOpen(v => !v)}
            className="sm:hidden rounded-lg p-2 text-gray-500 hover:bg-gray-100 transition"
            aria-label="Menu">
            <svg width="18" height="18" viewBox="0 0 18 18" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round">
              {open
                ? <><path d="M3 3l12 12M15 3L3 15"/></>
                : <><path d="M2 5h14M2 9h14M2 13h14"/></>
              }
            </svg>
          </button>
        </div>

        {/* Mobile nav */}
        {open && (
          <div className="sm:hidden border-t border-gray-100 py-3 space-y-1">
            {NAV.map(n => (
              <Link key={n.href} href={n.href} onClick={() => setOpen(false)}
                className={`block px-3 py-2 rounded-lg text-sm transition ${
                  pathname.startsWith(n.href)
                    ? 'bg-indigo-50 text-indigo-700 font-medium'
                    : 'text-gray-600 hover:bg-gray-50'
                }`}>
                {n.label}
              </Link>
            ))}
            <Link href="/minitab" onClick={() => setOpen(false)}
              className={`block px-3 py-2 rounded-lg text-sm transition ${
                pathname.startsWith('/minitab')
                  ? 'bg-indigo-50 text-indigo-700 font-medium'
                  : 'text-gray-600 hover:bg-gray-50'
              }`}>
              Student Login
            </Link>
            <Link href="/simulations" onClick={() => setOpen(false)}
              className="block mt-2 rounded-lg bg-indigo-600 px-3 py-2 text-sm font-medium text-white text-center">
              Try now
            </Link>
          </div>
        )}
      </div>
    </header>
  );
}
FILEEOF

echo ""
echo "Done."
echo ""
echo "Students now see 'Student Login' in the main nav, linking to /minitab."
echo "Inside the student area, a thin indigo bar with a Logout button appears"
echo "on every page except the login page itself."
echo ""
echo "Clear your build cache and rebuild to confirm:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
