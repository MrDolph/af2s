#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v3
#   1. FIX  Phase-space graph line missing (monotone interpolation breaks on a
#           curve that doubles back → linear + single closed loop)
#   2. NEW  Ohm's law & circuits  (ohm / series / parallel + I–V graph + embed)
#   3. NEW  Wave motion           (transverse / longitudinal / superposition /
#                                  standing + embed)
#   4. NEW  Refraction & lenses   (Snell+TIR / lens / mirror ray diagrams + embed)
#   5. NEW  Radioactive decay     (stochastic nuclei grid + N–t curve + embed)
#   6. Hub page: all four modules flipped from "coming soon" to LIVE
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v3-new-modules.sh
# (or from root if not yet moved:              bash patch-v3-new-modules.sh)
# Assumes patch v2 has already been applied.
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v3: phase-graph fix + 4 new simulation modules ──"
mkdir -p "src/app/embed/circuits" "src/app/embed/decay" "src/app/embed/optics" "src/app/embed/waves" "src/app/simulations" "src/app/simulations/ohms-law" "src/app/simulations/radioactive-decay" "src/app/simulations/refraction" "src/app/simulations/waves" "src/components/simulation" "src/lib/physics"

echo "  → src/components/simulation/SHMGraph.tsx"
cat > "src/components/simulation/SHMGraph.tsx" << 'AFEOF'
'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateSHMData, shmDisplacement, shmVelocity, shmAcceleration, shmKE, shmPE } from '@/lib/physics/shm';

const CYCLES = 3;

type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

interface Props {
  A: number; omega: number; m: number; k: number;
  mode: GraphMode; currentT?: number;
}

export function SHMGraph({ A, omega, m, k, mode, currentT = 0 }: Props) {
  // Memoized — regenerating 200 points on every animation tick was wasted
  // work; the curve only changes when the physics parameters change.
  const data = useMemo(() => generateSHMData(A, omega, m, k, CYCLES), [A, omega, m, k]);

  // The graph shows exactly CYCLES periods. SHM is periodic, so wrap the
  // live time marker back onto the visible window instead of letting it
  // run off the right edge and vanish (which looked like the graph had
  // fallen out of sync with the animation).
  const totalTime = CYCLES * (2 * Math.PI) / omega;
  const markerT = currentT > 0 ? currentT % totalTime : 0;

  // Live values at the marker time — computed from the SAME closed-form
  // equations that drive both the canvas animation and the plotted curve,
  // so the moving dot sits exactly ON the curve, perfectly in sync with
  // the mass/bob, at any frame rate.
  const liveX = shmDisplacement(A, omega, markerT);
  const liveV = shmVelocity(A, omega, markerT);
  const liveA = shmAcceleration(A, omega, markerT);
  const liveKE = shmKE(m, liveV);
  const livePE = shmPE(k, liveX);

  if (mode === 'phase') {
    // Phase space: v vs x. Two things matter here:
    // 1. type="linear" (NOT "monotone") — monotone interpolation assumes x is
    //    strictly increasing; a phase ellipse doubles back on itself, the
    //    interpolator produces NaN, and Recharts silently drops the entire
    //    path (the "missing line" bug).
    // 2. One single closed period, not 3 overlapping loops — the last point
    //    is appended equal to the first so the ellipse visibly closes.
    const period = Math.floor(data.length / CYCLES) + 1;
    const phaseData = [...data.slice(0, period), data[0]];
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={phaseData} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={[-A * 1.1, A * 1.1]}>
            <Label value="Displacement x (m)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Velocity v (m/s)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
          <Line type="linear" dataKey="v" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
          <ReferenceLine x={0} stroke="#e2e8f0" />
          <ReferenceLine y={0} stroke="#e2e8f0" />
          {markerT > 0 && (
            <ReferenceDot x={liveX} y={liveV} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
          )}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (mode === 'energy') {
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
            <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Energy (J)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4), '']} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
          <Legend wrapperStyle={{ fontSize: 10 }} />
          <Line type="monotone" dataKey="ke" stroke="#f59e0b" strokeWidth={2} dot={false} name="KE" />
          <Line type="monotone" dataKey="pe" stroke="#6366f1" strokeWidth={2} dot={false} name="PE" />
          <Line type="monotone" dataKey="te" stroke="#10b981" strokeWidth={1.5} dot={false} strokeDasharray="5 3" name="Total E" />
          {markerT > 0 && <>
            <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
            <ReferenceDot x={markerT} y={liveKE} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
            <ReferenceDot x={markerT} y={livePE} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          </>}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  const keyMap = { displacement: 'x', velocity: 'v', acceleration: 'a' };
  const colorMap = { displacement: '#6366f1', velocity: '#10b981', acceleration: '#f59e0b' };
  const labelMap = { displacement: 'Displacement (m)', velocity: 'Velocity (m/s)', acceleration: 'Acceleration (m/s²)' };
  const dataKey = keyMap[mode as keyof typeof keyMap];
  const color = colorMap[mode as keyof typeof colorMap];

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={labelMap[mode as keyof typeof labelMap]} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} dot={false} />
        {markerT > 0 && <>
          <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
          <ReferenceDot
            x={markerT}
            y={mode === 'displacement' ? liveX : mode === 'velocity' ? liveV : liveA}
            r={6} fill={color} stroke="#fff" strokeWidth={2} 
          />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}
AFEOF

echo "  → src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

export default function SimulationsPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => (
              <button key={t}
                className="shrink-0 rounded-full border border-gray-200 bg-white px-4 py-1.5 text-xs font-medium text-gray-600 hover:border-indigo-300 hover:text-indigo-700 transition whitespace-nowrap">
                {t}
              </button>
            ))}
          </div>

          {/* Cards grid */}
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {SIMULATIONS.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo "  → src/lib/physics/circuits.ts"
cat > "src/lib/physics/circuits.ts" << 'AFEOF'
// ── Ohm's law & DC circuits ───────────────────────────────────────────────────
// V = IR.  P = VI = I²R = V²/R.

export function ohmCurrent(V: number, R: number) {
  return R > 0 ? V / R : 0;
}
export function power(V: number, I: number) {
  return V * I;
}

// ── Series: same current everywhere, voltages add ─────────────────────────────
export function seriesTotal(resistors: number[]) {
  return resistors.reduce((a, r) => a + r, 0);
}
export function seriesAnalysis(V: number, resistors: number[]) {
  const Rtotal = seriesTotal(resistors);
  const I = ohmCurrent(V, Rtotal);
  return {
    Rtotal,
    I,
    drops: resistors.map(R => I * R),   // voltage divider: V_i = I·R_i
    powers: resistors.map(R => I * I * R),
    Ptotal: V * I,
  };
}

// ── Parallel: same voltage everywhere, currents add ───────────────────────────
export function parallelTotal(resistors: number[]) {
  const invSum = resistors.reduce((a, r) => a + (r > 0 ? 1 / r : 0), 0);
  return invSum > 0 ? 1 / invSum : 0;
}
export function parallelAnalysis(V: number, resistors: number[]) {
  const Rtotal = parallelTotal(resistors);
  const branches = resistors.map(R => ohmCurrent(V, R)); // current divider: I_i = V/R_i
  const I = branches.reduce((a, i) => a + i, 0);
  return {
    Rtotal,
    I,
    branches,
    powers: resistors.map(R => (V * V) / R),
    Ptotal: V * I,
  };
}

// I–V characteristic points for a fixed resistance (straight line, slope 1/R).
export function ivLine(R: number, vMax: number, points = 50) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const v = (i / points) * vMax;
    return { v: +v.toFixed(3), i: +ohmCurrent(v, R).toFixed(4) };
  });
}
AFEOF

echo "  → src/lib/physics/waves.ts"
cat > "src/lib/physics/waves.ts" << 'AFEOF'
// ── Wave motion ───────────────────────────────────────────────────────────────
// v = fλ,  ω = 2πf,  k = 2π/λ,  T = 1/f
// Travelling wave:  y(x, t) = A sin(kx − ωt)   (moving in +x)

export function waveSpeed(f: number, lambda: number) { return f * lambda; }
export function angularFreq(f: number) { return 2 * Math.PI * f; }
export function waveNumber(lambda: number) { return (2 * Math.PI) / lambda; }
export function period(f: number) { return f > 0 ? 1 / f : 0; }

export function travellingY(A: number, k: number, omega: number, x: number, t: number, phi = 0, dir: 1 | -1 = 1) {
  return A * Math.sin(k * x - dir * omega * t + phi);
}

// Superposition of two waves (same string): y = y1 + y2
export function superposedY(
  A1: number, A2: number, k1: number, k2: number,
  omega1: number, omega2: number, x: number, t: number, phi2 = 0,
) {
  return travellingY(A1, k1, omega1, x, t) + travellingY(A2, k2, omega2, x, t, phi2);
}

// Standing wave from two identical opposite-travelling waves:
// y = A sin(kx − ωt) + A sin(kx + ωt) = 2A sin(kx) cos(ωt)
export function standingY(A: number, k: number, omega: number, x: number, t: number) {
  return 2 * A * Math.sin(k * x) * Math.cos(omega * t);
}

// Node positions of a standing wave in [0, L]: x = nλ/2
export function standingNodes(lambda: number, L: number) {
  const nodes: number[] = [];
  for (let n = 0; n * lambda / 2 <= L + 1e-9; n++) nodes.push(n * lambda / 2);
  return nodes;
}
AFEOF

echo "  → src/lib/physics/optics.ts"
cat > "src/lib/physics/optics.ts" << 'AFEOF'
// ── Geometrical optics ────────────────────────────────────────────────────────
const DEG = Math.PI / 180;

// Snell's law: n1 sinθ1 = n2 sinθ2. Returns θ2 in degrees, or null for TIR.
export function snellTheta2(n1: number, n2: number, theta1Deg: number): number | null {
  const s = (n1 / n2) * Math.sin(theta1Deg * DEG);
  if (Math.abs(s) > 1) return null; // total internal reflection
  return Math.asin(s) / DEG;
}

// Critical angle (only exists going from dense → less dense, n1 > n2).
export function criticalAngle(n1: number, n2: number): number | null {
  if (n1 <= n2) return null;
  return Math.asin(n2 / n1) / DEG;
}

// ── Thin lens / spherical mirror ──────────────────────────────────────────────
// "Real is positive" convention (the one WAEC/NECO/IGCSE mark schemes use):
//   1/f = 1/u + 1/v
//   f > 0 : converging lens / concave mirror
//   f < 0 : diverging lens / convex mirror
//   u > 0 : real object
//   v > 0 : real image,  v < 0 : virtual image
// Magnification m = v/u  (m > 0 inverted-real for lens diagrams below,
// interpreted per device in the UI).
export interface ImageResult {
  v: number;          // image distance (signed)
  m: number;          // |magnification|
  real: boolean;
  inverted: boolean;
  atInfinity: boolean;
}

export function thinLensImage(u: number, f: number): ImageResult {
  // 1/v = 1/f − 1/u  →  v = uf/(u − f)
  if (Math.abs(u - f) < 1e-9) {
    return { v: Infinity, m: Infinity, real: true, inverted: true, atInfinity: true };
  }
  const v = (u * f) / (u - f);
  const m = Math.abs(v / u);
  const real = v > 0;
  // Converging lens: real image is inverted, virtual image is upright.
  // Diverging lens (f < 0): image always virtual + upright.
  const inverted = real;
  return { v, m, real, inverted, atInfinity: false };
}

// Same formula holds for mirrors in real-is-positive convention.
export const mirrorImage = thinLensImage;

// Power of a lens in dioptres (f in metres).
export function lensPower(f_m: number) { return f_m !== 0 ? 1 / f_m : 0; }
AFEOF

echo "  → src/lib/physics/decay.ts"
cat > "src/lib/physics/decay.ts" << 'AFEOF'
// ── Radioactive decay ─────────────────────────────────────────────────────────
// N(t) = N₀ · e^(−λt) = N₀ · 2^(−t/T½)
// λ = ln2 / T½          (decay constant)
// A = λN                (activity, decays per second)

export const LN2 = Math.LN2;

export function decayConstant(halfLife: number) {
  return halfLife > 0 ? LN2 / halfLife : 0;
}
export function remaining(N0: number, halfLife: number, t: number) {
  return N0 * Math.pow(2, -t / halfLife);
}
export function activity(N: number, halfLife: number) {
  return decayConstant(halfLife) * N;
}
// Probability that a single nucleus decays during a small interval dt.
export function decayProbability(halfLife: number, dt: number) {
  return 1 - Math.pow(2, -dt / halfLife);
}
// Time for N₀ to fall to N: t = T½ · log2(N₀/N)
export function timeToReach(N0: number, N: number, halfLife: number) {
  return N > 0 ? halfLife * Math.log2(N0 / N) : Infinity;
}

// Analytic decay curve for the graph.
export function decayCurve(N0: number, halfLife: number, tMax: number, points = 120) {
  return Array.from({ length: points + 1 }, (_, i) => {
    const t = (i / points) * tMax;
    return { t: +t.toFixed(3), n: +remaining(N0, halfLife, t).toFixed(2) };
  });
}
AFEOF

echo "  → src/components/simulation/CircuitCanvas.tsx"
cat > "src/components/simulation/CircuitCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { seriesAnalysis, parallelAnalysis, ohmCurrent } from '@/lib/physics/circuits';

export type CircuitMode = 'ohm' | 'series' | 'parallel';

interface Props {
  mode: CircuitMode;
  voltage: number;
  r1: number; r2: number; r3: number;
  isRunning: boolean; isPaused: boolean;
  width?: number; height?: number;
}

// Draw a resistor zig-zag along a horizontal segment.
function drawResistor(ctx: CanvasRenderingContext2D, x: number, y: number, len: number, label: string, value: number, vertical = false) {
  const teeth = 6, amp = 7;
  ctx.save();
  ctx.translate(x, y);
  if (vertical) ctx.rotate(Math.PI / 2);
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.moveTo(0, 0);
  const seg = len / (teeth + 1);
  ctx.lineTo(seg / 2, 0);
  for (let i = 0; i < teeth; i++) {
    ctx.lineTo(seg / 2 + seg * i + seg / 2, i % 2 === 0 ? -amp : amp);
  }
  ctx.lineTo(len - seg / 2, 0); ctx.lineTo(len, 0);
  ctx.stroke();
  ctx.restore();
  ctx.save();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  if (vertical) ctx.fillText(`${label}=${value}Ω`, x + 24, y + len / 2 + 3);
  else ctx.fillText(`${label}=${value}Ω`, x + len / 2, y - 14);
  ctx.restore();
}

function drawBattery(ctx: CanvasRenderingContext2D, x: number, y: number, V: number) {
  ctx.save();
  ctx.strokeStyle = '#475569'; ctx.lineWidth = 2;
  // long plate (+) and short plate (−)
  ctx.beginPath(); ctx.moveTo(x, y - 16); ctx.lineTo(x, y + 16); ctx.stroke();
  ctx.lineWidth = 4;
  ctx.beginPath(); ctx.moveTo(x + 10, y - 8); ctx.lineTo(x + 10, y + 8); ctx.stroke();
  ctx.fillStyle = '#334155'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText('+', x - 8, y - 20);
  ctx.fillText('−', x + 18, y - 20);
  ctx.fillText(`${V}V`, x + 5, y + 32);
  ctx.restore();
}

// A wire path is a list of points; electrons travel along it, distance
// parameterised by arc length so their SPEED on screen ∝ actual current.
type Path = { pts: [number, number][]; length: number; segLens: number[] };
function makePath(pts: [number, number][]): Path {
  const segLens: number[] = [];
  let length = 0;
  for (let i = 1; i < pts.length; i++) {
    const dx = pts[i][0] - pts[i - 1][0], dy = pts[i][1] - pts[i - 1][1];
    const l = Math.hypot(dx, dy);
    segLens.push(l); length += l;
  }
  return { pts, length, segLens };
}
function pointAt(path: Path, dist: number): [number, number] {
  let d = ((dist % path.length) + path.length) % path.length;
  for (let i = 0; i < path.segLens.length; i++) {
    if (d <= path.segLens[i]) {
      const f = path.segLens[i] === 0 ? 0 : d / path.segLens[i];
      const [x1, y1] = path.pts[i], [x2, y2] = path.pts[i + 1];
      return [x1 + (x2 - x1) * f, y1 + (y2 - y1) * f];
    }
    d -= path.segLens[i];
  }
  return path.pts[path.pts.length - 1];
}
function drawWire(ctx: CanvasRenderingContext2D, path: Path) {
  ctx.save();
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(path.pts[0][0], path.pts[0][1]);
  path.pts.slice(1).forEach(p => ctx.lineTo(p[0], p[1]));
  ctx.stroke();
  ctx.restore();
}
function drawElectrons(ctx: CanvasRenderingContext2D, path: Path, t: number, current: number, count: number) {
  if (current <= 0) return;
  // px/s proportional to current, capped for readability.
  const speed = Math.min(30 + current * 22, 170);
  ctx.save();
  for (let i = 0; i < count; i++) {
    const d = t * speed + (i / count) * path.length;
    const [x, y] = pointAt(path, d);
    ctx.beginPath(); ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fillStyle = '#f59e0b'; ctx.fill();
  }
  ctx.restore();
}

export function CircuitCanvas({ mode, voltage, r1, r2, r3, isRunning, isPaused, width = 640, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, voltage, r1, r2, r3, isRunning, isPaused });
  sim.current = { mode, voltage, r1, r2, r3, isRunning, isPaused };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, voltage, r1, r2, r3]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — electron drift speed on screen stays proportional
    // to the actual current at any display refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const L = 70, R = W - 70, T = 60, B = H - 50;

    if (s.mode === 'ohm') {
      const I = ohmCurrent(s.voltage, s.r1);
      const rLen = 130, rX = (W - rLen) / 2;
      const loop = makePath([[L, B], [L, T], [rX, T], [rX + rLen, T], [R, T], [R, B], [(R + L) / 2 + 20, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, rX, T, rLen, 'R', s.r1);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawElectrons(ctx, loop, t, I, 14);
      // Ammeter bubble
      ctx.save();
      ctx.fillStyle = 'white'; ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.arc(L, (T + B) / 2, 18, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('A', L, (T + B) / 2 - 2);
      ctx.font = '9px system-ui';
      ctx.fillText(`${I.toFixed(2)}A`, L, (T + B) / 2 + 10);
      ctx.restore();
    }

    if (s.mode === 'series') {
      const a = seriesAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const rLen = 90, gap = (R - L - 3 * rLen) / 4;
      const xs = [L + gap, L + gap * 2 + rLen, L + gap * 3 + rLen * 2];
      const loop = makePath([[L, B], [L, T], ...xs.flatMap((x): [number, number][] => [[x, T], [x + rLen, T]]), [R, T], [R, B], [L, B]]);
      drawWire(ctx, loop);
      drawResistor(ctx, xs[0], T, rLen, 'R₁', s.r1);
      drawResistor(ctx, xs[1], T, rLen, 'R₂', s.r2);
      drawResistor(ctx, xs[2], T, rLen, 'R₃', s.r3);
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
      drawElectrons(ctx, loop, t, a.I, 18);
      // Voltage drop labels under each resistor — the divider in action.
      ctx.save();
      ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'center';
      xs.forEach((x, i) => ctx.fillText(`${a.drops[i].toFixed(2)}V`, x + rLen / 2, T + 22));
      ctx.restore();
    }

    if (s.mode === 'parallel') {
      const a = parallelAnalysis(s.voltage, [s.r1, s.r2, s.r3]);
      const bx1 = L + 90, bx2 = R - 90;
      const rows = [T, (T + B) / 2 - 10, B - 60];
      const rLen = bx2 - bx1 - 60;
      // Main loop through the top branch, plus each branch loop.
      const branchPaths = rows.map(y => makePath([
        [L, B], [L, y], [bx1, y], [bx1 + 30, y], [bx1 + 30 + rLen, y], [bx2, y], [R, y], [R, B], [L, B],
      ]));
      // Rails
      ctx.save(); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(L, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(R, B); ctx.lineTo(R, rows[0]); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(L, B); ctx.lineTo(R, B); ctx.stroke();
      rows.forEach(y => { ctx.beginPath(); ctx.moveTo(L, y); ctx.lineTo(R, y); ctx.stroke(); });
      ctx.restore();
      const labels = ['R₁', 'R₂', 'R₃'], vals = [s.r1, s.r2, s.r3];
      rows.forEach((y, i) => {
        drawResistor(ctx, bx1 + 30, y, rLen, labels[i], vals[i]);
        // Electrons per branch — speed ∝ branch current, showing the
        // current divider: the smallest resistor gets the fastest flow.
        drawElectrons(ctx, branchPaths[i], t, a.branches[i], 10);
        ctx.save();
        ctx.fillStyle = '#059669'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`${a.branches[i].toFixed(2)}A`, bx2 + 6, y - 6);
        ctx.restore();
      });
      drawBattery(ctx, (R + L) / 2 - 5, B, s.voltage);
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText('● electron flow (speed ∝ current)', 8, H - 8);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/WaveCanvas.tsx"
cat > "src/components/simulation/WaveCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { angularFreq, waveNumber, travellingY, superposedY, standingY, standingNodes } from '@/lib/physics/waves';

export type WaveMode = 'transverse' | 'longitudinal' | 'superposition' | 'standing';

interface Props {
  mode: WaveMode;
  amplitude: number;    // m (display metres)
  frequency: number;    // Hz
  wavelength: number;   // m
  // superposition second wave:
  amplitude2?: number;
  frequency2?: number;
  phase2?: number;      // degrees
  isRunning: boolean; isPaused: boolean;
  onTick?: (t: number) => void;
  width?: number; height?: number;
}

const DOMAIN = 8; // metres of string shown

export function WaveCanvas({
  mode, amplitude, frequency, wavelength,
  amplitude2 = 0.5, frequency2 = 1, phase2 = 0,
  isRunning, isPaused, onTick, width = 660, height = 300,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2, isRunning, isPaused, onTick });
  sim.current = { mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2, isRunning, isPaused, onTick };

  useEffect(() => { tRef.current = 0; lastFrameRef.current = null; }, [mode, amplitude, frequency, wavelength, amplitude2, frequency2, phase2]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — one on-screen period equals the true T = 1/f
    // at any refresh rate.
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        tRef.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const t = tRef.current;
    s.onTick?.(t);

    const omega = angularFreq(s.frequency);
    const k = waveNumber(s.wavelength);
    const midY = H / 2 - 10;
    const xScale = W / DOMAIN;
    const yScale = Math.min(70, (H / 2 - 40) / Math.max(s.amplitude + (s.mode === 'superposition' ? s.amplitude2 : 0), s.mode === 'standing' ? 2 * s.amplitude : s.amplitude));

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Equilibrium line
    ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.setLineDash([4, 4]);
    ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
    ctx.setLineDash([]);

    if (s.mode === 'longitudinal') {
      // Columns of particles displaced ALONG x — compressions & rarefactions.
      const cols = 60, rowsN = 7;
      for (let c = 0; c < cols; c++) {
        const x0 = (c / cols) * DOMAIN;
        const dx = travellingY(s.amplitude * 0.35, k, omega, x0, t); // longitudinal displacement
        const px = (x0 + dx) * xScale;
        for (let r = 0; r < rowsN; r++) {
          const py = midY - 48 + r * 16;
          ctx.beginPath(); ctx.arc(px, py, 2.4, 0, Math.PI * 2);
          ctx.fillStyle = '#6366f1'; ctx.fill();
        }
      }
      // Label a compression: where displacement gradient is most negative
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('compressions ↔ rarefactions travel at v = fλ', 8, H - 26);
    } else {
      // Curve(s)
      const plot = (fn: (x: number) => number, color: string, lw = 2, dash: number[] = []) => {
        ctx.save();
        ctx.strokeStyle = color; ctx.lineWidth = lw; ctx.setLineDash(dash);
        ctx.beginPath();
        for (let px = 0; px <= W; px += 2) {
          const x = px / xScale;
          const y = midY - fn(x) * yScale;
          if (px === 0) ctx.moveTo(px, y); else ctx.lineTo(px, y);
        }
        ctx.stroke(); ctx.restore();
      };

      if (s.mode === 'transverse') {
        plot(x => travellingY(s.amplitude, k, omega, x, t), '#6366f1', 2.5);
        // Marked particle at x = 2m — shows a particle moves only UP/DOWN
        // while the wave PATTERN moves right.
        const xp = 2;
        const yp = midY - travellingY(s.amplitude, k, omega, xp, t) * yScale;
        ctx.beginPath(); ctx.arc(xp * xScale, yp, 6, 0, Math.PI * 2);
        ctx.fillStyle = '#ef4444'; ctx.fill();
        ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.stroke();
        ctx.setLineDash([3, 3]); ctx.strokeStyle = 'rgba(239,68,68,0.4)'; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xp * xScale, midY - s.amplitude * yScale); ctx.lineTo(xp * xScale, midY + s.amplitude * yScale); ctx.stroke();
        ctx.setLineDash([]);
        // Wavelength bracket
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        const bx = 0.5 * xScale, bw = s.wavelength * xScale, by = midY + s.amplitude * yScale + 14;
        ctx.beginPath(); ctx.moveTo(bx, by); ctx.lineTo(bx + bw, by); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(bx, by - 4); ctx.lineTo(bx, by + 4); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(bx + bw, by - 4); ctx.lineTo(bx + bw, by + 4); ctx.stroke();
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`λ = ${s.wavelength}m`, bx + bw / 2, by + 14);
      }

      if (s.mode === 'superposition') {
        const omega2 = angularFreq(s.frequency2);
        const k2 = waveNumber(s.wavelength); // same medium ⇒ same v; λ2 = v/f2
        const v = s.frequency * s.wavelength;
        const lambda2 = s.frequency2 > 0 ? v / s.frequency2 : s.wavelength;
        const k2b = waveNumber(lambda2);
        const phi2 = s.phase2 * Math.PI / 180;
        plot(x => travellingY(s.amplitude, k, omega, x, t), 'rgba(99,102,241,0.45)', 1.5, [5, 4]);
        plot(x => travellingY(s.amplitude2, k2b, omega2, x, t, phi2), 'rgba(16,185,129,0.45)', 1.5, [5, 4]);
        plot(x => superposedY(s.amplitude, s.amplitude2, k, k2b, omega, omega2, x, t, phi2), '#ef4444', 2.5);
        void k2;
        ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText('— resultant = y₁ + y₂ (principle of superposition)', 8, H - 26);
      }

      if (s.mode === 'standing') {
        plot(x => standingY(s.amplitude, k, omega, x, t), '#6366f1', 2.5);
        // Envelope
        plot(x => 2 * s.amplitude * Math.sin(k * x), 'rgba(99,102,241,0.2)', 1, [4, 4]);
        plot(x => -2 * s.amplitude * Math.sin(k * x), 'rgba(99,102,241,0.2)', 1, [4, 4]);
        // Nodes
        standingNodes(s.wavelength, DOMAIN).forEach(x => {
          ctx.beginPath(); ctx.arc(x * xScale, midY, 4, 0, Math.PI * 2);
          ctx.fillStyle = '#ef4444'; ctx.fill();
        });
        ctx.fillStyle = '#ef4444'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText('● nodes every λ/2 — no energy is transported', 8, H - 26);
      }
    }

    // HUD
    const v = s.frequency * s.wavelength;
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`v = fλ = ${s.frequency}×${s.wavelength} = ${v.toFixed(2)} m/s   T = ${(1 / s.frequency).toFixed(2)}s   t = ${t.toFixed(1)}s`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/OpticsCanvas.tsx"
cat > "src/components/simulation/OpticsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { snellTheta2, criticalAngle, thinLensImage } from '@/lib/physics/optics';

export type OpticsMode = 'snell' | 'lens' | 'mirror';

interface Props {
  mode: OpticsMode;
  // snell
  n1: number; n2: number; theta1: number;
  // lens / mirror (cm as display units)
  focal: number;          // |f| in cm
  objectDist: number;     // u in cm
  converging: boolean;    // true: convex lens / concave mirror
  width?: number; height?: number;
}

function arrow(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, color: string, lw = 2, headAt = 0.55) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = lw;
  ctx.beginPath(); ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke();
  // Direction arrowhead mid-ray
  const hx = x1 + (x2 - x1) * headAt, hy = y1 + (y2 - y1) * headAt;
  const ang = Math.atan2(y2 - y1, x2 - x1);
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(hx, hy);
  ctx.lineTo(hx - 9 * Math.cos(ang - 0.4), hy - 9 * Math.sin(ang - 0.4));
  ctx.lineTo(hx - 9 * Math.cos(ang + 0.4), hy - 9 * Math.sin(ang + 0.4));
  ctx.closePath(); ctx.fill();
  ctx.restore();
}

function objectArrow(ctx: CanvasRenderingContext2D, x: number, yBase: number, yTip: number, color: string, label: string) {
  ctx.save();
  ctx.strokeStyle = color; ctx.lineWidth = 3; ctx.lineCap = 'round';
  ctx.beginPath(); ctx.moveTo(x, yBase); ctx.lineTo(x, yTip); ctx.stroke();
  const dir = Math.sign(yTip - yBase) || -1;
  ctx.fillStyle = color;
  ctx.beginPath(); ctx.moveTo(x, yTip);
  ctx.lineTo(x - 6, yTip - dir * 10); ctx.lineTo(x + 6, yTip - dir * 10);
  ctx.closePath(); ctx.fill();
  ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(label, x, yTip - dir * 16);
  ctx.restore();
}

export function OpticsCanvas({ mode, n1, n2, theta1, focal, objectDist, converging, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ mode, n1, n2, theta1, focal, objectDist, converging });
  sim.current = { mode, n1, n2, theta1, focal, objectDist, converging };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    if (s.mode === 'snell') {
      const midY = H / 2, cx = W / 2;
      // Media
      ctx.fillStyle = 'rgba(219,234,254,0.6)'; ctx.fillRect(0, 0, W, midY);
      ctx.fillStyle = 'rgba(165,180,252,0.35)'; ctx.fillRect(0, midY, W, H - midY);
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(0, midY); ctx.lineTo(W, midY); ctx.stroke();
      // Normal
      ctx.setLineDash([5, 5]); ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(cx, 20); ctx.lineTo(cx, H - 20); ctx.stroke(); ctx.setLineDash([]);
      ctx.fillStyle = '#475569'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`n₁ = ${s.n1}`, 12, 22);
      ctx.fillText(`n₂ = ${s.n2}`, 12, H - 12);
      ctx.fillStyle = '#94a3b8'; ctx.font = '9px system-ui';
      ctx.fillText('normal', cx + 6, 26);

      const t1 = s.theta1 * Math.PI / 180;
      const rayLen = Math.min(cx, midY) - 30;
      // Incident ray (arrives at the boundary point)
      const ix = cx - Math.sin(t1) * rayLen, iy = midY - Math.cos(t1) * rayLen;
      arrow(ctx, ix, iy, cx, midY, '#6366f1', 2.5);
      ctx.fillStyle = '#4338ca'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`θ₁=${s.theta1}°`, cx - 44, midY - 22);

      const t2deg = snellTheta2(s.n1, s.n2, s.theta1);
      if (t2deg === null) {
        // Total internal reflection: all light reflects at θ1
        const rx = cx + Math.sin(t1) * rayLen, ry = midY - Math.cos(t1) * rayLen;
        arrow(ctx, cx, midY, rx, ry, '#ef4444', 2.5);
        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        const cc = criticalAngle(s.n1, s.n2);
        ctx.fillText(`TOTAL INTERNAL REFLECTION  (θ₁ > θc = ${cc?.toFixed(1)}°)`, cx, H - 30);
      } else {
        const t2 = t2deg * Math.PI / 180;
        // Refracted ray
        const fx = cx + Math.sin(t2) * rayLen, fy = midY + Math.cos(t2) * rayLen;
        arrow(ctx, cx, midY, fx, fy, '#10b981', 2.5);
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`θ₂=${t2deg.toFixed(1)}°`, cx + 48, midY + 30);
        // Partial (weak) reflection
        const rx = cx + Math.sin(t1) * rayLen * 0.6, ry = midY - Math.cos(t1) * rayLen * 0.6;
        ctx.save(); ctx.globalAlpha = 0.35;
        arrow(ctx, cx, midY, rx, ry, '#ef4444', 1.5);
        ctx.restore();
      }
      return;
    }

    // ── Lens / Mirror ray diagram ─────────────────────────────────────────────
    const axisY = H / 2, cx = W / 2;
    const f = s.converging ? s.focal : -s.focal;   // real-is-positive
    const u = s.objectDist;
    const img = thinLensImage(u, f);
    const scale = Math.min(3.2, (W / 2 - 30) / Math.max(u, Math.abs(img.atInfinity ? u : img.v), 2 * s.focal));
    const hObj = 44; // object height px

    // Principal axis
    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(0, axisY); ctx.lineTo(W, axisY); ctx.stroke();

    // Device
    ctx.save();
    if (s.mode === 'lens') {
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 3; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(cx, axisY - 78); ctx.lineTo(cx, axisY + 78); ctx.stroke();
      // Arrowheads: outward = converging (convex), inward = diverging (concave)
      const d = s.converging ? 1 : -1;
      [[-78, -1], [78, 1]].forEach(([yo, sgn]) => {
        ctx.fillStyle = '#6366f1';
        ctx.beginPath();
        ctx.moveTo(cx, axisY + yo);
        ctx.lineTo(cx - 8, axisY + yo - sgn * d * 10);
        ctx.lineTo(cx + 8, axisY + yo - sgn * d * 10);
        ctx.closePath(); ctx.fill();
      });
    } else {
      // Mirror arc: concave (converging) opens left toward the object.
      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 4;
      ctx.beginPath();
      const bow = s.converging ? 26 : -26;
      ctx.moveTo(cx + bow, axisY - 80);
      ctx.quadraticCurveTo(cx - bow, axisY, cx + bow, axisY + 80);
      ctx.stroke();
      // hatching behind mirror
      ctx.lineWidth = 1; ctx.strokeStyle = '#c7d2fe';
      for (let y = -70; y <= 70; y += 14) {
        ctx.beginPath();
        ctx.moveTo(cx + bow + 3, axisY + y);
        ctx.lineTo(cx + bow + 12, axisY + y - 8);
        ctx.stroke();
      }
    }
    ctx.restore();

    // Focal points
    const fPx = s.focal * scale;
    ctx.fillStyle = '#f59e0b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    [[-fPx, 'F'], [fPx, 'F'], [-2 * fPx, '2F'], [2 * fPx, '2F']].forEach(([dx, lab]) => {
      const x = cx + (dx as number);
      if (x < 10 || x > W - 10) return;
      ctx.beginPath(); ctx.arc(x, axisY, 3, 0, Math.PI * 2); ctx.fill();
      ctx.fillText(lab as string, x, axisY + 16);
    });

    // Object
    const objX = cx - u * scale;
    objectArrow(ctx, objX, axisY, axisY - hObj, '#0f172a', 'O');

    // Image
    const sideSign = s.mode === 'mirror' ? -1 : 1; // real image forms LEFT of a mirror
    if (!img.atInfinity) {
      const imgX = img.real ? cx + sideSign * img.v * scale : cx - Math.abs(img.v) * scale * (s.mode === 'mirror' ? -1 : 1);
      // Simpler + convention-correct: real → opposite side (lens) / same side (mirror);
      // virtual → same side as object (lens) / behind mirror.
      const ix = s.mode === 'lens'
        ? (img.real ? cx + img.v * scale : cx - Math.abs(img.v) * scale)
        : (img.real ? cx - img.v * scale : cx + Math.abs(img.v) * scale);
      void imgX;
      const hImg = hObj * img.m * (img.inverted ? 1 : -1); // inverted draws below? tip direction:
      const tipY = img.inverted ? axisY + hObj * img.m : axisY - hObj * img.m;
      if (ix > -40 && ix < W + 40) {
        objectArrow(ctx, ix, axisY, tipY, img.real ? '#10b981' : '#8b5cf6', img.real ? 'I (real)' : 'I (virtual)');
      }
      void hImg;

      // Principal rays from object tip
      const tip: [number, number] = [objX, axisY - hObj];
      const dev = cx;
      ctx.save();
      // Ray 1: parallel to axis → through/away-from F after device
      arrow(ctx, tip[0], tip[1], dev, tip[1], '#ef4444', 1.6, 0.5);
      // after device it must pass through the image tip
      const drawTo = (fromX: number, fromY: number, toX: number, toY: number, color: string, dashed = false) => {
        ctx.save(); if (dashed) ctx.setLineDash([5, 4]);
        ctx.strokeStyle = color; ctx.lineWidth = 1.6;
        // extend beyond the target
        const ang = Math.atan2(toY - fromY, toX - fromX);
        const ext = 60;
        ctx.beginPath(); ctx.moveTo(fromX, fromY);
        ctx.lineTo(toX + Math.cos(ang) * ext, toY + Math.sin(ang) * ext);
        ctx.stroke(); ctx.restore();
      };
      drawTo(dev, tip[1], ix, tipY, '#ef4444', !img.real);
      // Ray 2: through the centre (lens) — undeviated; mirror: to pole, reflects symmetric
      if (s.mode === 'lens') {
        drawTo(tip[0], tip[1], cx, axisY, '#3b82f6');
        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      } else {
        arrow(ctx, tip[0], tip[1], cx, axisY, '#3b82f6', 1.6, 0.5);
        drawTo(cx, axisY, ix, tipY, '#3b82f6', !img.real);
      }
      ctx.restore();
    } else {
      ctx.fillStyle = '#64748b'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('Object at F — rays emerge parallel, image at infinity', cx, 26);
    }

    // Caption
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    const nature = img.atInfinity ? 'at infinity'
      : `${img.real ? 'real' : 'virtual'}, ${img.inverted ? 'inverted' : 'upright'}, ${img.m > 1 ? 'magnified' : img.m < 1 ? 'diminished' : 'same size'}`;
    ctx.fillText(`u=${u}cm  f=${f}cm  →  v=${img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1) + 'cm'}  m=${img.atInfinity ? '∞' : img.m.toFixed(2)}  (${nature})`, 8, H - 8);
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
AFEOF

echo "  → src/components/simulation/DecayCanvas.tsx"
cat > "src/components/simulation/DecayCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { decayProbability, decayCurve, remaining } from '@/lib/physics/decay';

// ── Canvas: grid of nuclei decaying stochastically ────────────────────────────
interface CanvasProps {
  n0: number;           // number of nuclei (perfect square works best)
  halfLife: number;     // seconds
  isRunning: boolean; isPaused: boolean;
  resetKey: number;
  onTick?: (t: number, nRemaining: number) => void;
  width?: number; height?: number;
}

export function DecayCanvas({ n0, halfLife, isRunning, isPaused, resetKey, onTick, width = 420, height = 300 }: CanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const tRef = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const decayedRef = useRef<boolean[]>([]);
  const sim = useRef({ n0, halfLife, isRunning, isPaused, onTick });
  sim.current = { n0, halfLife, isRunning, isPaused, onTick };

  useEffect(() => {
    tRef.current = 0; lastFrameRef.current = null;
    decayedRef.current = new Array(n0).fill(false);
  }, [n0, halfLife, resetKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    // Real wall-clock dt — measured half-life on screen equals the slider
    // value at any refresh rate. Each undecayed nucleus decays this frame
    // with probability p = 1 − 2^(−dt/T½): memoryless, exactly like nature.
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
        tRef.current += dt;
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    if (dt > 0) {
      const p = decayProbability(s.halfLife, dt);
      const arr = decayedRef.current;
      for (let i = 0; i < arr.length; i++) {
        if (!arr[i] && Math.random() < p) arr[i] = true;
      }
    }
    const nLeft = decayedRef.current.reduce((a, d) => a + (d ? 0 : 1), 0);
    s.onTick?.(tRef.current, nLeft);

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const cols = Math.ceil(Math.sqrt(s.n0 * (W / H)));
    const rows = Math.ceil(s.n0 / cols);
    const cell = Math.min((W - 20) / cols, (H - 44) / rows);
    const ox = (W - cols * cell) / 2, oy = 8;
    const r = Math.max(2, cell * 0.32);
    for (let i = 0; i < s.n0; i++) {
      const cxp = ox + (i % cols) * cell + cell / 2;
      const cyp = oy + Math.floor(i / cols) * cell + cell / 2;
      ctx.beginPath(); ctx.arc(cxp, cyp, r, 0, Math.PI * 2);
      ctx.fillStyle = decayedRef.current[i] ? '#e2e8f0' : '#6366f1';
      ctx.fill();
    }

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`t = ${tRef.current.toFixed(1)}s   remaining: ${nLeft}/${s.n0}   ● undecayed  ○ decayed`, 8, H - 10);
    // Expected from theory, for comparison against the random sample
    ctx.fillStyle = '#94a3b8'; ctx.textAlign = 'right';
    ctx.fillText(`theory: ${remaining(s.n0, s.halfLife, tRef.current).toFixed(0)}`, W - 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}

// ── Graph: analytic N–t curve + live dot for the measured count ───────────────
interface GraphProps {
  n0: number; halfLife: number;
  currentT?: number; currentN?: number;
}

export function DecayGraph({ n0, halfLife, currentT = 0, currentN }: GraphProps) {
  const tMax = 4 * halfLife;
  const data = useMemo(() => decayCurve(n0, halfLife, tMax), [n0, halfLife, tMax]);
  const markerT = Math.min(currentT, tMax);
  const theoryN = remaining(n0, halfLife, markerT);

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={[0, tMax]}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={[0, n0]}>
          <Label value="Nuclei remaining N" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(0), 'N']} labelFormatter={t => `t=${Number(t).toFixed(1)}s`} />
        <Line type="monotone" dataKey="n" stroke="#6366f1" strokeWidth={2} dot={false} name="theory" />
        {/* Half-life gridlines: N halves at every T½ */}
        {[1, 2, 3].map(k => (
          <ReferenceLine key={k} x={k * halfLife} stroke="#e2e8f0" strokeDasharray="4 4"
            label={{ value: `${k}T½`, position: 'top', fontSize: 9, fill: '#94a3b8' }} />
        ))}
        {currentT > 0 && <>
          <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
          {/* dot ON the theoretical curve */}
          <ReferenceDot x={markerT} y={theoryN} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          {/* measured (random) count from the canvas — scatters around theory */}
          {currentN !== undefined && (
            <ReferenceDot x={markerT} y={Math.min(currentN, n0)} r={5} fill="#ef4444" stroke="#fff" strokeWidth={2} />
          )}
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}
AFEOF

echo "  → src/app/simulations/ohms-law/page.tsx"
cat > "src/app/simulations/ohms-law/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { CircuitCanvas, CircuitMode } from '@/components/simulation/CircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { ohmCurrent, seriesAnalysis, parallelAnalysis, ivLine } from '@/lib/physics/circuits';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<CircuitMode, { title: string; icon: string; sub: string; eq: string }> = {
  ohm:      { title: "Ohm's law",      icon: '⚡', sub: 'Single resistor',            eq: 'V = IR' },
  series:   { title: 'Series',         icon: '🔗', sub: 'Same current, voltages add', eq: 'R = R₁+R₂+R₃' },
  parallel: { title: 'Parallel',       icon: '🪜', sub: 'Same voltage, currents add', eq: '1/R = 1/R₁+1/R₂+1/R₃' },
};

const TEACHER_NOTES: Record<CircuitMode, string[]> = {
  ohm: [
    'V = IR only holds for OHMIC conductors — the I–V graph is a straight line through the origin whose slope is 1/R.',
    'The electron animation shows drift speed ∝ current: double the voltage, double the speed.',
    'Conventional current flows + → −, but the electrons physically drift the opposite way.',
    'Power dissipated P = VI = I²R = V²/R — a resistor converts electrical energy to heat.',
    'Try the sliders on the I–V graph: the operating point always sits on the line for a fixed R.',
  ],
  series: [
    'The SAME current flows through every component — there is only one path.',
    'Voltages divide in proportion to resistance: V₁/V₂ = R₁/R₂ (the potential divider).',
    'Total resistance is always LARGER than the largest single resistor.',
    'One broken component breaks the whole circuit — why old fairy lights all went out together.',
    'Check: the three voltage drops on the canvas always sum to the supply voltage.',
  ],
  parallel: [
    'Every branch gets the FULL supply voltage; the currents divide instead.',
    'The current divider: the SMALLEST resistance takes the LARGEST current — watch the electron speeds.',
    'Total resistance is always SMALLER than the smallest single resistor.',
    'House wiring is parallel: every appliance gets mains voltage, and one failing does not kill the rest.',
    'Check: branch currents on the canvas always sum to the total from the battery.',
  ],
};

const EXERCISES: Record<CircuitMode, { q: string; a: string }[]> = {
  ohm: [
    { q: 'A 12V battery drives a current of 3A through a resistor. Find R and the power dissipated.', a: 'R=V/I=12/3=4Ω. P=VI=12×3=36W.' },
    { q: 'The I–V graph of a conductor is a straight line of slope 0.25 A/V. Find its resistance.', a: 'Slope = 1/R → R = 1/0.25 = 4Ω.' },
    { q: 'An electric kettle rated 2000W runs on 230V mains. Find the current and its resistance.', a: 'I=P/V=2000/230≈8.7A. R=V/I=230/8.7≈26.4Ω.' },
  ],
  series: [
    { q: 'R₁=2Ω, R₂=3Ω, R₃=5Ω in series with a 20V battery. Find the current and V across R₂.', a: 'R=10Ω. I=20/10=2A. V₂=IR₂=2×3=6V.' },
    { q: 'Two resistors in series carry 0.5A. If V₁=3V and the supply is 9V, find R₂.', a: 'V₂=9−3=6V. R₂=V₂/I=6/0.5=12Ω.' },
    { q: 'Why does adding a resistor in series always reduce the current?', a: 'Total R increases (R = ΣRᵢ), and I = V/R with fixed V, so I falls.' },
  ],
  parallel: [
    { q: 'R₁=6Ω and R₂=3Ω in parallel across 12V. Find each branch current and the total.', a: 'I₁=12/6=2A, I₂=12/3=4A. Total I=6A (and R=2Ω checks: 12/2=6A).' },
    { q: 'Find the combined resistance of 4Ω, 6Ω and 12Ω in parallel.', a: '1/R=1/4+1/6+1/12=3/12+2/12+1/12=6/12 → R=2Ω.' },
    { q: 'Two equal resistors R in parallel — what is the combined resistance?', a: 'R/2. Equal resistors in parallel halve the resistance.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

// I–V characteristic with the live operating point sitting ON the line.
function IVGraph({ R, V }: { R: number; V: number }) {
  const vMax = 24;
  const data = useMemo(() => ivLine(R, vMax), [R]);
  const I = ohmCurrent(V, R);
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="v" type="number" tick={{ fontSize: 10 }} domain={[0, vMax]}>
          <Label value="Voltage V (V)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Current I (A)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3) + ' A']} labelFormatter={v => `V=${v}V`} />
        <Line type="monotone" dataKey="i" stroke="#6366f1" strokeWidth={2} dot={false} />
        <ReferenceDot x={V} y={I} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function OhmsLawPage() {
  const [mode, setMode] = useState<CircuitMode>('ohm');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [V, setV] = useState(12);
  const [r1, setR1] = useState(4);
  const [r2, setR2] = useState(6);
  const [r3, setR3] = useState(12);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
  }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, V, r1, r2, r3, reset]);

  const ser = seriesAnalysis(V, [r1, r2, r3]);
  const par = parallelAnalysis(V, [r1, r2, r3]);
  const I1 = ohmCurrent(V, r1);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity</p>
                <h1 className="text-lg font-semibold text-gray-900">Ohm&apos;s law &amp; circuits</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as CircuitMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            <span className="text-xs text-gray-400 ml-2">P = VI = I²R = V²/R</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
                  isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/circuits"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, V, r1, r2, r3 }} />
              </div>

              {mode === 'ohm' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">I–V characteristic</p>
                  <IVGraph R={r1} V={V} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Straight line through the origin — the red dot is the current operating point (slope = 1/R)
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
                <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
                {mode !== 'ohm' && <>
                  <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
                  <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'ohm' && <>
                    <StatRow label="Current I" value={I1.toFixed(3)} unit="A" color="text-indigo-600" />
                    <StatRow label="Power P" value={(V * I1).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Charge in 60s" value={(I1 * 60).toFixed(1)} unit="C" color="text-amber-600" />
                    <StatRow label="Energy in 60s" value={(V * I1 * 60).toFixed(0)} unit="J" color="text-rose-500" />
                  </>}
                  {mode === 'series' && <>
                    <StatRow label="Total R" value={ser.Rtotal.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Current I" value={ser.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="V across R₁" value={ser.drops[0].toFixed(2)} unit="V" color="text-amber-600" />
                    <StatRow label="V across R₂" value={ser.drops[1].toFixed(2)} unit="V" color="text-rose-500" />
                    <StatRow label="V across R₃" value={ser.drops[2].toFixed(2)} unit="V" color="text-purple-600" />
                    <StatRow label="Total power" value={ser.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                  {mode === 'parallel' && <>
                    <StatRow label="Total R" value={par.Rtotal.toFixed(2)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Total current" value={par.I.toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="I through R₁" value={par.branches[0].toFixed(3)} unit="A" color="text-amber-600" />
                    <StatRow label="I through R₂" value={par.branches[1].toFixed(3)} unit="A" color="text-rose-500" />
                    <StatRow label="I through R₃" value={par.branches[2].toFixed(3)} unit="A" color="text-purple-600" />
                    <StatRow label="Total power" value={par.Ptotal.toFixed(2)} unit="W" color="text-gray-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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
AFEOF

echo "  → src/app/simulations/waves/page.tsx"
cat > "src/app/simulations/waves/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { WaveCanvas, WaveMode } from '@/components/simulation/WaveCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { waveSpeed, angularFreq, waveNumber, period } from '@/lib/physics/waves';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<WaveMode, { title: string; icon: string; sub: string; eq: string }> = {
  transverse:    { title: 'Transverse',     icon: '🌊', sub: 'Particles ⊥ to travel',       eq: 'y = A sin(kx − ωt)' },
  longitudinal:  { title: 'Longitudinal',   icon: '🔊', sub: 'Particles ∥ to travel',        eq: 'compressions & rarefactions' },
  superposition: { title: 'Superposition',  icon: '➕', sub: 'Two waves on one string',      eq: 'y = y₁ + y₂' },
  standing:      { title: 'Standing wave',  icon: '🎻', sub: 'Two opposite travelling waves', eq: 'y = 2A sin(kx)cos(ωt)' },
};

const TEACHER_NOTES: Record<WaveMode, string[]> = {
  transverse: [
    'Watch the red particle: it only moves UP and DOWN while the wave pattern moves RIGHT — the wave transports energy, not matter.',
    'v = fλ is the single most examined wave equation. The green bracket marks one wavelength.',
    'Doubling frequency at fixed speed halves the wavelength — try it with the sliders.',
    'Examples: water surface waves, waves on a string, ALL electromagnetic waves.',
    'The particle completes one full oscillation in exactly one period T = 1/f.',
  ],
  longitudinal: [
    'Particles vibrate ALONG the direction of travel — regions bunch up (compressions) and spread out (rarefactions).',
    'Sound is the classic longitudinal wave; it cannot travel through a vacuum because it needs particles.',
    'Wavelength = distance between successive compressions (or rarefactions).',
    'The same v = fλ applies — only the direction of particle vibration differs from transverse.',
    'Seismic P-waves are longitudinal; S-waves are transverse (and cannot pass the liquid outer core).',
  ],
  superposition: [
    'When two waves meet, displacements simply ADD: y = y₁ + y₂ — the principle of superposition.',
    'Same frequency, 0° phase → constructive interference (double amplitude). 180° → destructive (cancellation).',
    'Slightly different frequencies produce BEATS — watch the resultant swell and fade.',
    'The two component waves pass through each other unchanged after overlapping.',
    'This is the foundation of interference, diffraction patterns, and noise-cancelling headphones.',
  ],
  standing: [
    'Two identical waves travelling in OPPOSITE directions superpose into a standing wave: y = 2A sin(kx)cos(ωt).',
    'Nodes (red dots) never move — they are spaced λ/2 apart. Antinodes oscillate with amplitude 2A.',
    'A standing wave transports NO energy — energy is trapped between nodes.',
    'Stringed instruments work on standing waves: fixed ends must be nodes, so only certain λ fit.',
    'Fundamental frequency of a string of length L: λ = 2L, f₁ = v/2L.',
  ],
};

const EXERCISES: Record<WaveMode, { q: string; a: string }[]> = {
  transverse: [
    { q: 'A wave has frequency 50Hz and wavelength 6.8m. Find its speed and period.', a: 'v=fλ=50×6.8=340 m/s. T=1/f=0.02s.' },
    { q: 'Radio waves (v=3×10⁸ m/s) at 100MHz — find the wavelength.', a: 'λ=v/f=3×10⁸/10⁸=3m.' },
    { q: 'A wave crest travels 15m in 3s while a particle completes 6 full oscillations. Find λ.', a: 'v=15/3=5 m/s. f=6/3=2Hz. λ=v/f=2.5m.' },
  ],
  longitudinal: [
    { q: 'Sound travels 660m in 2s. Adjacent compressions are 1.1m apart. Find the frequency.', a: 'v=660/2=330 m/s. λ=1.1m. f=v/λ=300Hz.' },
    { q: 'Why can light reach us from the Sun but sound cannot?', a: 'Light (transverse EM wave) needs no medium; sound (longitudinal mechanical) needs particles to compress — space is a vacuum.' },
    { q: 'An echo returns 0.6s after a clap, with v=340 m/s. How far is the wall?', a: 'Total path=340×0.6=204m. Distance=204/2=102m.' },
  ],
  superposition: [
    { q: 'Two waves of amplitude 3cm meet in phase. What is the resultant amplitude? And at 180°?', a: 'In phase: 3+3=6cm (constructive). Antiphase: 3−3=0 (destructive).' },
    { q: 'Two tuning forks of 256Hz and 260Hz sound together. What beat frequency is heard?', a: 'f_beat=|f₁−f₂|=4Hz — 4 loud-soft cycles per second.' },
    { q: 'State the principle of superposition.', a: 'When two or more waves meet at a point, the resultant displacement equals the vector sum of the individual displacements.' },
  ],
  standing: [
    { q: 'Adjacent nodes of a standing wave are 0.4m apart. Find the wavelength.', a: 'Node spacing=λ/2 → λ=0.8m.' },
    { q: 'A 0.6m string fixed at both ends vibrates in its fundamental mode with v=120 m/s. Find f₁.', a: 'λ=2L=1.2m. f₁=v/λ=120/1.2=100Hz.' },
    { q: 'How is a standing wave different from a travelling wave?', a: 'Standing: fixed nodes/antinodes, no energy transport, amplitude varies with position. Travelling: pattern moves, transports energy, every point oscillates with the same amplitude.' },
  ],
};

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

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function WavesPage() {
  const [mode, setMode] = useState<WaveMode>('transverse');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [A, setA] = useState(1);
  const [f, setF] = useState(0.5);
  const [lambda, setLambda] = useState(2);
  const [A2, setA2] = useState(0.7);
  const [f2, setF2] = useState(0.5);
  const [phase2, setPhase2] = useState(0);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
  }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, A, f, lambda, A2, f2, phase2, reset]);

  const v = waveSpeed(f, lambda);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Waves</p>
                <h1 className="text-lg font-semibold text-gray-900">Wave motion</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as WaveMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            <span className="text-xs text-gray-400 ml-2">v = fλ</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <WaveCanvas key={resetKey} mode={mode}
                  amplitude={A} frequency={f} wavelength={lambda}
                  amplitude2={A2} frequency2={f2} phase2={phase2}
                  isRunning={isRunning} isPaused={isPaused}
                  width={660} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/waves"
                  title={`${MODE_META[mode].title} wave — A-Factor STEM Studio`}
                  params={{ mode, A, f, lambda, A2, f2, phase2 }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Amplitude" unit="m" value={A} min={0.2} max={1.5} step={0.1} set={setA} color="#6366f1" />
                <Slider label="Frequency" unit="Hz" value={f} min={0.1} max={2} step={0.05} set={setF} color="#f59e0b" note="Slow enough to follow by eye" />
                <Slider label="Wavelength" unit="m" value={lambda} min={0.5} max={4} step={0.1} set={setLambda} color="#10b981" />
                {mode === 'superposition' && <>
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide pt-1">Second wave</p>
                  <Slider label="Amplitude A₂" unit="m" value={A2} min={0.1} max={1.5} step={0.1} set={setA2} color="#8b5cf6" />
                  <Slider label="Frequency f₂" unit="Hz" value={f2} min={0.1} max={2} step={0.05} set={setF2} color="#ef4444" note="Set slightly different from f for beats" />
                  <Slider label="Phase difference" unit="°" value={phase2} min={0} max={360} step={5} set={setPhase2} color="#0ea5e9" note="0° constructive · 180° destructive" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Wave speed v" value={v.toFixed(2)} unit="m/s" color="text-indigo-600" />
                  <StatRow label="Period T" value={period(f).toFixed(2)} unit="s" color="text-emerald-600" />
                  <StatRow label="Angular freq ω" value={angularFreq(f).toFixed(3)} unit="rad/s" color="text-amber-600" />
                  <StatRow label="Wave number k" value={waveNumber(lambda).toFixed(3)} unit="rad/m" color="text-rose-500" />
                  {mode === 'superposition' && <>
                    <StatRow label="Beat frequency" value={Math.abs(f - f2).toFixed(2)} unit="Hz" color="text-purple-600" />
                    <StatRow label="Max resultant" value={(A + A2).toFixed(2)} unit="m" color="text-gray-600" />
                  </>}
                  {mode === 'standing' && <>
                    <StatRow label="Node spacing" value={(lambda / 2).toFixed(2)} unit="m" color="text-purple-600" />
                    <StatRow label="Antinode amp." value={(2 * A).toFixed(2)} unit="m" color="text-gray-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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
AFEOF

echo "  → src/app/simulations/refraction/page.tsx"
cat > "src/app/simulations/refraction/page.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { snellTheta2, criticalAngle, thinLensImage, lensPower } from '@/lib/physics/optics';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<OpticsMode, { title: string; icon: string; sub: string; eq: string }> = {
  snell:  { title: 'Refraction', icon: '💠', sub: 'Light crossing a boundary', eq: 'n₁ sinθ₁ = n₂ sinθ₂' },
  lens:   { title: 'Lenses',     icon: '🔍', sub: 'Convex & concave',          eq: '1/f = 1/u + 1/v' },
  mirror: { title: 'Mirrors',    icon: '🪞', sub: 'Concave & convex',          eq: '1/f = 1/u + 1/v' },
};

const PRESETS = [
  { label: 'Air → Glass', n1: 1.0, n2: 1.5 },
  { label: 'Air → Water', n1: 1.0, n2: 1.33 },
  { label: 'Glass → Air', n1: 1.5, n2: 1.0 },
  { label: 'Water → Air', n1: 1.33, n2: 1.0 },
  { label: 'Diamond → Air', n1: 2.42, n2: 1.0 },
];

const TEACHER_NOTES: Record<OpticsMode, string[]> = {
  snell: [
    'Into a DENSER medium (n₂ > n₁): light bends TOWARDS the normal. Into a less dense medium: away from it.',
    'The critical angle only exists going dense → less dense; sinθc = n₂/n₁.',
    'Beyond θc, ALL light reflects: total internal reflection — the basis of optical fibres and diamond sparkle.',
    'Refractive index n = c/v = sinθ₁/sinθ₂ = real depth / apparent depth (three exam definitions of the same thing).',
    'Diamond → air: θc ≈ 24.4° — tiny, which is why diamonds trap and bounce light so much.',
  ],
  lens: [
    'Real-is-positive convention: f > 0 for converging (convex), f < 0 for diverging (concave). WAEC/IGCSE mark schemes use this.',
    'Convex lens: object beyond 2F → diminished real image; between F and 2F → magnified real image; inside F → magnified virtual (magnifying glass).',
    'A concave lens ALWAYS gives a virtual, upright, diminished image regardless of object position.',
    'Two principal rays fix the image: parallel-to-axis (bends through F) and through the optical centre (undeviated).',
    'Lens power P = 1/f (f in metres), unit dioptre — opticians add powers of lenses in contact.',
  ],
  mirror: [
    'Concave mirror (converging, f > 0): same image rules as a convex lens — but real images form on the SAME side as the object.',
    'Convex mirror (diverging, f < 0): always virtual, upright, diminished — that is why it is used for car wing mirrors and shop security ("objects are closer than they appear").',
    'Focal length f = R/2 where R is the radius of curvature.',
    'Uses of concave mirrors: shaving/makeup mirrors (object inside F → magnified upright virtual image), torch and headlamp reflectors (bulb at F → parallel beam).',
    'The mirror formula is identical to the lens formula in the real-is-positive convention.',
  ],
};

const EXERCISES: Record<OpticsMode, { q: string; a: string }[]> = {
  snell: [
    { q: 'Light passes from air into glass (n=1.5) at 45°. Find the angle of refraction.', a: 'sinθ₂ = sin45°/1.5 = 0.707/1.5 = 0.471 → θ₂ = 28.1°.' },
    { q: 'Find the critical angle for water (n=1.33) to air.', a: 'sinθc = 1/1.33 = 0.752 → θc = 48.8°.' },
    { q: 'Light travels at 3×10⁸ m/s in air. Find its speed in glass of n=1.5.', a: 'v = c/n = 3×10⁸/1.5 = 2×10⁸ m/s.' },
  ],
  lens: [
    { q: 'An object 30cm from a convex lens of f=20cm. Find the image position and magnification.', a: '1/v = 1/20 − 1/30 = 1/60 → v = 60cm (real). m = v/u = 2 (magnified, inverted).' },
    { q: 'An object 10cm from a convex lens of f=15cm. Describe the image.', a: '1/v = 1/15 − 1/10 = −1/30 → v = −30cm: virtual, upright, m=3 — a magnifying glass.' },
    { q: 'Find the power of a converging lens with f = 25cm.', a: 'P = 1/f = 1/0.25 = +4 dioptres.' },
  ],
  mirror: [
    { q: 'An object 40cm from a concave mirror of f=15cm. Find the image.', a: '1/v = 1/15 − 1/40 = 5/120 → v = 24cm: real, inverted, m = 0.6 (diminished).' },
    { q: 'Why are convex mirrors used as driving mirrors?', a: 'They always give an upright, diminished, virtual image with a much wider field of view than a plane mirror.' },
    { q: 'A concave mirror has radius of curvature 60cm. Where must a bulb be placed for a parallel beam?', a: 'f = R/2 = 30cm. Place the bulb at the focal point, 30cm from the pole.' },
  ],
};

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

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function RefractionPage() {
  const [mode, setMode] = useState<OpticsMode>('snell');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [n1, setN1] = useState(1.0);
  const [n2, setN2] = useState(1.5);
  const [theta1, setTheta1] = useState(35);
  const [focal, setFocal] = useState(15);
  const [objectDist, setObjectDist] = useState(40);
  const [converging, setConverging] = useState(true);

  const t2 = snellTheta2(n1, n2, theta1);
  const critAng = criticalAngle(n1, n2);
  const f = converging ? focal : -focal;
  const img = thinLensImage(objectDist, f);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Optics</p>
                <h1 className="text-lg font-semibold text-gray-900">Refraction &amp; lenses</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as OpticsMode[]).map(m => (
              <button key={m} onClick={() => { setMode(m); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span><span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{MODE_META[mode].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{MODE_META[mode].eq}</span>
            {mode !== 'snell' && <span className="text-xs text-gray-400 ml-2">m = v/u · real is positive</span>}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
                  focal={focal} objectDist={objectDist} converging={converging}
                  width={660} height={320} />
              </div>

              <div className="flex flex-wrap items-center justify-end gap-2">
                <EmbedButton path="/embed/optics"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, n1, n2, theta1, focal, u: objectDist, conv: converging ? 1 : 0 }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {mode === 'snell' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {PRESETS.map(p => (
                      <button key={p.label} onClick={() => { setN1(p.n1); setN2(p.n2); }}
                        className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                          n1 === p.n1 && n2 === p.n2
                            ? 'border-indigo-300 bg-indigo-50 text-indigo-700'
                            : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{p.label}</button>
                    ))}
                  </div>
                  <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1"
                    note={critAng !== null ? `Critical angle θc = ${critAng.toFixed(1)}° — push θ₁ past it for TIR` : undefined} />
                  <Slider label="n₁ (top medium)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
                  <Slider label="n₂ (bottom medium)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
                </>}

                {mode !== 'snell' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Type</span>
                    <div className="flex gap-2">
                      {([true, false] as const).map(c => (
                        <button key={String(c)} onClick={() => setConverging(c)}
                          className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                            converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {mode === 'lens'
                            ? (c ? 'Convex (converging)' : 'Concave (diverging)')
                            : (c ? 'Concave (converging)' : 'Convex (diverging)')}
                        </button>
                      ))}
                    </div>
                  </div>
                  <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
                  <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1"
                    note="Slide the object through 2F, F and inside F — watch the image flip" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'snell' && <>
                    <StatRow label="Angle of refraction θ₂" value={t2 === null ? 'TIR' : t2.toFixed(1)} unit={t2 === null ? '' : '°'} color="text-indigo-600" />
                    <StatRow label="Critical angle θc" value={critAng === null ? '—' : critAng.toFixed(1)} unit={critAng === null ? '' : '°'} color="text-emerald-600" />
                    <StatRow label="n₂/n₁ ratio" value={(n2 / n1).toFixed(3)} unit="" color="text-amber-600" />
                    <StatRow label="Bends" value={t2 === null ? 'reflects fully' : n2 > n1 ? 'towards normal' : 'away from normal'} unit="" color="text-rose-500" />
                  </>}
                  {mode !== 'snell' && <>
                    <StatRow label="Image distance v" value={img.atInfinity ? '∞' : Math.abs(img.v).toFixed(1)} unit={img.atInfinity ? '' : 'cm'} color="text-indigo-600" />
                    <StatRow label="Magnification m" value={img.atInfinity ? '∞' : img.m.toFixed(2)} unit="×" color="text-emerald-600" />
                    <StatRow label="Nature" value={img.atInfinity ? 'at infinity' : img.real ? 'real' : 'virtual'} unit="" color="text-amber-600" />
                    <StatRow label="Orientation" value={img.atInfinity ? '—' : img.inverted ? 'inverted' : 'upright'} unit="" color="text-rose-500" />
                    {mode === 'lens' && (
                      <StatRow label="Power" value={lensPower(f / 100).toFixed(2)} unit="D" color="text-purple-600" />
                    )}
                    {mode === 'mirror' && (
                      <StatRow label="Radius R = 2f" value={(2 * focal).toFixed(0)} unit="cm" color="text-purple-600" />
                    )}
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[mode].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[mode].map((ex, i) => (
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
AFEOF

echo "  → src/app/simulations/radioactive-decay/page.tsx"
cat > "src/app/simulations/radioactive-decay/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DecayCanvas, DecayGraph } from '@/components/simulation/DecayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { decayConstant, activity, remaining } from '@/lib/physics/decay';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'Decay is RANDOM for one nucleus but statistically predictable for many — the red measured dot scatters around the smooth blue theory curve, and the scatter shrinks as N₀ grows.',
  'After each half-life exactly half of what remains decays: N₀ → N₀/2 → N₀/4 → N₀/8 … the dashed gridlines mark 1T½, 2T½, 3T½.',
  'The decay constant λ = ln2/T½ is the probability per second that any one nucleus decays. Activity A = λN falls with the same half-life as N.',
  'Nothing changes the half-life — not temperature, pressure, or chemistry. It is a nuclear property.',
  'Carbon-14 dating: living things maintain constant C-14; after death it halves every 5730 years. Measuring the remaining fraction gives the age.',
];

const EXERCISES = [
  { q: 'A sample has half-life 8s and starts with 640 nuclei. How many remain after 24s?', a: '24s = 3 half-lives. 640 → 320 → 160 → 80 nuclei.' },
  { q: 'The activity of a source falls from 1200Bq to 150Bq in 36 minutes. Find the half-life.', a: '1200→600→300→150 is 3 halvings, so T½ = 36/3 = 12 minutes.' },
  { q: 'A sample of half-life 5730 years retains 25% of its C-14. How old is it?', a: '25% = (1/2)² → 2 half-lives → 2 × 5730 = 11460 years.' },
  { q: 'Find the decay constant of a nuclide with T½ = 10s, and the activity of 400 nuclei.', a: 'λ = ln2/10 = 0.0693 s⁻¹. A = λN = 0.0693 × 400 ≈ 27.7 decays/s.' },
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

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function RadioactiveDecayPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [n0, setN0] = useState(400);
  const [halfLife, setHalfLife] = useState(5);
  const [live, setLive] = useState({ t: 0, n: 400 });

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setLive({ t: 0, n: n0 });
  }, [n0]);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [n0, halfLife, reset]);

  // Throttle graph updates (same pattern as SHM) — canvas has its own rAF loop.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number, n: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setLive({ t, n });
    }
  }, []);

  const lam = decayConstant(halfLife);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Radioactive decay</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Random decay, predictable statistics</span>
            <span className="text-sm font-semibold font-mono text-gray-900">N = N₀ · 2^(−t/T½)</span>
            <span className="text-xs text-gray-400 ml-2">λ = ln2/T½ &nbsp;|&nbsp; A = λN</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DecayCanvas n0={n0} halfLife={halfLife} resetKey={resetKey}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick} width={640} height={300} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/decay"
                  title="Radioactive decay — A-Factor STEM Studio"
                  params={{ n0, hl: halfLife }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Decay curve N–t</p>
                <DecayGraph n0={n0} halfLife={halfLife} currentT={live.t} currentN={live.n} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Blue dot: theory N₀·2^(−t/T½) — Red dot: your random sample. They agree better with larger N₀.
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Initial nuclei N₀" unit="" value={n0} min={50} max={900} step={50} set={setN0} color="#6366f1"
                  note="Larger samples follow the theory curve more closely" />
                <Slider label="Half-life T½" unit="s" value={halfLife} min={1} max={20} step={0.5} set={setHalfLife} color="#f59e0b" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Decay constant λ" value={lam.toFixed(4)} unit="s⁻¹" color="text-indigo-600" />
                  <StatRow label="Initial activity" value={activity(n0, halfLife).toFixed(1)} unit="Bq" color="text-emerald-600" />
                  <StatRow label="N after 1 T½" value={(n0 / 2).toFixed(0)} unit="" color="text-amber-600" />
                  <StatRow label="N after 2 T½" value={(n0 / 4).toFixed(0)} unit="" color="text-rose-500" />
                  <StatRow label="N after 3 T½" value={(n0 / 8).toFixed(0)} unit="" color="text-purple-600" />
                  {live.t > 0 && (
                    <StatRow label={`Theory at t=${live.t.toFixed(1)}s`} value={remaining(n0, halfLife, live.t).toFixed(0)} unit="" color="text-gray-600" />
                  )}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

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
AFEOF

echo "  → src/app/embed/circuits/page.tsx"
cat > "src/app/embed/circuits/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { CircuitCanvas, CircuitMode } from '@/components/simulation/CircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function CircuitsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): CircuitMode => {
    const m = sp.get('mode');
    return m === 'series' || m === 'parallel' ? m : 'ohm';
  })();
  const showControls = sp.get('controls') !== '0';

  const [V, setV] = useState(() => num(sp, 'V', 12, 1, 24));
  const [r1, setR1] = useState(() => num(sp, 'r1', 4, 1, 50));
  const [r2, setR2] = useState(() => num(sp, 'r2', 6, 1, 50));
  const [r3, setR3] = useState(() => num(sp, 'r3', 12, 1, 50));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [V, r1, r2, r3, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Supply voltage" unit="V" value={V} min={1} max={24} step={0.5} set={setV} color="#6366f1" />
            <Slider label={mode === 'ohm' ? 'Resistance R' : 'R₁'} unit="Ω" value={r1} min={1} max={50} step={1} set={setR1} color="#f59e0b" />
            {mode !== 'ohm' && <>
              <Slider label="R₂" unit="Ω" value={r2} min={1} max={50} step={1} set={setR2} color="#10b981" />
              <Slider label="R₃" unit="Ω" value={r3} min={1} max={50} step={1} set={setR3} color="#8b5cf6" />
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function CircuitsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <CircuitsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/waves/page.tsx"
cat > "src/app/embed/waves/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { WaveCanvas, WaveMode } from '@/components/simulation/WaveCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function WavesEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): WaveMode => {
    const m = sp.get('mode');
    return m === 'longitudinal' || m === 'superposition' || m === 'standing' ? m : 'transverse';
  })();
  const showControls = sp.get('controls') !== '0';

  const [A, setA] = useState(() => num(sp, 'A', 1, 0.2, 1.5));
  const [f, setF] = useState(() => num(sp, 'f', 0.5, 0.1, 2));
  const [lambda, setLambda] = useState(() => num(sp, 'lambda', 2, 0.5, 4));
  const [A2, setA2] = useState(() => num(sp, 'A2', 0.7, 0.1, 1.5));
  const [f2, setF2] = useState(() => num(sp, 'f2', 0.5, 0.1, 2));
  const [phase2, setPhase2] = useState(() => num(sp, 'phase2', 0, 0, 360));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [A, f, lambda, A2, f2, phase2, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <WaveCanvas key={resetKey} mode={mode}
        amplitude={A} frequency={f} wavelength={lambda}
        amplitude2={A2} frequency2={f2} phase2={phase2}
        isRunning={isRunning} isPaused={isPaused} width={660} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Amplitude" unit="m" value={A} min={0.2} max={1.5} step={0.1} set={setA} color="#6366f1" />
            <Slider label="Frequency" unit="Hz" value={f} min={0.1} max={2} step={0.05} set={setF} color="#f59e0b" />
            <Slider label="Wavelength" unit="m" value={lambda} min={0.5} max={4} step={0.1} set={setLambda} color="#10b981" />
            {mode === 'superposition' && <>
              <Slider label="Amplitude A₂" unit="m" value={A2} min={0.1} max={1.5} step={0.1} set={setA2} color="#8b5cf6" />
              <Slider label="Frequency f₂" unit="Hz" value={f2} min={0.1} max={2} step={0.05} set={setF2} color="#ef4444" />
              <Slider label="Phase difference" unit="°" value={phase2} min={0} max={360} step={5} set={setPhase2} color="#0ea5e9" />
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function WavesEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <WavesEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/optics/page.tsx"
cat > "src/app/embed/optics/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function OpticsEmbedInner() {
  const sp = useSearchParams();
  const mode = ((): OpticsMode => {
    const m = sp.get('mode');
    return m === 'lens' || m === 'mirror' ? m : 'snell';
  })();
  const showControls = sp.get('controls') !== '0';

  const [n1, setN1] = useState(() => num(sp, 'n1', 1.0, 1, 2.5));
  const [n2, setN2] = useState(() => num(sp, 'n2', 1.5, 1, 2.5));
  const [theta1, setTheta1] = useState(() => num(sp, 'theta1', 35, 0, 89));
  const [focal, setFocal] = useState(() => num(sp, 'focal', 15, 5, 40));
  const [objectDist, setObjectDist] = useState(() => num(sp, 'u', 40, 5, 90));
  const [converging, setConverging] = useState(() => sp.get('conv') !== '0');

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
        focal={focal} objectDist={objectDist} converging={converging}
        width={660} height={320} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            {mode === 'snell' && <>
              <Slider label="Angle of incidence θ₁" unit="°" value={theta1} min={0} max={89} step={1} set={setTheta1} color="#6366f1" />
              <Slider label="n₁ (top)" unit="" value={n1} min={1} max={2.5} step={0.01} set={setN1} color="#f59e0b" />
              <Slider label="n₂ (bottom)" unit="" value={n2} min={1} max={2.5} step={0.01} set={setN2} color="#10b981" />
            </>}
            {mode !== 'snell' && <>
              <Slider label="Focal length |f|" unit="cm" value={focal} min={5} max={40} step={1} set={setFocal} color="#f59e0b" />
              <Slider label="Object distance u" unit="cm" value={objectDist} min={5} max={90} step={1} set={setObjectDist} color="#6366f1" />
              <div className="space-y-1">
                <span className="text-xs text-gray-500">Type</span>
                <div className="flex gap-2">
                  {([true, false] as const).map(c => (
                    <button key={String(c)} onClick={() => setConverging(c)}
                      className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                        converging === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                      }`}>
                      {c ? 'Converging' : 'Diverging'}
                    </button>
                  ))}
                </div>
              </div>
            </>}
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function OpticsEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <OpticsEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/embed/decay/page.tsx"
cat > "src/app/embed/decay/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { DecayCanvas, DecayGraph } from '@/components/simulation/DecayCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function DecayEmbedInner() {
  const sp = useSearchParams();
  const showControls = sp.get('controls') !== '0';
  const showGraph = sp.get('graph') !== '0';

  const [n0, setN0] = useState(() => num(sp, 'n0', 400, 50, 900));
  const [halfLife, setHalfLife] = useState(() => num(sp, 'hl', 5, 1, 20));
  const [live, setLive] = useState({ t: 0, n: 400 });

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setLive({ t: 0, n: n0 });
  }, [n0]);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [n0, halfLife, reset]);

  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number, n: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setLive({ t, n });
    }
  }, []);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <DecayCanvas n0={n0} halfLife={halfLife} resetKey={resetKey}
        isRunning={isRunning} isPaused={isPaused} onTick={handleTick}
        width={640} height={280} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showGraph && (
        <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
          <DecayGraph n0={n0} halfLife={halfLife} currentT={live.t} currentN={live.n} />
        </div>
      )}
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
          <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <div className="grid grid-cols-1 gap-x-6 gap-y-3 sm:grid-cols-2">
            <Slider label="Initial nuclei N₀" unit="" value={n0} min={50} max={900} step={50} set={setN0} color="#6366f1" />
            <Slider label="Half-life T½" unit="s" value={halfLife} min={1} max={20} step={0.5} set={setHalfLife} color="#f59e0b" />
          </div>
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function DecayEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <DecayEmbedInner />
    </Suspense>
  );
}
AFEOF

echo ""
echo "✓ Patch v3 applied — 18 files written."
echo ""
echo "New pages:  /simulations/ohms-law   /simulations/waves"
echo "            /simulations/refraction /simulations/radioactive-decay"
echo "New embeds: /embed/circuits /embed/waves /embed/optics /embed/decay"
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
