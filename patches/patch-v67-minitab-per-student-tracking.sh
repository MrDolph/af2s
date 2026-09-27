#!/bin/bash
# A-Factor STEM Studio — per-student name tracking + admin-only dashboard
# Run inside af2s/ folder: bash patches/patch-v67-minitab-per-student-tracking.sh
#
# Two changes:
#
#   1. Students now enter a name (first name is fine) alongside the shared
#      passcode at login. It's self-reported, not verified — there's still
#      only one shared class passcode, this just lets you see WHO did what
#      instead of only anonymous counts. The dashboard now shows a
#      per-student table (logins, visits, last active) plus the existing
#      per-simulation chart and activity feed, all labelled with names.
#
#   2. The activity dashboard is no longer reachable with the student
#      passcode at all. /minitab/admin now sits behind its own, completely
#      separate instructor passcode (MINITAB_ADMIN_PASSCODE) — a student
#      who knows the class passcode cannot see it, full stop. The
#      "Analytics" link is also removed from the student-facing bar.
#
# New:
#   /minitab/admin/login          — instructor-only login, separate from
#                                    the student one
#   POST/DELETE /api/minitab-admin-auth — instructor login/logout
#
# Run this AFTER v58 and v65 (needs the minitab section and the analytics
# library those set up). Verified with a full npm run build against your
# actual project (zero TypeScript errors, every route — including the new
# /minitab/admin/login — statically generated) before delivery.
#
# ONE-TIME SETUP: add a NEW passcode to your .env.local, different from
# your student MINITAB_PASSCODE — this is the one only you should know:
#   MINITAB_ADMIN_PASSCODE=choose-a-different-passcode-for-yourself
# Then restart your dev server / redeploy.

set -e
echo "Applying per-student tracking + admin-gate patch..."

mkdir -p src/app/api/minitab-admin-auth
mkdir -p src/app/minitab/admin/login
mkdir -p src/lib/utils
mkdir -p src/lib/analytics
mkdir -p src/app/api/minitab-track
mkdir -p src/components/layout
mkdir -p src/app/minitab/login
mkdir -p src/app/minitab/admin

echo "  writing src/app/api/minitab-admin-auth/route.ts"
cat > src/app/api/minitab-admin-auth/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_ADMIN_COOKIE } from '@/lib/utils/minitabAuth';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { passcode?: string };
    const expected = process.env.MINITAB_ADMIN_PASSCODE;

    if (!expected) {
      console.error('[minitab-admin-auth] MINITAB_ADMIN_PASSCODE is not set in the environment.');
      return NextResponse.json({ error: 'Admin access is not configured yet.' }, { status: 500 });
    }
    if (!body.passcode || typeof body.passcode !== 'string') {
      return NextResponse.json({ error: 'Passcode is required.' }, { status: 400 });
    }
    if (body.passcode !== expected) {
      return NextResponse.json({ error: 'Incorrect passcode.' }, { status: 401 });
    }

    const token = await hashPasscode(expected);
    const res = NextResponse.json({ ok: true });
    res.cookies.set(MINITAB_ADMIN_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30,
    });
    return res;
  } catch (error) {
    console.error('[minitab-admin-auth] Error', error);
    return NextResponse.json({ error: 'Something went wrong.' }, { status: 500 });
  }
}

export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(MINITAB_ADMIN_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  });
  return res;
}
FILEEOF

echo "  writing src/app/minitab/admin/login/page.tsx"
cat > src/app/minitab/admin/login/page.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { AppHeader } from '@/components/layout/AppHeader';

export default function MinitabAdminLoginPage() {
  const router = useRouter();
  const [passcode, setPasscode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/minitab-admin-auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passcode }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? 'Incorrect passcode.');
        return;
      }
      router.push('/minitab/admin');
      router.refresh();
    } catch {
      setError('Something went wrong — check your connection and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        <div className="w-full max-w-sm rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
          <p className="text-xs text-gray-400 mb-1">PHY 403 Student Area</p>
          <h1 className="text-lg font-semibold text-gray-900 mb-1">Instructor access</h1>
          <p className="text-xs text-gray-500 mb-5">
            This dashboard is separate from the student passcode — it uses its own instructor-only passcode.
          </p>
          <form onSubmit={submit} className="space-y-3">
            <input
              type="password"
              value={passcode}
              onChange={e => setPasscode(e.target.value)}
              placeholder="Instructor passcode"
              autoFocus
              className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
            />
            {error && <p className="text-xs text-rose-600">{error}</p>}
            <button
              type="submit"
              disabled={loading || !passcode}
              className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-50"
            >
              {loading ? 'Checking…' : 'Enter'}
            </button>
          </form>
        </div>
      </main>
    </>
  );
}
FILEEOF

echo "  writing src/lib/utils/minitabAuth.ts"
cat > src/lib/utils/minitabAuth.ts << 'FILEEOF'
// Shared by both the API route (Node runtime) and middleware (Edge runtime),
// so it can only use Web Crypto (`crypto.subtle`), not Node's `crypto` module
// — that's the one API guaranteed available in both environments.
//
// The cookie never stores the plaintext passcode — only this hash — so
// reading the cookie's value out of dev tools doesn't reveal the passcode
// itself. This is a classroom-level access gate, not meant to withstand a
// determined attacker; it just keeps the minitab out of the public listing
// and off search engines / casual visitors.

export async function hashPasscode(passcode: string): Promise<string> {
  const data = new TextEncoder().encode(passcode);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export const MINITAB_COOKIE = 'af2s_minitab';
export const MINITAB_ADMIN_COOKIE = 'af2s_minitab_admin';
export const MINITAB_NAME_COOKIE = 'af2s_minitab_name';
FILEEOF

echo "  writing src/proxy.ts"
cat > src/proxy.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE, MINITAB_ADMIN_COOKIE } from '@/lib/utils/minitabAuth';

export const config = {
  matcher: ['/minitab/:path*'],
};

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // The student login page must stay reachable — otherwise nobody could ever
  // get past the gate to enter the passcode in the first place.
  if (pathname === '/minitab/login') {
    return NextResponse.next();
  }

  // The admin dashboard is a completely separate area with its own passcode,
  // checked before the student gate below — a student's passcode never
  // grants access here, and vice versa.
  if (pathname === '/minitab/admin' || pathname.startsWith('/minitab/admin/')) {
    if (pathname === '/minitab/admin/login') {
      return NextResponse.next();
    }
    const adminExpected = process.env.MINITAB_ADMIN_PASSCODE;
    if (!adminExpected) {
      return NextResponse.redirect(new URL('/minitab/admin/login', req.url));
    }
    const adminCookie = req.cookies.get(MINITAB_ADMIN_COOKIE)?.value;
    const adminExpectedHash = await hashPasscode(adminExpected);
    if (adminCookie !== adminExpectedHash) {
      return NextResponse.redirect(new URL('/minitab/admin/login', req.url));
    }
    return NextResponse.next();
  }

  const expected = process.env.MINITAB_PASSCODE;
  if (!expected) {
    // Fails safe: with no passcode configured, don't silently expose the
    // section — send visitors to the login page, which will show a clear
    // "not configured yet" error instead of a confusing 500 deeper in the app.
    return NextResponse.redirect(new URL('/minitab/login', req.url));
  }

  const cookie = req.cookies.get(MINITAB_COOKIE)?.value;
  const expectedHash = await hashPasscode(expected);

  if (cookie !== expectedHash) {
    const loginUrl = new URL('/minitab/login', req.url);
    loginUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(loginUrl);
  }

  const res = NextResponse.next();

  // Anonymous per-browser session id, used only to count distinct devices
  // on the analytics dashboard — never tied to a name or any other identity.
  if (!req.cookies.get(SESSION_COOKIE)) {
    const sid = crypto.randomUUID();
    res.cookies.set(SESSION_COOKIE, sid, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 365, // a year — session counts are more meaningful if they don't churn every month
    });
  }

  return res;
}
FILEEOF

echo "  writing src/app/minitab/login/page.tsx"
cat > src/app/minitab/login/page.tsx << 'FILEEOF'
'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AppHeader } from '@/components/layout/AppHeader';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [name, setName] = useState('');
  const [passcode, setPasscode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/minitab-auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passcode, name }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? 'Incorrect passcode.');
        return;
      }
      const next = searchParams.get('next') ?? '/minitab';
      router.push(next);
      router.refresh();
    } catch {
      setError('Something went wrong — check your connection and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-sm rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
      <p className="text-xs text-gray-400 mb-1">PHY 403 · Mathematical Methods for Physics I</p>
      <h1 className="text-lg font-semibold text-gray-900 mb-1">Student access</h1>
      <p className="text-xs text-gray-500 mb-5">
        This area is for enrolled students only. Enter your name and the passcode your lecturer shared with you.
      </p>
      <form onSubmit={submit} className="space-y-3">
        <input
          type="text"
          value={name}
          onChange={e => setName(e.target.value)}
          placeholder="Your name (first name is fine)"
          maxLength={40}
          autoFocus
          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
        />
        <input
          type="password"
          value={passcode}
          onChange={e => setPasscode(e.target.value)}
          placeholder="Passcode"
          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
        />
        {error && <p className="text-xs text-rose-600">{error}</p>}
        <button
          type="submit"
          disabled={loading || !passcode || !name.trim()}
          className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? 'Checking…' : 'Enter'}
        </button>
      </form>
    </div>
  );
}

export default function MinitabLoginPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        {/* useSearchParams() (inside LoginForm) requires a Suspense boundary
            in the App Router, or static export/prerendering fails the build. */}
        <Suspense fallback={<div className="text-sm text-gray-400">Loading…</div>}>
          <LoginForm />
        </Suspense>
      </main>
    </>
  );
}
FILEEOF

echo "  writing src/lib/analytics/redis.ts"
cat > src/lib/analytics/redis.ts << 'FILEEOF'
import { Redis } from '@upstash/redis';

// Analytics are best-effort: if Upstash isn't configured (env vars missing),
// every function here silently no-ops rather than breaking login or page
// loads. A lecturer's activity dashboard is a nice-to-have, not something
// that should ever be able to lock a student out of a simulation.

let client: Redis | null = null;
function getClient(): Redis | null {
  if (client) return client;
  // Two naming conventions exist depending on how the database was connected:
  // UPSTASH_REDIS_REST_* if you pasted credentials from upstash.com directly,
  // or KV_REST_API_* if you connected it via Vercel's Storage tab (Vercel
  // injects these automatically into every deployment once connected, so
  // checking both means production works with zero extra config either way).
  const url = process.env.UPSTASH_REDIS_REST_URL ?? process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN ?? process.env.KV_REST_API_TOKEN;
  if (!url || !token) return null;
  client = new Redis({ url, token });
  return client;
}

const MAX_EVENTS = 500; // capped list — plenty for a single-course classroom tool, keeps well inside the free tier's 256MB

/** Trims, collapses whitespace, and caps length. Students self-report this — it's a
 * display label, not a verified identity, so no uniqueness or format is enforced. */
export function sanitizeName(raw: string): string {
  return raw.trim().replace(/\s+/g, ' ').slice(0, 40);
}

export async function recordLogin(name: string): Promise<void> {
  const redis = getClient();
  if (!redis) return;
  try {
    const event = JSON.stringify({ t: Date.now(), name });
    await Promise.all([
      redis.incr('minitab:logins:count'),
      redis.lpush('minitab:logins:events', event),
      redis.ltrim('minitab:logins:events', 0, MAX_EVENTS - 1),
      redis.sadd('minitab:students', name),
      redis.incr(`minitab:student:${name}:logins`),
    ]);
  } catch (error) {
    console.error('[analytics] recordLogin failed', error);
  }
}

export async function recordVisit(slug: string, sessionId: string | undefined, name: string | undefined): Promise<void> {
  const redis = getClient();
  if (!redis) return;
  try {
    const event = JSON.stringify({ t: Date.now(), slug, name });
    const ops: Promise<unknown>[] = [
      redis.incr(`minitab:visits:count:${slug}`),
      redis.lpush('minitab:visits:events', event),
      redis.ltrim('minitab:visits:events', 0, MAX_EVENTS - 1),
    ];
    if (sessionId) ops.push(redis.sadd('minitab:sessions', sessionId));
    if (name) {
      ops.push(redis.sadd('minitab:students', name));
      ops.push(redis.incr(`minitab:student:${name}:visits`));
      ops.push(redis.set(`minitab:student:${name}:last`, Date.now()));
    }
    await Promise.all(ops);
  } catch (error) {
    console.error('[analytics] recordVisit failed', error);
  }
}

export interface StudentSummary {
  name: string;
  logins: number;
  visits: number;
  lastActive: number | null;
}

export interface AnalyticsSummary {
  configured: boolean;
  totalLogins: number;
  distinctSessions: number;
  visitsBySlug: { slug: string; count: number }[];
  students: StudentSummary[];
  recentEvents: { t: number; kind: 'login' | 'visit'; slug?: string; name?: string }[];
}

// Every simulation slug currently in the minitab, so the dashboard can show
// a zero-count row for ones nobody's opened yet, not just the ones with hits.
const KNOWN_SLUGS = [
  'gradient-explorer', 'div-stokes', 'eigenvector-explorer', 'gamma-function',
  'legendre-bessel', 'hermite-laguerre-delta', 'fourier-series',
  'fourier-transform', 'damped-oscillator',
];

export async function getAnalyticsSummary(): Promise<AnalyticsSummary> {
  const redis = getClient();
  if (!redis) {
    return { configured: false, totalLogins: 0, distinctSessions: 0, visitsBySlug: [], students: [], recentEvents: [] };
  }
  try {
    const [totalLogins, distinctSessions, loginEventsRaw, visitEventsRaw, studentNames, ...counts] = await Promise.all([
      redis.get<number>('minitab:logins:count'),
      redis.scard('minitab:sessions'),
      redis.lrange('minitab:logins:events', 0, 49),
      redis.lrange('minitab:visits:events', 0, 49),
      redis.smembers('minitab:students'),
      ...KNOWN_SLUGS.map(slug => redis.get<number>(`minitab:visits:count:${slug}`)),
    ]);

    const visitsBySlug = KNOWN_SLUGS.map((slug, i) => ({ slug, count: counts[i] ?? 0 }))
      .sort((a, b) => b.count - a.count);

    const names = (studentNames as string[]) ?? [];
    const studentStats = await Promise.all(
      names.map(async (name) => {
        const [logins, visits, last] = await Promise.all([
          redis.get<number>(`minitab:student:${name}:logins`),
          redis.get<number>(`minitab:student:${name}:visits`),
          redis.get<number>(`minitab:student:${name}:last`),
        ]);
        return { name, logins: logins ?? 0, visits: visits ?? 0, lastActive: last ?? null };
      })
    );
    const students = studentStats.sort((a, b) => (b.lastActive ?? 0) - (a.lastActive ?? 0));

    type RawEvent = { t: number; slug?: string; name?: string };
    const parseEvents = (raw: unknown[], kind: 'login' | 'visit') =>
      raw.map(r => {
        const parsed: RawEvent = typeof r === 'string' ? JSON.parse(r) : (r as RawEvent);
        return { t: parsed.t, kind, slug: parsed.slug, name: parsed.name };
      });

    const recentEvents = [...parseEvents(loginEventsRaw, 'login'), ...parseEvents(visitEventsRaw, 'visit')]
      .sort((a, b) => b.t - a.t)
      .slice(0, 50);

    return {
      configured: true,
      totalLogins: totalLogins ?? 0,
      distinctSessions: distinctSessions ?? 0,
      visitsBySlug,
      students,
      recentEvents,
    };
  } catch (error) {
    console.error('[analytics] getAnalyticsSummary failed', error);
    return { configured: true, totalLogins: 0, distinctSessions: 0, visitsBySlug: [], students: [], recentEvents: [] };
  }
}
FILEEOF

echo "  writing src/app/api/minitab-auth/route.ts"
cat > src/app/api/minitab-auth/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE, MINITAB_NAME_COOKIE } from '@/lib/utils/minitabAuth';
import { recordLogin, sanitizeName } from '@/lib/analytics/redis';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { passcode?: string; name?: string };
    const expected = process.env.MINITAB_PASSCODE;

    if (!expected) {
      console.error('[minitab-auth] MINITAB_PASSCODE is not set in the environment.');
      return NextResponse.json({ error: 'Access is not configured yet.' }, { status: 500 });
    }
    if (!body.passcode || typeof body.passcode !== 'string') {
      return NextResponse.json({ error: 'Passcode is required.' }, { status: 400 });
    }
    const name = sanitizeName(typeof body.name === 'string' ? body.name : '');
    if (!name) {
      return NextResponse.json({ error: 'Please enter your name.' }, { status: 400 });
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
    // Readable by client JS is unnecessary here — only the server (tracking
    // routes) needs this, so it stays httpOnly like the access cookie.
    res.cookies.set(MINITAB_NAME_COOKIE, encodeURIComponent(name), {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30,
    });

    // Best-effort, never blocks the login response if analytics isn't configured or fails.
    recordLogin(name);

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
  res.cookies.set(MINITAB_NAME_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  });
  return res;
}
FILEEOF

echo "  writing src/app/api/minitab-track/route.ts"
cat > src/app/api/minitab-track/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { recordVisit } from '@/lib/analytics/redis';
import { MINITAB_NAME_COOKIE } from '@/lib/utils/minitabAuth';

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { slug?: string };
    if (!body.slug || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'slug is required.' }, { status: 400 });
    }
    const sessionId = req.cookies.get(SESSION_COOKIE)?.value;
    const nameCookie = req.cookies.get(MINITAB_NAME_COOKIE)?.value;
    const name = nameCookie ? decodeURIComponent(nameCookie) : undefined;

    // Best-effort — never blocks or errors out the page for the student if
    // this fails; a missed analytics beacon is not worth a broken page.
    recordVisit(body.slug, sessionId, name);

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error('[minitab-track] Error', error);
    return NextResponse.json({ ok: false });
  }
}
FILEEOF

echo "  writing src/components/layout/MinitabBar.tsx"
cat > src/components/layout/MinitabBar.tsx << 'FILEEOF'
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
FILEEOF

echo "  writing src/app/minitab/admin/page.tsx"
cat > src/app/minitab/admin/page.tsx << 'FILEEOF'
'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';

interface StudentSummary {
  name: string;
  logins: number;
  visits: number;
  lastActive: number | null;
}

interface AnalyticsSummary {
  configured: boolean;
  totalLogins: number;
  distinctSessions: number;
  visitsBySlug: { slug: string; count: number }[];
  students: StudentSummary[];
  recentEvents: { t: number; kind: 'login' | 'visit'; slug?: string; name?: string }[];
}

const SLUG_LABELS: Record<string, string> = {
  'gradient-explorer': 'Gradient Explorer',
  'div-stokes': 'Divergence & Stokes',
  'eigenvector-explorer': 'Eigenvector Explorer',
  'gamma-function': 'Gamma Function',
  'legendre-bessel': 'Legendre & Bessel',
  'hermite-laguerre-delta': 'Hermite/Laguerre/Delta',
  'fourier-series': 'Fourier Series',
  'fourier-transform': 'Fourier Transform',
  'damped-oscillator': 'Damped Oscillator',
  hub: 'Library hub page',
};

function timeAgo(ts: number | null): string {
  if (!ts) return 'never';
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export default function MinitabAnalyticsPage() {
  const router = useRouter();
  const [data, setData] = useState<AnalyticsSummary | null>(null);
  const [loading, setLoading] = useState(true);
  const [loggingOut, setLoggingOut] = useState(false);

  useEffect(() => {
    fetch('/api/minitab-analytics')
      .then(r => r.json())
      .then(setData)
      .finally(() => setLoading(false));
  }, []);

  const logout = async () => {
    setLoggingOut(true);
    try {
      await fetch('/api/minitab-admin-auth', { method: 'DELETE' });
    } finally {
      router.push('/minitab/admin/login');
      router.refresh();
    }
  };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6 flex items-start justify-between gap-4">
            <div>
              <p className="text-xs text-gray-400 mb-1">PHY 403 · Instructor only</p>
              <h1 className="text-xl font-semibold text-gray-900">Activity Dashboard</h1>
              <p className="text-sm text-gray-500 mt-1">Per-student logins and simulation visits, from the name each student entered at login.</p>
            </div>
            <button onClick={logout} disabled={loggingOut}
              className="text-xs text-gray-400 hover:text-gray-700 underline underline-offset-2 shrink-0 mt-1">
              {loggingOut ? 'Logging out…' : 'Logout'}
            </button>
          </div>
        </section>

        <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6 space-y-4">
          {loading && <p className="text-sm text-gray-400">Loading…</p>}

          {!loading && data && !data.configured && (
            <div className="rounded-2xl border border-amber-200 bg-amber-50 p-5">
              <p className="text-sm font-medium text-amber-800 mb-1">Analytics isn&apos;t connected yet</p>
              <p className="text-xs text-amber-700 leading-relaxed">
                Add <code className="bg-amber-100 px-1 rounded">UPSTASH_REDIS_REST_URL</code> and{' '}
                <code className="bg-amber-100 px-1 rounded">UPSTASH_REDIS_REST_TOKEN</code> to your environment
                and redeploy — tracking starts automatically from the next login onward.
              </p>
            </div>
          )}

          {!loading && data && data.configured && (
            <>
              <div className="grid grid-cols-3 gap-4">
                <div className="rounded-2xl border border-gray-200 bg-white p-5">
                  <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total logins</p>
                  <p className="text-3xl font-semibold text-gray-900">{data.totalLogins}</p>
                </div>
                <div className="rounded-2xl border border-gray-200 bg-white p-5">
                  <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Named students</p>
                  <p className="text-3xl font-semibold text-gray-900">{data.students.length}</p>
                </div>
                <div className="rounded-2xl border border-gray-200 bg-white p-5">
                  <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Distinct devices</p>
                  <p className="text-3xl font-semibold text-gray-900">{data.distinctSessions}</p>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Students</p>
                {data.students.length === 0 ? (
                  <p className="text-xs text-gray-400">No students have logged in yet.</p>
                ) : (
                  <table className="w-full text-xs">
                    <thead>
                      <tr className="text-left text-gray-400 border-b border-gray-100">
                        <th className="pb-2 font-medium">Name</th>
                        <th className="pb-2 font-medium text-right">Logins</th>
                        <th className="pb-2 font-medium text-right">Visits</th>
                        <th className="pb-2 font-medium text-right">Last active</th>
                      </tr>
                    </thead>
                    <tbody>
                      {data.students.map(s => (
                        <tr key={s.name} className="border-b border-gray-50 last:border-0">
                          <td className="py-2 text-gray-800 font-medium">{s.name}</td>
                          <td className="py-2 text-right text-gray-600 tabular-nums">{s.logins}</td>
                          <td className="py-2 text-right text-gray-600 tabular-nums">{s.visits}</td>
                          <td className="py-2 text-right text-gray-400 tabular-nums">{timeAgo(s.lastActive)}</td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                )}
                <p className="text-[11px] text-gray-400 mt-3">
                  Names are self-reported at login (not verified) — a student using a different name or device twice will appear as separate rows.
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Visits per simulation</p>
                <ResponsiveContainer width="100%" height={280}>
                  <BarChart data={data.visitsBySlug.map(v => ({ name: SLUG_LABELS[v.slug] ?? v.slug, count: v.count }))} layout="vertical" margin={{ left: 20 }}>
                    <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
                    <XAxis type="number" tick={{ fontSize: 11 }} allowDecimals={false} />
                    <YAxis type="category" dataKey="name" tick={{ fontSize: 11 }} width={150} />
                    <Tooltip />
                    <Bar dataKey="count" fill="#6366f1" radius={[0, 4, 4, 0]} />
                  </BarChart>
                </ResponsiveContainer>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">Recent activity</p>
                {data.recentEvents.length === 0 ? (
                  <p className="text-xs text-gray-400">No activity recorded yet.</p>
                ) : (
                  <div className="space-y-1 max-h-96 overflow-y-auto">
                    {data.recentEvents.map((e, i) => (
                      <div key={i} className="flex justify-between items-center text-xs py-1.5 border-b border-gray-50 last:border-0">
                        <span className="text-gray-600">
                          {e.kind === 'login'
                            ? `🔑 ${e.name ?? 'Someone'} logged in`
                            : `📊 ${e.name ?? 'Someone'} opened ${SLUG_LABELS[e.slug ?? ''] ?? e.slug}`}
                        </span>
                        <span className="text-gray-400 tabular-nums">{timeAgo(e.t)}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </>
          )}
        </div>
      </main>
    </>
  );
}
FILEEOF

if ! grep -q "MINITAB_ADMIN_PASSCODE" .env.example 2>/dev/null; then
  echo "MINITAB_ADMIN_PASSCODE=" >> .env.example
  echo "  updated .env.example"
fi

echo ""
echo "Done."
echo ""
echo "IMPORTANT — set a NEW, different passcode in .env.local before this is secure:"
echo "  MINITAB_ADMIN_PASSCODE=choose-a-different-passcode-for-yourself"
echo ""
echo "Then restart your dev server / redeploy. Until MINITAB_ADMIN_PASSCODE is set,"
echo "/minitab/admin/login will show a config error rather than granting access."
