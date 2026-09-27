#!/bin/bash
# A-Factor STEM Studio — free student activity analytics for the minitab
# Run inside af2s/ folder: bash patches/patch-v65-minitab-analytics.sh
#
# Adds anonymous login and simulation-visit tracking, backed by Upstash Redis
# (permanently free tier: 256MB, 500K commands/month — plenty for a single
# course). No student names or identities are ever recorded — only login
# timestamps, per-simulation visit counts, and an anonymous per-browser
# session id used solely to count distinct devices.
#
# New:
#   /minitab/admin              — activity dashboard (bar chart + recent feed)
#   POST /api/minitab-track     — records a simulation-page visit
#   GET  /api/minitab-analytics — aggregated summary for the dashboard
#   src/lib/analytics/redis.ts  — Upstash client + tracking helpers
#
# Updated:
#   src/app/api/minitab-auth/route.ts — records a login on success
#   src/proxy.ts                      — assigns an anonymous session cookie
#   src/components/layout/MinitabBar.tsx — fires a visit beacon + "Analytics" link
#
# Everything here is best-effort: if Upstash isn't configured yet, tracking
# silently no-ops and the dashboard shows a setup notice — nothing here can
# ever block a student's login or a simulation from loading.
#
# ONE-TIME SETUP AFTER RUNNING THIS SCRIPT:
#   1. Create a free Redis database at https://upstash.com (or via Vercel's
#      Storage tab, which does the same thing through their Marketplace).
#   2. Add these two lines to your .env.local, from the Upstash dashboard:
#        UPSTASH_REDIS_REST_URL=...
#        UPSTASH_REDIS_REST_TOKEN=...
#   3. Restart your dev server (or redeploy on Vercel).
# Until you do this, /minitab/admin will show a "not connected yet" notice
# instead of data — everything else in the app is completely unaffected.

set -e
echo "Applying minitab analytics patch..."

mkdir -p src/lib/analytics
mkdir -p src/app/api/minitab-track
mkdir -p src/app/api/minitab-analytics
mkdir -p src/app/minitab/admin
mkdir -p src/app/api/minitab-auth
mkdir -p src/components/layout

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
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;
  client = new Redis({ url, token });
  return client;
}

const MAX_EVENTS = 500; // capped list — plenty for a single-course classroom tool, keeps well inside the free tier's 256MB

export async function recordLogin(): Promise<void> {
  const redis = getClient();
  if (!redis) return;
  try {
    const event = JSON.stringify({ t: Date.now() });
    await Promise.all([
      redis.incr('minitab:logins:count'),
      redis.lpush('minitab:logins:events', event),
      redis.ltrim('minitab:logins:events', 0, MAX_EVENTS - 1),
    ]);
  } catch (error) {
    console.error('[analytics] recordLogin failed', error);
  }
}

export async function recordVisit(slug: string, sessionId: string | undefined): Promise<void> {
  const redis = getClient();
  if (!redis) return;
  try {
    const event = JSON.stringify({ t: Date.now(), slug });
    const ops: Promise<unknown>[] = [
      redis.incr(`minitab:visits:count:${slug}`),
      redis.lpush('minitab:visits:events', event),
      redis.ltrim('minitab:visits:events', 0, MAX_EVENTS - 1),
    ];
    if (sessionId) ops.push(redis.sadd('minitab:sessions', sessionId));
    await Promise.all(ops);
  } catch (error) {
    console.error('[analytics] recordVisit failed', error);
  }
}

export interface AnalyticsSummary {
  configured: boolean;
  totalLogins: number;
  distinctSessions: number;
  visitsBySlug: { slug: string; count: number }[];
  recentEvents: { t: number; kind: 'login' | 'visit'; slug?: string }[];
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
    return { configured: false, totalLogins: 0, distinctSessions: 0, visitsBySlug: [], recentEvents: [] };
  }
  try {
    const [totalLogins, distinctSessions, loginEventsRaw, visitEventsRaw, ...counts] = await Promise.all([
      redis.get<number>('minitab:logins:count'),
      redis.scard('minitab:sessions'),
      redis.lrange('minitab:logins:events', 0, 49),
      redis.lrange('minitab:visits:events', 0, 49),
      ...KNOWN_SLUGS.map(slug => redis.get<number>(`minitab:visits:count:${slug}`)),
    ]);

    const visitsBySlug = KNOWN_SLUGS.map((slug, i) => ({ slug, count: counts[i] ?? 0 }))
      .sort((a, b) => b.count - a.count);

    type RawEvent = { t: number; slug?: string };
    const parseEvents = (raw: unknown[], kind: 'login' | 'visit') =>
      raw.map(r => {
        const parsed: RawEvent = typeof r === 'string' ? JSON.parse(r) : (r as RawEvent);
        return { t: parsed.t, kind, slug: parsed.slug };
      });

    const recentEvents = [...parseEvents(loginEventsRaw, 'login'), ...parseEvents(visitEventsRaw, 'visit')]
      .sort((a, b) => b.t - a.t)
      .slice(0, 50);

    return {
      configured: true,
      totalLogins: totalLogins ?? 0,
      distinctSessions: distinctSessions ?? 0,
      visitsBySlug,
      recentEvents,
    };
  } catch (error) {
    console.error('[analytics] getAnalyticsSummary failed', error);
    return { configured: true, totalLogins: 0, distinctSessions: 0, visitsBySlug: [], recentEvents: [] };
  }
}
FILEEOF

echo "  writing src/app/api/minitab-track/route.ts"
cat > src/app/api/minitab-track/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { recordVisit } from '@/lib/analytics/redis';

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { slug?: string };
    if (!body.slug || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'slug is required.' }, { status: 400 });
    }
    const sessionId = req.cookies.get(SESSION_COOKIE)?.value;

    // Best-effort — never blocks or errors out the page for the student if
    // this fails; a missed analytics beacon is not worth a broken page.
    recordVisit(body.slug, sessionId);

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error('[minitab-track] Error', error);
    return NextResponse.json({ ok: false });
  }
}
FILEEOF

echo "  writing src/app/api/minitab-analytics/route.ts"
cat > src/app/api/minitab-analytics/route.ts << 'FILEEOF'
import { NextResponse } from 'next/server';
import { getAnalyticsSummary } from '@/lib/analytics/redis';

export async function GET() {
  const summary = await getAnalyticsSummary();
  return NextResponse.json(summary);
}
FILEEOF

echo "  writing src/app/minitab/admin/page.tsx"
cat > src/app/minitab/admin/page.tsx << 'FILEEOF'
'use client';
import { useState, useEffect } from 'react';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';

interface AnalyticsSummary {
  configured: boolean;
  totalLogins: number;
  distinctSessions: number;
  visitsBySlug: { slug: string; count: number }[];
  recentEvents: { t: number; kind: 'login' | 'visit'; slug?: string }[];
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

function timeAgo(ts: number): string {
  const s = Math.floor((Date.now() - ts) / 1000);
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

export default function MinitabAnalyticsPage() {
  const [data, setData] = useState<AnalyticsSummary | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/minitab-analytics')
      .then(r => r.json())
      .then(setData)
      .finally(() => setLoading(false));
  }, []);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6">
            <p className="text-xs text-gray-400 mb-1">PHY 403 · Student Area</p>
            <h1 className="text-xl font-semibold text-gray-900">Activity Dashboard</h1>
            <p className="text-sm text-gray-500 mt-1">Logins and simulation visits, tracked anonymously — no student names or identities are recorded.</p>
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
                (from the Upstash dashboard, or Vercel&apos;s Storage tab) and redeploy — tracking starts automatically
                from the next login onward.
              </p>
            </div>
          )}

          {!loading && data && data.configured && (
            <>
              <div className="grid grid-cols-2 gap-4">
                <div className="rounded-2xl border border-gray-200 bg-white p-5">
                  <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Total logins</p>
                  <p className="text-3xl font-semibold text-gray-900">{data.totalLogins}</p>
                </div>
                <div className="rounded-2xl border border-gray-200 bg-white p-5">
                  <p className="text-xs text-gray-400 uppercase tracking-wide mb-1">Distinct devices/browsers</p>
                  <p className="text-3xl font-semibold text-gray-900">{data.distinctSessions}</p>
                </div>
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
                          {e.kind === 'login' ? '🔑 Student logged in' : `📊 Opened ${SLUG_LABELS[e.slug ?? ''] ?? e.slug}`}
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

echo "  writing src/app/api/minitab-auth/route.ts"
cat > src/app/api/minitab-auth/route.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';
import { recordLogin } from '@/lib/analytics/redis';

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

    // Best-effort, never blocks the login response if analytics isn't configured or fails.
    recordLogin();

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

echo "  writing src/proxy.ts"
cat > src/proxy.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';

export const config = {
  matcher: ['/minitab/:path*'],
};

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // The login page and its own auth API call must stay reachable — otherwise
  // nobody could ever get past the gate to enter the passcode in the first place.
  if (pathname === '/minitab/login') {
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

  // Anonymous per-browser session id, used only to count distinct visitors
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
  // the admin dashboard itself, since neither is a "simulation visit".
  useEffect(() => {
    if (pathname === '/minitab/login' || pathname === '/minitab/admin') return;
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
        <div className="flex items-center gap-4">
          <Link href="/minitab/admin" className="opacity-70 hover:opacity-100 text-[11px]">
            Analytics
          </Link>
          <button
            onClick={logout}
            disabled={loggingOut}
            className="opacity-90 hover:opacity-100 underline underline-offset-2 disabled:opacity-50"
          >
            {loggingOut ? 'Logging out…' : 'Logout'}
          </button>
        </div>
      </div>
    </div>
  );
}
FILEEOF

# Document the two new env vars in .env.example only — never touches
# .env.local, which holds your real secrets.
if ! grep -q "UPSTASH_REDIS_REST_URL" .env.example 2>/dev/null; then
  echo "UPSTASH_REDIS_REST_URL=" >> .env.example
  echo "UPSTASH_REDIS_REST_TOKEN=" >> .env.example
  echo "  updated .env.example"
fi

echo "  installing @upstash/redis..."
npm install @upstash/redis

echo ""
echo "Done."
echo ""
echo "New routes:"
echo "  /minitab/admin              — activity dashboard"
echo ""
echo "ONE-TIME SETUP required before data appears:"
echo "  1. Create a free database at https://upstash.com"
echo "  2. Add UPSTASH_REDIS_REST_URL and UPSTASH_REDIS_REST_TOKEN to .env.local"
echo "  3. Restart your dev server / redeploy"
echo ""
echo "Until then, /minitab/admin shows a setup notice — nothing else is affected."
