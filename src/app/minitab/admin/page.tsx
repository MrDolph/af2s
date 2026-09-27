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
