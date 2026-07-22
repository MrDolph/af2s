#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v12: mobile-friendly AI prompt bar + a more
# compact projectile-motion layout
#
#   1. PROMPT BAR MOBILE FIX. The input + "Generate" button were forced into
#      one fixed row with no mobile breakpoint, so on narrow screens the
#      button got squeezed and text could overflow/wrap awkwardly. Now
#      stacks vertically (full-width input, full-width button below it) on
#      narrow screens and sits in one row from the `sm` breakpoint up. Input
#      text is 16px on mobile (prevents iOS Safari's automatic zoom-on-
#      focus, a common mobile-web gotcha) while staying compact on desktop.
#      This fixes the prompt bar everywhere it's used: the homepage and the
#      projectile-motion page.
#
#   2. PROJECTILE-MOTION LAYOUT. Moved the "Parameters" (sliders) card out
#      of the main column — where it sat stacked full-width below the
#      canvas — into the sidebar column, right next to "Calculated". This
#      shortens the main column to just canvas + controls, so on wider
#      screens the whole page reads more like a single compact view instead
#      of a long stack, and puts the sliders directly beside the numbers
#      they affect. Mobile stacking order is unchanged (Parameters still
#      appears immediately after the controls).
#
#   3. HOMEPAGE: wired the same responsive-canvas hook used across the rest
#      of the app (previously fixed at 720×320) and widened the page
#      container to match every other page (max-w-7xl -> max-w-[100rem]).
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v12-mobile-prompt-and-layout.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v12: mobile prompt bar + compact projectile-motion layout ──"
mkdir -p "src/app" "src/app/simulations/projectile-motion" "src/components/ai"

echo "  → src/components/ai/PromptBar.tsx"
cat > "src/components/ai/PromptBar.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import type { AIPromptResponse } from '@/types/ai';

interface PromptBarProps { onResult: (r: AIPromptResponse) => void; className?: string; }

const EXAMPLE_PROMPTS = [
  'Show projectile motion at 45° and 30 m/s',
  "Demonstrate Newton's second law with 10 kg and 50 N",
  'Ṣe afihan projectile ti o bẹrẹ ni 20 m/s',
];

export function PromptBar({ onResult, className }: PromptBarProps) {
  const [prompt, setPrompt] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (text: string) => {
    if (!text.trim() || isLoading) return;
    setIsLoading(true); setError(null);
    try {
      const res = await fetch('/api/ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: text }),
      });
      if (!res.ok) { const d = await res.json(); throw new Error(d.error || 'Error'); }
      onResult(await res.json());
      setPrompt('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate simulation');
    } finally { setIsLoading(false); }
  };

  return (
    <div className={className}>
      {/* Stacks on narrow screens (full-width input, full-width button below
          it) and sits in one row from `sm` upward. text-base (16px) on the
          input prevents iOS Safari's automatic zoom-on-focus. */}
      <div className="flex flex-col gap-2 sm:flex-row">
        <input
          type="text" value={prompt}
          onChange={e => setPrompt(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleSubmit(prompt)}
          placeholder="Describe what you want to simulate…"
          disabled={isLoading}
          className="min-w-0 flex-1 rounded-lg border border-gray-200 bg-white px-4 py-3 text-base outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100 disabled:opacity-50 sm:text-sm"
        />
        <button
          onClick={() => handleSubmit(prompt)}
          disabled={!prompt.trim() || isLoading}
          className="w-full shrink-0 rounded-lg bg-indigo-600 px-5 py-3 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-40 sm:w-auto"
        >
          {isLoading ? 'Generating…' : 'Generate'}
        </button>
      </div>
      {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
      <div className="mt-3 flex flex-wrap gap-2">
        {EXAMPLE_PROMPTS.map(p => (
          <button key={p} onClick={() => handleSubmit(p)} disabled={isLoading}
            className="max-w-full truncate rounded-full border border-gray-200 bg-gray-50 px-3 py-1.5 text-xs text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700 disabled:opacity-40">
            {p}
          </button>
        ))}
      </div>
    </div>
  );
}
AFEOF

echo "  → src/app/page.tsx"
cat > "src/app/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef } from 'react';
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
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

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

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 720, 320, 900);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero prompt section */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-6 sm:py-8">
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-6 space-y-4">

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
              <div ref={canvasBoxRef}>
                <ProjectileCanvas
                  key={resetKey}
                  params={params}
                  isRunning={isRunning}
                  isPaused={isPaused}
                  onTick={handleTick}
                  onComplete={handleComplete}
                  width={canvasSize.width}
                  height={canvasSize.height}
                />
              </div>
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
              <p className="text-xs text-gray-400">Gas laws, Newton&apos;s laws, waves, circuits, and more.</p>
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
AFEOF

echo "  → src/app/simulations/projectile-motion/page.tsx"
cat > "src/app/simulations/projectile-motion/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileModeCanvas, ProjectileMode } from '@/components/simulation/ProjectileModeCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import type { AIPromptResponse } from '@/types/ai';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  standardAnalytics, horizontalAnalytics, verticalAnalytics, inclinedAnalytics,
  StandardParams, HorizontalParams, VerticalParams, InclinedParams,
} from '@/lib/physics/projectile-modes';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ProjectileMode, { title: string; icon: string; sub: string; eqs: string[] }> = {
  standard:   { title: 'Standard', icon: '🎯', sub: 'Angle θ, optional height h', eqs: ['R = vₓ × T', 'H = h + vy₀²/2g'] },
  horizontal: { title: 'Horizontal', icon: '🏗️', sub: 'Launched horizontally from height', eqs: ['t = √(2h/g)', 'R = v₀t'] },
  vertical:   { title: 'Vertical', icon: '⬆️', sub: 'Thrown up/down or dropped', eqs: ['H_max = h₀ + v₀²/2g', 't = v₀/g'] },
  inclined:   { title: 'Inclined', icon: '📐', sub: 'Launched along a slope β', eqs: ['t = 2v₀sinα/gcosβ'] },
};

const TEACHER_NOTES: Record<ProjectileMode, string[]> = {
  standard: [
    'vx is constant throughout — no horizontal force acts on the projectile.',
    'When h₀ > 0, the optimal angle for max range drops below 45°.',
    'Complementary angles give equal range only when launched from ground level.',
    'Platform height slider — drag it up to simulate a cliff or tall building.',
    'Use the gravity slider to explore projectile behaviour on the Moon (1.6 m/s²) or Mars (3.7 m/s²).',
  ],
  horizontal: [
    'Horizontal projection: initial vertical velocity is ZERO. Only horizontal speed is given at launch.',
    'Time of flight depends only on height — t = √(2h/g). Horizontal speed does not affect fall time.',
    'The landing velocity always has a downward component: v_land = √(v₀² + (gt)²).',
    'Classic exam scenario: stone thrown from a cliff, ball rolling off a table, bomb from a horizontal aircraft.',
    'The path curves — it starts horizontal and steepens continuously until landing.',
  ],
  vertical: [
    'Pure vertical motion — no horizontal displacement at all.',
    'At maximum height, vy = 0. Time to reach max = v₀/g.',
    'Symmetry: time rising = time falling (when returning to same height).',
    'Set v₀ = 0 and h₀ > 0 for free fall. Set v₀ negative for a downward throw.',
    'Landing speed: v = √(v₀² + 2gh₀) — same regardless of direction of initial throw from same height.',
  ],
  inclined: [
    'Key insight: resolve gravity into components along the slope (g sinβ) and perpendicular (g cosβ).',
    'The effective gravity perpendicular to slope is g cosβ — less than g, so flight time is longer than on flat ground.',
    'Optimal launch angle for max range along slope = 45° − β/2, not 45°.',
    'Range along slope ≠ horizontal range — understand which the exam question is asking for.',
    'This is one of the hardest WAEC/IGCSE topics: always set up axes along and perpendicular to the slope.',
    'Down-the-slope launch: same flight time t = 2v₀sinα/(g cosβ), but g sinβ now ACCELERATES the motion, so the range along the slope is longer than the same launch going up.',
  ],
};

const EXERCISES: Record<ProjectileMode, { q: string; a: string }[]> = {
  standard: [
    { q: 'A ball is thrown at 25 m/s at 37° from a 20m building. Find the range. (g = 10 m/s², sin37°=0.6, cos37°=0.8)', a: 'vx=20, vy₀=15. Solve 20+15t−5t²=0 → t≈3+, R=20×3.56=71.2m' },
    { q: 'Complementary angles 30° and 60° give the same range. Does this still hold when launched from a height?', a: 'No — when h₀ > 0 the symmetry breaks. The ball launched at the shallower angle has more horizontal time and travels farther.' },
    { q: 'Find the angle for max range when v₀=20 m/s from a 15m platform. (g=10 m/s²)', a: 'The optimal angle is less than 45° and requires calculus or numerical methods. Try angles around 38°–42° in the simulator.' },
  ],
  horizontal: [
    { q: 'A stone is thrown horizontally at 12 m/s from a 45m cliff. Find range and landing speed. (g=10 m/s²)', a: 't=√(2×45/10)=3s. R=12×3=36m. vy=gt=30m/s. v=√(144+900)=√1044≈32.3m/s' },
    { q: 'A ball rolls off a 1.25m table and lands 2m away. Find its speed at the table edge. (g=10 m/s²)', a: 't=√(2×1.25/10)=0.5s. v₀=R/t=2/0.5=4m/s' },
    { q: 'Why does doubling the horizontal speed double the range but not the time of flight?', a: 'Time depends only on height (t=√(2h/g)) which is unchanged. With double speed, the ball covers twice the horizontal distance in the same time.' },
  ],
  vertical: [
    { q: 'A ball is thrown upward at 30 m/s from the ground. Find max height and total flight time. (g=10 m/s²)', a: 'H=v²/2g=900/20=45m. t_up=30/10=3s. Total=6s.' },
    { q: 'A ball is dropped from 80m. Find speed at impact. (g=10 m/s²)', a: 'v=√(2gh)=√(2×10×80)=√1600=40 m/s' },
    { q: 'A ball thrown upward at 20 m/s from a 30m tower. Find max height above ground. (g=10 m/s²)', a: 'H_above_launch=v²/2g=400/20=20m. Max above ground=30+20=50m.' },
  ],
  inclined: [
    { q: 'v₀=20 m/s, α=30° above slope, β=30° slope. Find time of flight. (g=10 m/s²)', a: 't=2v₀sinα/(gcosβ)=2×20×0.5/(10×0.866)=20/8.66≈2.31s' },
    { q: 'At what α is range along slope maximised when β=30°?', a: 'Optimal α = 45° − β/2 = 45° − 15° = 30° above the slope surface.' },
    { q: 'Why is range along slope different from horizontal range?', a: 'The landing point is on the slope, higher than the foot of the incline. Slope range = distance along the surface; horizontal range = horizontal distance only.' },
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
        onChange={e => set(Number(e.target.value))}
        className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: number | string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-sm font-semibold tabular-nums ${color}`}>
        {typeof value === 'number' ? value.toFixed(2) : value}
        <span className="text-xs font-normal text-gray-400 ml-1">{unit}</span>
      </span>
    </div>
  );
}

export default function ProjectileMotionPage() {
  const [mode, setMode] = useState<ProjectileMode>('standard');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [livePos, setLivePos] = useState({ t: 0, x: 0, y: 0 });

  // Params
  const [v0, setV0] = useState(25); const [angle, setAngle] = useState(45);
  const [g, setG] = useState(9.81); const [h0, setH0] = useState(0);
  const [hV0, setHV0] = useState(20); const [hH, setHH] = useState(30);
  const [vV0, setVV0] = useState(15); const [vH0, setVH0] = useState(0);
  const [iV0, setIV0] = useState(20); const [iAlpha, setIAlpha] = useState(30); const [iBeta, setIBeta] = useState(30);
  const [iLaunchFrom, setILaunchFrom] = useState<'base' | 'top'>('base');

  // Memoized so these keep a stable object identity across renders that don't
  // actually change their values (e.g. the per-frame re-render from handleTick
  // updating livePos). Without this, ProjectileModeCanvas sees a "new" params
  // object on every animation frame and resets itself mid-flight.
  const std: StandardParams   = useMemo(() => ({ v0, angle, g, h0 }), [v0, angle, g, h0]);
  const hrz: HorizontalParams = useMemo(() => ({ v0: hV0, h: hH, g }), [hV0, hH, g]);
  const vtc: VerticalParams   = useMemo(() => ({ v0: vV0, h0: vH0, g }), [vV0, vH0, g]);
  const inc: InclinedParams   = useMemo(
    () => ({ v0: iV0, alpha: iAlpha, beta: iBeta, g, launchFrom: iLaunchFrom }),
    [iV0, iAlpha, iBeta, g, iLaunchFrom]
  );

  const stdA = standardAnalytics(std);
  const hrzA = horizontalAnalytics(hrz);
  const vtcA = verticalAnalytics(vtc);
  const incA = inclinedAnalytics(inc);

  // Debounced reset on param change
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setLivePos({ t: 0, x: 0, y: 0 });
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, v0, angle, g, h0, hV0, hH, vV0, vH0, iV0, iAlpha, iBeta, iLaunchFrom, reset]);

  const handleTick = useCallback((t: number, x: number, y: number) => setLivePos({ t, x, y }), []);
  const handleComplete = useCallback(() => { setIsComplete(true); setIsRunning(false); }, []);
  const handleAIResult = useCallback((r: AIPromptResponse) => {
    if (r.simulationType === 'projectile_motion') {
      const p = r.params as Record<string, number>;
      if (p.initialVelocity) setV0(p.initialVelocity);
      if (p.angle) setAngle(p.angle);
      if (p.gravity) setG(p.gravity);
      if (p.h0) setH0(p.h0);
      setMode('standard');
    }
    setTimeout(reset, 100);
  }, [reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 290, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Page header */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Projectile motion</h1>
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">

          {/* AI prompt */}
          <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
            <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">AI prompt</p>
            <PromptBar onResult={handleAIResult} />
          </div>

          {/* Mode tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ProjectileMode[]).map(m => (
              <button key={m} onClick={() => setMode(m)}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  mode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{MODE_META[m].icon}</span>
                <span>{MODE_META[m].title}</span>
              </button>
            ))}
          </div>

          {/* Sub + equations */}
          <div className="flex flex-wrap items-center gap-2">
            <span className="text-xs text-gray-500">{MODE_META[mode].sub}</span>
            {MODE_META[mode].eqs.map(eq => (
              <span key={eq} className="rounded-lg border border-gray-200 bg-white px-2.5 py-1 text-xs font-mono text-gray-700">{eq}</span>
            ))}
          </div>

          {/* ── MOBILE: stack everything; DESKTOP: 3-col ── */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Col 1: canvas + controls */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ProjectileModeCanvas
                  key={resetKey}
                  mode={mode}
                  standard={std} horizontal={hrz} vertical={vtc} inclined={inc}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick} onComplete={handleComplete}
                  width={canvasSize.width} height={canvasSize.height}
                />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                <div className="flex items-center gap-2">
                  {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
                  <EmbedButton
                    path="/embed/projectile"
                    title={`Projectile motion (${mode}) — A-Factor STEM Studio`}
                    params={
                      mode === 'standard'   ? { mode, v0, angle, g, h0 } :
                      mode === 'horizontal' ? { mode, v0: hV0, h: hH, g } :
                      mode === 'vertical'   ? { mode, v0: vV0, h0: vH0, g } :
                      { mode, v0: iV0, alpha: iAlpha, beta: iBeta, g, launch: iLaunchFrom }
                    }
                  />
                </div>
              </div>
            </div>

            {/* Col 2: parameters + analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Gravity" unit="m/s²" value={g} min={1} max={25} step={0.1} set={setG} color="#10b981" />

                {mode === 'standard' && <>
                  <Slider label="Initial velocity" unit="m/s" value={v0} min={1} max={100} step={1} set={setV0} color="#6366f1" />
                  <Slider label="Launch angle" unit="°" value={angle} min={1} max={89} step={1} set={setAngle} color="#f59e0b" />
                  <Slider label="Platform height" unit="m" value={h0} min={0} max={120} step={1} set={setH0} color="#8b5cf6" note="0 = ground level" />
                </>}

                {mode === 'horizontal' && <>
                  <Slider label="Horizontal speed" unit="m/s" value={hV0} min={1} max={100} step={1} set={setHV0} color="#6366f1" />
                  <Slider label="Launch height" unit="m" value={hH} min={1} max={200} step={1} set={setHH} color="#8b5cf6" />
                </>}

                {mode === 'vertical' && <>
                  <Slider label="Initial velocity (↑ positive)" unit="m/s" value={vV0} min={-30} max={50} step={1} set={setVV0} color="#6366f1" note="Negative = thrown downward" />
                  <Slider label="Initial height" unit="m" value={vH0} min={0} max={200} step={1} set={setVH0} color="#8b5cf6" />
                </>}

                {mode === 'inclined' && <>
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">Launched from</span>
                    <div className="flex gap-2">
                      {(['base', 'top'] as const).map(v => (
                        <button key={v} onClick={() => setILaunchFrom(v)}
                          className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium transition ${
                            iLaunchFrom === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>
                          {v === 'base' ? 'Base — up the slope' : 'Top — down the slope'}
                        </button>
                      ))}
                    </div>
                    <p className="text-[10px] text-gray-400">
                      {iLaunchFrom === 'base'
                        ? 'Launched up the slope at α above the surface — lands back on the incline. Gravity component g sinβ decelerates it along the slope.'
                        : 'Launched down the slope at α above the surface — lands at the base of the incline. Gravity component g sinβ accelerates it along the slope, so it travels farther than the same launch going up.'}
                    </p>
                  </div>
                  <Slider label="Initial velocity" unit="m/s" value={iV0} min={1} max={60} step={1} set={setIV0} color="#6366f1" />
                  <Slider label="α — angle above slope" unit="°" value={iAlpha} min={1} max={89} step={1} set={setIAlpha} color="#f59e0b" />
                  <Slider label="β — slope angle" unit="°" value={iBeta} min={5} max={60} step={1} set={setIBeta} color="#ef4444" />
                </>}
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'standard' && <>
                    <StatRow label="Time of flight" value={stdA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Max range" value={stdA.range} unit="m" color="text-emerald-600" />
                    <StatRow label="Max height" value={stdA.maxHeight} unit="m" color="text-amber-600" />
                    <StatRow label="vx" value={stdA.vx} unit="m/s" color="text-gray-600" />
                    <StatRow label="vy₀" value={stdA.vy0} unit="m/s" color="text-rose-500" />
                  </>}
                  {mode === 'horizontal' && <>
                    <StatRow label="Time of flight" value={hrzA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range" value={hrzA.range} unit="m" color="text-emerald-600" />
                    <StatRow label="Landing speed" value={hrzA.vLand} unit="m/s" color="text-amber-600" />
                    <StatRow label="Landing angle" value={hrzA.angleLand} unit="°↓" color="text-rose-500" />
                  </>}
                  {mode === 'vertical' && <>
                    <StatRow label="Max height" value={vtcA.maxHeight} unit="m" color="text-indigo-600" />
                    <StatRow label="Time to peak" value={vtcA.timeToMax} unit="s" color="text-amber-600" />
                    <StatRow label="Flight time" value={vtcA.tFlight} unit="s" color="text-emerald-600" />
                    <StatRow label="Landing speed" value={vtcA.vLand} unit="m/s" color="text-rose-500" />
                  </>}
                  {mode === 'inclined' && <>
                    <StatRow label="Flight time" value={incA.tFlight} unit="s" color="text-indigo-600" />
                    <StatRow label="Range along slope" value={incA.rangeAlongIncline} unit="m" color="text-emerald-600" />
                    <StatRow label="Horizontal range" value={incA.rangeHorizontal} unit="m" color="text-amber-600" />
                    <StatRow label="Max height ⊥ slope" value={incA.maxHeightAboveIncline} unit="m" color="text-rose-500" />
                    <StatRow
                      label={iLaunchFrom === 'top' ? 'Vertical drop' : 'Vertical rise'}
                      value={incA.verticalDrop} unit="m" color="text-purple-600" />
                  </>}
                </div>
              </div>

              {livePos.t > 0 && (
                <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                  <p className="text-xs font-medium text-indigo-400 uppercase tracking-wide mb-2">Live</p>
                  <div className="space-y-1.5">
                    {[
                      { l: 't', v: livePos.t.toFixed(2), u: 's' },
                      ...(mode !== 'vertical' ? [{ l: 'x', v: livePos.x.toFixed(1), u: 'm' }] : []),
                      { l: 'y', v: livePos.y.toFixed(1), u: 'm' },
                    ].map(r => (
                      <div key={r.l} className="flex justify-between rounded-lg bg-white/70 px-3 py-1.5">
                        <span className="text-xs text-indigo-400 font-mono">{r.l}</span>
                        <span className="text-xs font-semibold text-indigo-700 tabular-nums">{r.v} <span className="font-normal text-indigo-300">{r.u}</span></span>
                      </div>
                    ))}
                  </div>
                </div>
              )}

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

            {/* Col 3: teacher notes + exercises — full width on mobile, col on xl */}
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
                        <span><span className="font-medium text-indigo-600">Q{i+1}.</span> {ex.q}</span>
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

echo ""
echo "✓ Patch v12 applied — 3 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check on a narrow (mobile-width) browser window: the AI prompt bar"
echo "should stack input above a full-width Generate button, and the"
echo "projectile-motion page's Parameters panel should now sit beside"
echo "Calculated in the sidebar on wider screens."
