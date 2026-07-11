#!/bin/bash
# A-Factor STEM Studio — Mobile responsive + /simulations hub
# Run inside af2s/ folder: bash mobile-responsive-patch.sh
set -e
echo "Building mobile responsive pages + simulations hub..."

mkdir -p src/app/simulations
mkdir -p src/components/layout
mkdir -p src/components/ui

# ── 1. Shared layout components ───────────────────────────────────────────────

cat > src/components/layout/AppHeader.tsx << 'EOF'
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
EOF

# ── 2. /simulations hub page ──────────────────────────────────────────────────
cat > src/app/simulations/page.tsx << 'EOF'
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/',
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
    href: '/simulations/newtons-second-law',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'coming',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/shm',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'coming',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'coming',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'coming',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'coming',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'coming',
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
EOF

# ── 3. Updated root layout with viewport meta ─────────────────────────────────
cat > src/app/layout.tsx << 'EOF'
import type { Metadata, Viewport } from 'next';
import { Geist, Geist_Mono } from 'next/font/google';
import './globals.css';

const geistSans = Geist({ variable: '--font-geist-sans', subsets: ['latin'] });
const geistMono = Geist_Mono({ variable: '--font-geist-mono', subsets: ['latin'] });

export const metadata: Metadata = {
  title: 'A-Factor STEM Studio — Physics simulations for every curriculum',
  description: 'AI-powered interactive physics simulations for WAEC, NECO, IGCSE, SAT and JUPEB students. Type a prompt, get an instant simulation.',
  keywords: ['physics simulation', 'WAEC', 'IGCSE', 'NECO', 'SAT', 'JUPEB', 'STEM education', 'Africa'],
};

export const viewport: Viewport = {
  width: 'device-width',
  initialScale: 1,
  maximumScale: 5,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${geistSans.variable} ${geistMono.variable} antialiased`}>
      <body className="min-h-screen bg-gray-50">{children}</body>
    </html>
  );
}
EOF

# ── 4. Updated home page — mobile responsive ──────────────────────────────────
cat > src/app/page.tsx << 'EOF'
'use client';
import { useState, useCallback } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileCanvas } from '@/components/simulation/ProjectileCanvas';
import { SimulationStats } from '@/components/simulation/SimulationStats';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ParamControls } from '@/components/simulation/ParamControls';
import type { AIPromptResponse } from '@/types/ai';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

const DEFAULT_PARAMS: ProjectileParams = { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 };

export default function HomePage() {
  const [params, setParams] = useState<ProjectileParams>(DEFAULT_PARAMS);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [liveState, setLiveState] = useState<ProjectileState | null>(null);
  const [isComplete, setIsComplete] = useState(false);
  const [lastResponse, setLastResponse] = useState<AIPromptResponse | null>(null);
  const [resetKey, setResetKey] = useState(0);

  const handleAIResult = useCallback((response: AIPromptResponse) => {
    setLastResponse(response);
    if (response.simulationType === 'projectile_motion') {
      const p = response.params as ProjectileParams;
      setParams({
        initialVelocity: Number(p.initialVelocity) || 20,
        angle: Number(p.angle) || 45,
        gravity: Number(p.gravity) || 9.81,
        mass: Number(p.mass) || 1,
      });
    }
    setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  }, []);

  const handleRun = () => { setIsRunning(true); setIsPaused(false); setIsComplete(false); };
  const handlePause = () => setIsPaused(p => !p);
  const handleReset = () => {
    setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  };
  const handleParamChange = (next: ProjectileParams) => {
    setParams(next); setIsRunning(false); setIsPaused(false);
    setLiveState(null); setIsComplete(false);
    setResetKey(k => k + 1);
  };
  const handleTick = useCallback((s: ProjectileState) => setLiveState(s), []);
  const handleComplete = useCallback((_: GraphDataPoint[]) => { setIsComplete(true); }, []);
  const currentSpeed = liveState ? Math.sqrt(liveState.vx ** 2 + liveState.vy ** 2) : undefined;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero prompt section */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-6 sm:py-8">
            <div className="mb-1 flex items-center gap-2">
              <span className="rounded-full bg-indigo-50 px-3 py-0.5 text-xs font-medium text-indigo-600">
                Phase 1 · Projectile motion
              </span>
              <Link href="/simulations" className="text-xs text-gray-400 hover:text-indigo-600 transition">
                All simulations →
              </Link>
            </div>
            <h2 className="text-base sm:text-lg font-semibold text-gray-900 mb-1">
              Describe your simulation
            </h2>
            <p className="text-xs text-gray-400 mb-4">
              Type in English, Yoruba, Hausa, or Igbo — AI generates parameters instantly.
            </p>
            <PromptBar onResult={handleAIResult} />
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-6 space-y-4">

          {/* AI explanation */}
          {lastResponse && (
            <div className="rounded-2xl border border-indigo-100 bg-indigo-50 px-4 sm:px-6 py-4">
              <p className="text-xs font-medium text-indigo-400 mb-1 uppercase tracking-wide">
                {lastResponse.title}
              </p>
              <p className="text-xs sm:text-sm text-indigo-800 leading-relaxed">
                {lastResponse.explanation}
              </p>
              {lastResponse.suggestedFollowUps?.length > 0 && (
                <div className="mt-3 flex flex-wrap gap-2">
                  {lastResponse.suggestedFollowUps.map(q => (
                    <span key={q} className="rounded-full border border-indigo-200 bg-white px-2.5 py-1 text-xs text-indigo-600">
                      {q}
                    </span>
                  ))}
                </div>
              )}
            </div>
          )}

          {/* Main simulation area — stack on mobile, side by side on desktop */}
          <div className="flex flex-col lg:grid lg:grid-cols-[1fr_260px] gap-4">

            {/* Canvas + controls */}
            <div className="space-y-3 min-w-0">
              <ProjectileCanvas
                key={resetKey}
                params={params}
                isRunning={isRunning}
                isPaused={isPaused}
                onTick={handleTick}
                onComplete={handleComplete}
                width={720}
                height={320}
              />
              <div className="flex flex-wrap items-center gap-3 justify-between">
                <SimulationControls
                  isRunning={isRunning && !isComplete}
                  isPaused={isPaused}
                  onRun={handleRun}
                  onPause={handlePause}
                  onReset={handleReset}
                />
                {isComplete && (
                  <span className="text-xs font-medium text-emerald-600">
                    ✓ Complete — press Reset to go again
                  </span>
                )}
              </div>
              <SimulationStats
                params={params}
                elapsedTime={liveState?.time}
                currentHeight={liveState ? Math.max(0, liveState.y) : undefined}
                currentSpeed={currentSpeed}
              />
            </div>

            {/* Param controls — below canvas on mobile */}
            <div>
              <ParamControls
                params={params}
                onChange={handleParamChange}
                disabled={isRunning && !isComplete}
              />
            </div>
          </div>

          {/* Link to all simulations */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 sm:p-5 flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
            <div>
              <p className="text-sm font-medium text-gray-900 mb-0.5">More simulations</p>
              <p className="text-xs text-gray-400">Gas laws, Newton's 2nd law, waves, circuits and more coming.</p>
            </div>
            <Link href="/simulations"
              className="shrink-0 rounded-xl bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-indigo-700 transition">
              Browse all →
            </Link>
          </div>
        </div>
      </main>
    </>
  );
}
EOF

# ── 5. Updated Gas Laws page — mobile responsive ──────────────────────────────
cat > src/app/simulations/gas-laws/page.tsx << 'EOF'
'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import { idealGasPressure, charlesNewVolume } from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = {
  boyle: [
    "Boyle's Law: at constant temperature, P₁V₁ = P₂V₂. Pressure and volume are inversely proportional.",
    "The P-V graph is a hyperbola — halving the volume doubles the pressure.",
    "Real gases deviate at very high pressures or low temperatures.",
    "Ask students: what happens to particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law: at constant pressure, V₁/T₁ = V₂/T₂. Volume is proportional to absolute temperature.",
    "Temperature MUST be in Kelvin — the law breaks down with Celsius.",
    "The V-T graph is a straight line. Extended to 0 K it passes through absolute zero.",
    "Ask students: why do hot air balloons rise? Why do car tyres overinflate in summer?",
  ],
};

const EXERCISES = {
  boyle: [
    { q: "A gas occupies 4 L at 200 kPa. What is its volume at 400 kPa? (constant T)", a: "2 L — P₁V₁ = P₂V₂ → (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa has volume 8 L. Find the pressure when V = 2 L.", a: "400 kPa — (100×8)/2 = 400 kPa" },
    { q: "Why does a sealed syringe become harder to push as you compress the gas?", a: "Reducing volume increases pressure — more particle collisions per unit area." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. What volume at 600 K? (constant P)", a: "6 L — V₁/T₁ = V₂/T₂ → (3×600)/300 = 6 L" },
    { q: "A balloon has volume 2 L at 27°C. Find its volume at 127°C.", a: "T₁=300K, T₂=400K → V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin when using Charles' Law?", a: "Kelvin starts at absolute zero — the true zero of molecular motion. Celsius gives wrong ratios." },
  ],
};

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);
  const [temperature, setTemperature] = useState(300);
  const [pressure, setPressure] = useState(200);
  const moles = 0.1;
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE']);

  const derivedPressure = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedVolume = charlesNewVolume(3, 300, temperature);

  const toggleC = (c: string) =>
    setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c]);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        {/* Header */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Thermal physics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Gas laws</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c} onClick={() => toggleC(c)}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c)
                        ? CURRICULUM_COLORS[c] + ' border-transparent'
                        : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-7xl px-4 sm:px-6 py-5 space-y-4">

          {/* Law tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-full sm:w-fit">
            {(['boyle', 'charles'] as Law[]).map(l => (
              <button key={l} onClick={() => setLaw(l)}
                className={`flex-1 sm:flex-none px-4 sm:px-5 py-2 rounded-lg text-xs sm:text-sm font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {l === 'boyle' ? "Boyle's Law" : "Charles' Law"}
              </button>
            ))}
          </div>

          {/* Key equation pill */}
          <div className="inline-flex items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Key equation</span>
            <span className="text-sm font-semibold text-gray-900">
              {law === 'boyle' ? 'P₁V₁ = P₂V₂' : 'V₁/T₁ = V₂/T₂'}
            </span>
            <span className="text-xs text-gray-400">
              {law === 'boyle' ? 'constant T' : 'constant P, T in Kelvin'}
            </span>
          </div>

          {/* Main 3-col layout — stacks on mobile */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">

            {/* Canvas + sliders */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                  {law === 'boyle' ? 'Compression (constant T)' : 'Expansion (constant P)'}
                </p>
                {law === 'boyle'
                  ? <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={280} height={260} />
                  : <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={280} height={260} />
                }
              </div>

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Adjust</p>

                {law === 'boyle' ? (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Volume</span>
                        <span className="font-medium tabular-nums">{volume.toFixed(1)} L</span>
                      </div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume}
                        onChange={e => setVolume(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Temperature (constant)</span>
                        <span className="font-medium tabular-nums">{temperature} K</span>
                      </div>
                      <input type="range" min="200" max="600" step="10" value={temperature}
                        onChange={e => setTemperature(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="rounded-xl bg-indigo-50 px-3 py-2.5 text-sm">
                      <span className="font-medium text-indigo-700">P = {derivedPressure.toFixed(1)} kPa</span>
                      <span className="text-indigo-400 text-xs ml-2">↑ as V decreases</span>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Temperature</span>
                        <span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span>
                      </div>
                      <input type="range" min="100" max="600" step="10" value={temperature}
                        onChange={e => setTemperature(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs">
                        <span className="text-gray-500">Pressure (constant)</span>
                        <span className="font-medium tabular-nums">{pressure} kPa</span>
                      </div>
                      <input type="range" min="50" max="500" step="10" value={pressure}
                        onChange={e => setPressure(Number(e.target.value))}
                        className="w-full" style={{ accentColor: '#10b981' }} />
                    </div>
                    <div className="rounded-xl bg-emerald-50 px-3 py-2.5 text-sm">
                      <span className="font-medium text-emerald-700">V = {derivedVolume.toFixed(2)} L</span>
                      <span className="text-emerald-400 text-xs ml-2">↑ as T increases</span>
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Graph */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">
                {law === 'boyle' ? 'P–V graph' : 'V–T graph'}
              </p>
              <p className="text-xs text-gray-400 mb-4">
                {law === 'boyle'
                  ? 'Hyperbolic curve at constant T. Yellow dot = current state.'
                  : 'Straight line through 0 K. Yellow dot = current state.'}
              </p>
              <GasLawGraph law={law} currentV={volume} currentP={derivedPressure} currentT={temperature} moles={moles} />

              {/* Real world */}
              <div className="mt-4 rounded-xl border border-indigo-100 bg-indigo-50 p-3">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                {law === 'boyle' ? (
                  <ul className="space-y-1 text-xs text-indigo-800">
                    <li>🤿 Scuba diving — gas expands as diver ascends</li>
                    <li>🩺 Breathing — lungs expand to reduce pressure</li>
                    <li>💉 Syringes — pulling back creates low pressure</li>
                  </ul>
                ) : (
                  <ul className="space-y-1 text-xs text-indigo-800">
                    <li>🎈 Hot air balloons — heat expands gas, reduces density</li>
                    <li>🚗 Car tyres — overinflate in summer heat</li>
                    <li>🍞 Bread rising — CO₂ expands in the oven</li>
                  </ul>
                )}
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 md:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-2">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[law].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-base leading-none">{openEx === i ? '▲' : '▼'}</span>
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

              {/* Curriculum tags */}
              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
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
EOF

# ── 6. Global CSS — add scrollbar-hide utility ────────────────────────────────
cat >> src/app/globals.css << 'EOF'

/* Hide scrollbar for topic filter row on mobile */
.scrollbar-hide::-webkit-scrollbar { display: none; }
.scrollbar-hide { -ms-overflow-style: none; scrollbar-width: none; }

/* Smooth tap targets on mobile */
button, a { -webkit-tap-highlight-color: transparent; }

/* Prevent canvas overflow on small screens */
canvas { max-width: 100%; }
EOF

echo ""
echo "✅ Mobile responsive patch complete!"
echo ""
echo "Pages updated:"
echo "  /                     — home page (mobile responsive)"
echo "  /simulations          — simulations hub (new)"
echo "  /simulations/gas-laws — gas laws (mobile responsive)"
echo ""
echo "Run: npm run dev -- --webpack"
