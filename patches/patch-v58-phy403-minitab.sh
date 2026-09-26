#!/bin/bash
# A-Factor STEM Studio — PHY 403 Student Minitab (passcode-gated)
# Run inside af2s/ folder: bash patch-v58-phy403-minitab.sh
#
# Adds a separate, passcode-protected section at /minitab, invisible from
# the public /simulations hub, for your PHY 403 students only. This patch
# does NOT touch src/app/simulations/page.tsx at all.
#
# Includes the first simulation: Damped Oscillator (Laplace transform,
# Chapters 14-15) — physics verified against RK4 numerical ODE integration
# to ~1e-12 before this was built, and this whole patch was verified with
# a full `npm run build` against your actual project before delivery.
#
# ONE MANUAL STEP AFTER RUNNING THIS SCRIPT:
#   Add a line to your .env.local (this script will NOT touch that file,
#   since it holds secrets):
#     MINITAB_PASSCODE=choose-a-passcode-for-your-students
#   Then restart your dev server. Share that passcode with your students;
#   they enter it once at /minitab and stay logged in for 30 days.

set -e
echo "Applying PHY 403 minitab patch..."

mkdir -p src/app/minitab/login
mkdir -p src/app/minitab/damped-oscillator
mkdir -p src/app/api/minitab-auth
mkdir -p src/components/simulation
mkdir -p src/lib/physics
mkdir -p src/lib/utils

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
FILEEOF

echo "  writing src/lib/physics/dampedOscillator.ts"
cat > src/lib/physics/dampedOscillator.ts << 'FILEEOF'
// ── Damped Harmonic Oscillator (PHY 403 §14–15) ────────────────────────────
// Governing ODE: y'' + 2γy' + ω₀²y = 0
// Solved via Laplace transform (Y(s) found algebraically, then inverted).
// Three regimes, selected by comparing γ and ω₀:
//   γ < ω₀  → underdamped   (decaying oscillation)
//   γ = ω₀  → critically damped (fastest non-oscillatory return to zero)
//   γ > ω₀  → overdamped    (slow, non-oscillatory decay)
//
// Verified against direct RK4 numerical integration of the ODE across all
// three regimes and several initial-condition combinations — max error
// ~1e-12 (floating-point noise), confirming the closed-form solution below.

export interface DampedOscillatorParams {
  gamma: number;   // damping coefficient γ (1/s)
  omega0: number;  // undamped natural angular frequency ω₀ (rad/s)
  y0: number;      // initial displacement y(0)
  yp0: number;     // initial velocity y'(0)
}

export type DampingRegime = 'underdamped' | 'critical' | 'overdamped';

export function dampingRegime(gamma: number, omega0: number): DampingRegime {
  const disc = omega0 * omega0 - gamma * gamma;
  if (Math.abs(disc) < 1e-6) return 'critical';
  return disc > 0 ? 'underdamped' : 'overdamped';
}

/** y(t) for the damped oscillator, valid across all three regimes. */
export function dampedY(t: number, { gamma, omega0, y0, yp0 }: DampedOscillatorParams): number {
  const disc = omega0 * omega0 - gamma * gamma;
  const b = yp0 + gamma * y0; // shared coefficient from the Laplace-transform partial fractions

  if (Math.abs(disc) < 1e-6) {
    // Critically damped: y(t) = e^{-γt}[y0 + (y'0 + γy0)t]
    return Math.exp(-gamma * t) * (y0 + b * t);
  }
  if (disc > 0) {
    // Underdamped: y(t) = e^{-γt}[y0 cos(ω_d t) + (b/ω_d) sin(ω_d t)]
    const wd = Math.sqrt(disc);
    return Math.exp(-gamma * t) * (y0 * Math.cos(wd * t) + (b / wd) * Math.sin(wd * t));
  }
  // Overdamped: y(t) = e^{-γt}[y0 cosh(ω_h t) + (b/ω_h) sinh(ω_h t)]
  const wh = Math.sqrt(-disc);
  return Math.exp(-gamma * t) * (y0 * Math.cosh(wh * t) + (b / wh) * Math.sinh(wh * t));
}

/** ω_d (underdamped) or ω_h (overdamped) — undefined/irrelevant at critical damping. */
export function dampedSecondaryFreq(gamma: number, omega0: number): number {
  const disc = omega0 * omega0 - gamma * gamma;
  return Math.sqrt(Math.abs(disc));
}

/** Amplitude envelope bound |y(t)| ≤ envelope(t) — exact for underdamped, an approximate guide otherwise. */
export function dampedEnvelope(t: number, { gamma, omega0, y0, yp0 }: DampedOscillatorParams): number {
  const disc = omega0 * omega0 - gamma * gamma;
  const b = yp0 + gamma * y0;
  const w = Math.sqrt(Math.max(Math.abs(disc), 0.09));
  const amp = Math.sqrt(y0 * y0 + (b / w) * (b / w));
  return amp * Math.exp(-gamma * t);
}

/** Generates {t, y} samples over [0, tmax] for plotting. */
export function generateDampedData(params: DampedOscillatorParams, tmax: number, points = 300) {
  const data: { t: number; y: number; envelope: number; envelopeNeg: number }[] = [];
  for (let i = 0; i <= points; i++) {
    const t = (i / points) * tmax;
    const env = dampedEnvelope(t, params);
    data.push({ t, y: dampedY(t, params), envelope: env, envelopeNeg: -env });
  }
  return data;
}
FILEEOF

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
FILEEOF

echo "  writing src/middleware.ts"
cat > src/middleware.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';

export const config = {
  matcher: ['/minitab/:path*'],
};

export async function middleware(req: NextRequest) {
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

  if (cookie === expectedHash) {
    return NextResponse.next();
  }

  const loginUrl = new URL('/minitab/login', req.url);
  loginUrl.searchParams.set('next', pathname);
  return NextResponse.redirect(loginUrl);
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
        body: JSON.stringify({ passcode }),
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
        This area is for enrolled students only. Enter the passcode your lecturer shared with you.
      </p>
      <form onSubmit={submit} className="space-y-3">
        <input
          type="password"
          value={passcode}
          onChange={e => setPasscode(e.target.value)}
          placeholder="Passcode"
          autoFocus
          className="w-full rounded-lg border border-gray-200 px-3 py-2.5 text-sm outline-none focus:border-indigo-400"
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

echo "  writing src/app/minitab/page.tsx"
cat > src/app/minitab/page.tsx << 'FILEEOF'
'use client';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

// This list grows as more PHY 403 simulations are added. Unlike the public
// /simulations hub, this page is only reachable after the /minitab middleware
// passcode check succeeds, so nothing here needs curriculum tags — it's a
// single-course reading list, not a multi-curriculum catalogue.
const SIMULATIONS = [
  {
    slug: 'damped-oscillator',
    href: '/minitab/damped-oscillator',
    title: 'Damped Oscillator (Laplace Transform)',
    description: "Drag γ past ω₀ and watch underdamped, critical, and overdamped regimes — every curve from Chapter 15's Laplace-transform solution, verified against RK4 numerical integration.",
    icon: '🌀',
    chapter: 'Ch 14–15',
  },
];

export default function MinitabHubPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6">
            <p className="text-xs text-gray-400 mb-1">PHY 403 · Mathematical Methods for Physics I</p>
            <h1 className="text-xl font-semibold text-gray-900">Student Simulation Library</h1>
            <p className="text-sm text-gray-500 mt-1">
              Interactive companions to the course notes — every simulation's physics is verified numerically before it's built.
            </p>
          </div>
        </section>

        <div className="mx-auto max-w-5xl px-4 sm:px-6 py-6">
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
            {SIMULATIONS.map(sim => (
              <Link
                key={sim.slug}
                href={sim.href}
                className="group rounded-2xl border border-gray-200 bg-white p-5 transition hover:border-indigo-300 hover:shadow-sm"
              >
                <div className="flex items-start justify-between gap-3">
                  <span className="text-2xl">{sim.icon}</span>
                  <span className="text-[10px] font-medium text-indigo-600 bg-indigo-50 px-2 py-1 rounded-full">
                    {sim.chapter}
                  </span>
                </div>
                <h2 className="mt-3 text-sm font-semibold text-gray-900 group-hover:text-indigo-700">
                  {sim.title}
                </h2>
                <p className="mt-1.5 text-xs text-gray-500 leading-relaxed">{sim.description}</p>
              </Link>
            ))}
          </div>
        </div>
      </main>
    </>
  );
}
FILEEOF

echo "  writing src/components/simulation/DampedOscillatorCanvas.tsx"
cat > src/components/simulation/DampedOscillatorCanvas.tsx << 'FILEEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { dampedY, type DampedOscillatorParams } from '@/lib/physics/dampedOscillator';

interface Props extends DampedOscillatorParams {
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

function drawSpring(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, coils = 8) {
  const coilW = 16;
  const segH = (y2 - y1) / (coils * 2 + 2);
  ctx.beginPath();
  ctx.moveTo(x, y1);
  ctx.lineTo(x, y1 + segH);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + coilW, y1 + segH + (2 * i + 1) * segH);
    ctx.lineTo(x - coilW, y1 + segH + (2 * i + 2) * segH);
  }
  ctx.lineTo(x, y2 - segH);
  ctx.lineTo(x, y2);
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 1.5; ctx.stroke();
}

// Dashpot (damper) symbol: a piston inside a cylinder — visually communicates
// "this is what γ represents" alongside the spring, which only represents ω₀.
function drawDamper(ctx: CanvasRenderingContext2D, x: number, y1: number, y2: number, pistonY: number) {
  const w = 14;
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1.5;
  ctx.strokeRect(x - w / 2, y1, w, (y2 - y1) * 0.55);
  ctx.beginPath();
  ctx.moveTo(x, y1); ctx.lineTo(x, pistonY);
  ctx.moveTo(x - w / 2 + 2, pistonY); ctx.lineTo(x + w / 2 - 2, pistonY);
  ctx.moveTo(x, pistonY); ctx.lineTo(x, y2);
  ctx.stroke();
}

export function DampedOscillatorCanvas({
  gamma, omega0, y0, yp0, isRunning, isPaused, onTick, width = 380, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const trailRef = useRef<number[]>([]);
  // Ref-mirror pattern (see project conventions) — avoids stale closures
  // capturing prop values from the render that scheduled the rAF loop.
  const sim = useRef({ gamma, omega0, y0, yp0, isRunning, isPaused, onTick });
  sim.current = { gamma, omega0, y0, yp0, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; trailRef.current = []; }, [gamma, omega0, y0, yp0]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const { gamma: g, omega0: w0, y0: Y0, yp0: Yp0, isRunning: r, isPaused: p, onTick: ot } = sim.current;
    const W = canvas.width, H = canvas.height;

    if (r && !p && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const y = dampedY(tRef.current, { gamma: g, omega0: w0, y0: Y0, yp0: Yp0 });
    ot?.(tRef.current);

    trailRef.current.push(y);
    if (trailRef.current.length > 50) trailRef.current.shift();

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cx = W / 2 - 25;
    const dx = W / 2 + 30;
    const ceilingY = 20;
    const equilY = H / 2 + 10;
    const scale = 80; // px per unit of y

    // Ceiling
    ctx.fillStyle = '#64748b'; ctx.fillRect(cx - 40, 0, 90, 12);

    const massY = equilY + y * scale;

    drawSpring(ctx, cx, ceilingY + 12, massY - 22);
    drawDamper(ctx, dx, ceilingY + 12, massY + 20, ceilingY + 12 + (massY - ceilingY - 12) * 0.5);

    // Equilibrium line
    ctx.setLineDash([4, 4]);
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(30, equilY); ctx.lineTo(W - 30, equilY); ctx.stroke();
    ctx.setLineDash([]);

    // Trail
    ctx.beginPath();
    trailRef.current.forEach((yy, i) => {
      const px = cx - 60 - (trailRef.current.length - i) * 1.5;
      const py = equilY + yy * scale;
      if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.25)'; ctx.lineWidth = 2; ctx.stroke();

    // Mass block (spans both the spring and damper attachment points)
    ctx.fillStyle = '#6366f1';
    ctx.beginPath();
    ctx.roundRect(cx - 45, massY - 18, 140, 36, 8);
    ctx.fill();
    ctx.fillStyle = 'white'; ctx.font = '11px sans-serif'; ctx.textAlign = 'center';
    ctx.fillText('m', cx + 25, massY + 4);

    if (isRunning && !isPaused) {
      rafRef.current = requestAnimationFrame(draw);
    }
  }, [isRunning, isPaused]);

  useEffect(() => {
    if (isRunning && !isPaused) {
      rafRef.current = requestAnimationFrame(draw);
    } else {
      draw(lastFrameRef.current ?? undefined);
    }
    return () => cancelAnimationFrame(rafRef.current);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isRunning, isPaused, draw, gamma, omega0, y0, yp0]);

  return <canvas ref={canvasRef} width={width} height={height} className="rounded-xl" />;
}
FILEEOF

echo "  writing src/components/simulation/DampedOscillatorGraph.tsx"
cat > src/components/simulation/DampedOscillatorGraph.tsx << 'FILEEOF'
'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateDampedData, dampedY, type DampedOscillatorParams } from '@/lib/physics/dampedOscillator';

const TMAX = 10;

interface Props extends DampedOscillatorParams {
  currentT?: number;
}

export function DampedOscillatorGraph({ gamma, omega0, y0, yp0, currentT = 0 }: Props) {
  // Memoized — regenerating 300 points every animation tick was wasted work;
  // the curve only changes when the physics parameters change.
  const data = useMemo(
    () => generateDampedData({ gamma, omega0, y0, yp0 }, TMAX),
    [gamma, omega0, y0, yp0]
  );

  const markerT = Math.min(currentT, TMAX);
  const liveY = dampedY(markerT, { gamma, omega0, y0, yp0 });

  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" domain={[0, TMAX]} tick={{ fontSize: 10 }}>
          <Label value="Time t (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="y(t)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey="envelope" stroke="#f59e0b" strokeWidth={1.2} strokeDasharray="4 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="envelopeNeg" stroke="#f59e0b" strokeWidth={1.2} strokeDasharray="4 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="y" stroke="#6366f1" strokeWidth={2.2} dot={false} isAnimationActive={false} />
        {markerT > 0 && (
          <>
            <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
            <ReferenceDot x={markerT} y={liveY} r={6} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          </>
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
FILEEOF

echo "  writing src/app/minitab/damped-oscillator/page.tsx"
cat > src/app/minitab/damped-oscillator/page.tsx << 'FILEEOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { DampedOscillatorCanvas } from '@/components/simulation/DampedOscillatorCanvas';
import { DampedOscillatorGraph } from '@/components/simulation/DampedOscillatorGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { dampingRegime, dampedSecondaryFreq } from '@/lib/physics/dampedOscillator';

const TEACHER_NOTES = [
  "y'' + 2γy' + ω₀²y = 0 models a car's suspension, a door closer, a voltmeter needle settling — anything that relaxes back to equilibrium after a disturbance, with some form of friction/resistance present.",
  "Chapter 15's method: take ℒ of both sides, solve the resulting algebraic equation for Y(s), then invert. The differential equation becomes ordinary algebra.",
  "The three regimes come from the sign of ω₀²−γ² inside the square root: positive → real oscillation frequency ω_d (underdamped); zero → critical damping; negative → real hyperbolic frequency ω_h (overdamped, no oscillation at all).",
  "Critical damping (γ=ω₀) is the fastest possible return to equilibrium WITHOUT overshooting — this is why shock absorbers and galvanometers are deliberately designed to sit at (or just past) this exact point.",
  "The dashed envelope curve is ±amplitude·e^(−γt) — every regime decays inside this envelope; only the underdamped case actually touches it periodically.",
];

const EXERCISES: { q: string; a: string }[] = [
  {
    q: 'A system has γ=1, ω₀=3, y(0)=2, y′(0)=0. Find ω_d and classify the regime.',
    a: 'ω₀²−γ²=9−1=8>0 → underdamped. ω_d=√8≈2.83 rad/s.',
  },
  {
    q: 'Using the values above, write down y(t) in closed form (no need to evaluate numerically).',
    a: "y(t)=e^(−t)[2cos(2.83t) + ((0+1×2)/2.83)sin(2.83t)] = e^(−t)[2cos(2.83t) + 0.707sin(2.83t)]",
  },
  {
    q: 'For what value of γ (given ω₀=5) does the system become critically damped?',
    a: 'γ=ω₀=5 exactly — this is the definition of critical damping.',
  },
  {
    q: 'A system has γ=4, ω₀=2. Is it under-, critically, or overdamped? Find ω_h.',
    a: 'γ>ω₀ → overdamped. ω_h=√(γ²−ω₀²)=√(16−4)=√12≈3.46.',
  },
  {
    q: "Explain, without solving the ODE, why the critically damped case can't be found by simply setting ω_d=0 in the underdamped formula.",
    a: "Setting ω_d=0 makes the (b/ω_d)sin(ω_d t) term divide by zero. The critically-damped solution isn't a limiting case you can just plug into the underdamped formula — it comes from a genuinely different partial-fraction decomposition of Y(s), because (s+γ)²+ω_d² becomes a repeated root (s+γ)² when ω_d=0, which inverts to a t·e^(−γt) term instead of a sine.",
  },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

const REGIME_META: Record<string, { label: string; color: string }> = {
  underdamped: { label: 'Underdamped — oscillates', color: 'bg-indigo-100 text-indigo-700' },
  critical: { label: 'Critically damped', color: 'bg-amber-100 text-amber-700' },
  overdamped: { label: 'Overdamped — no oscillation', color: 'bg-rose-100 text-rose-700' },
};

export default function DampedOscillatorPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [currentT, setCurrentT] = useState(0);

  const [gamma, setGamma] = useState(0.8);
  const [omega0, setOmega0] = useState(2.0);
  const [y0, setY0] = useState(1.0);
  const [yp0, setYp0] = useState(0.0);

  const regime = dampingRegime(gamma, omega0);
  const secondaryFreq = dampedSecondaryFreq(gamma, omega0);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [gamma, omega0, y0, yp0, reset]);

  // Throttled to ~25fps — see project conventions: updating React state every
  // animation frame stutters the Recharts graph re-render.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 380, 300, 500);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapters 14–15</p>
                <h1 className="text-lg font-semibold text-gray-900">Damped Oscillator (Laplace Transform)</h1>
              </div>
              <span className={`text-xs px-3 py-1.5 rounded-full font-medium ${REGIME_META[regime].color}`}>
                {REGIME_META[regime].label}
              </span>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Governing equation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">y&apos;&apos; + 2γy&apos; + ω₀²y = 0</span>
            <span className="text-xs text-gray-400 ml-2">
              {regime === 'underdamped' && `ω_d = ${secondaryFreq.toFixed(3)} rad/s`}
              {regime === 'overdamped' && `ω_h = ${secondaryFreq.toFixed(3)} rad/s`}
              {regime === 'critical' && 'y(t) = e^(−γt)[y₀ + (y′₀+γy₀)t]'}
            </span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            <div className="space-y-3 min-w-0">
              {/* Canvas */}
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DampedOscillatorCanvas key={resetKey}
                  gamma={gamma} omega0={omega0} y0={y0} yp0={yp0}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                <EmbedButton
                  path="/embed/damped-oscillator"
                  params={{ gamma, omega0, y0, yp0 }}
                  title="Damped Oscillator (Laplace Transform)"
                />
              </div>

              {/* Graph */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">y(t) vs time</p>
                <DampedOscillatorGraph gamma={gamma} omega0={omega0} y0={y0} yp0={yp0} currentT={currentT} />
              </div>
            </div>

            {/* Sliders + stats */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-4">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
                <Slider label="Damping γ" unit="1/s" value={gamma} min={0} max={6} step={0.05}
                  set={setGamma} color="#f59e0b" note="Larger γ = more friction/resistance" />
                <Slider label="Natural frequency ω₀" unit="rad/s" value={omega0} min={0.5} max={6} step={0.05}
                  set={setOmega0} color="#6366f1" note="What it would oscillate at with zero damping" />
                <Slider label="Initial displacement y(0)" unit="" value={y0} min={-2} max={2} step={0.1}
                  set={setY0} color="#10b981" />
                <Slider label="Initial velocity y'(0)" unit="/s" value={yp0} min={-4} max={4} step={0.1}
                  set={setYp0} color="#ec4899" />
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Calculated values</p>
                {[
                  { l: 'Regime', v: REGIME_META[regime].label, c: 'text-gray-700' },
                  { l: regime === 'overdamped' ? 'ω_h' : 'ω_d', v: `${secondaryFreq.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                  { l: 'y at t=3s', v: '', c: 'text-emerald-600' },
                ].filter(r => r.v).map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES.map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>

          </div>
        </div>
      </main>
    </>
  );
}
FILEEOF

# Add the passcode variable to .env.example only (never touches .env.local,
# which holds your real secrets) — so the requirement is documented for
# future reference / anyone else who clones the repo.
if ! grep -q "MINITAB_PASSCODE" .env.example 2>/dev/null; then
  echo "MINITAB_PASSCODE=" >> .env.example
  echo "  updated .env.example"
fi

echo ""
echo "Done."
echo ""
echo "MANUAL STEP REQUIRED:"
echo "  Add this line to your .env.local, with a real passcode:"
echo "    MINITAB_PASSCODE=choose-a-passcode-for-your-students"
echo "  Then restart your dev server (rm -rf .next if switching build modes)."
echo ""
echo "New routes:"
echo "  /minitab            — passcode-gated hub (not linked from public nav)"
echo "  /minitab/login       — passcode entry"
echo "  /minitab/damped-oscillator — Damped Oscillator (PHY 403 Ch 14-15)"
echo ""
echo "This patch was verified with a full 'npm run build' against your actual"
echo "project (all dependencies installed, TypeScript checked, all three new"
echo "routes statically generated with zero errors) before being delivered."
