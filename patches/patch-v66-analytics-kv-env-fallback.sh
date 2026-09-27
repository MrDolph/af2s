#!/bin/bash
# A-Factor STEM Studio — support Vercel Storage-tab env var naming for analytics
# Run inside af2s/ folder: bash patches/patch-v66-analytics-kv-env-fallback.sh
#
# If you connected your Upstash database via Vercel's Storage tab (rather
# than pasting credentials from upstash.com directly), Vercel names the
# injected env vars KV_REST_API_URL / KV_REST_API_TOKEN instead of
# UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN. The v65 patch only
# checked the latter, so production would have silently found nothing.
#
# This patch checks both naming conventions, preferring UPSTASH_REDIS_REST_*
# if both happen to be set. Only src/lib/analytics/redis.ts changes.
#
# For local development, add to .env.local (from your Upstash/Vercel dashboard):
#   UPSTASH_REDIS_REST_URL=<KV_REST_API_URL's value>
#   UPSTASH_REDIS_REST_TOKEN=<KV_REST_API_TOKEN's value — the read-write one,
#                              not KV_REST_API_READ_ONLY_TOKEN>
# On Vercel itself, if you connected via the Storage tab, KV_REST_API_URL and
# KV_REST_API_TOKEN are already injected automatically — no action needed there.

set -e
echo "Applying analytics env-var fallback fix..."

mkdir -p src/lib/analytics

echo "  fixing src/lib/analytics/redis.ts"
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

echo ""
echo "Done. Rebuild to confirm:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
