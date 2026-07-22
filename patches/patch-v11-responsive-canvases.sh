#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v11: bigger, responsive simulation canvases
#
#   Every simulation canvas now fills its actual available width (up to a
#   sensible cap), instead of sitting at a small fixed pixel size inside a
#   much bigger container. This required NO changes to any of the 26 canvas
#   COMPONENT files — every one of them already reads its size straight from
#   its width/height props (or from the live <canvas> element's own
#   attributes, which React keeps in sync with those props), so passing a
#   dynamically-computed size is enough for the whole animation to scale up.
#
#   New shared hook: useResponsiveCanvasSize(containerRef, baseWidth,
#   baseHeight, maxWidth). It measures a wrapping <div> via ResizeObserver
#   and returns a {width, height} pair that fills the container (capped at
#   maxWidth) while preserving the base aspect ratio. The hook takes an
#   EXTERNALLY-created ref (rather than returning one bundled in an object)
#   — this was a deliberate fix after the first version tripped a stricter
#   ref-analysis lint rule; passing a ref you created yourself is the
#   unambiguous, standard pattern.
#
#   Also widened the outer page container on every simulation page from
#   max-w-7xl (1280px) to max-w-[100rem] (1600px), so there's real room for
#   the canvas to grow on wide screens.
#
#   Wired into all 15 simulation pages:
#     friction, waves, refraction, ohms-law, radioactive-decay,
#     photoelectric-effect, de-broglie, x-rays, heat-transfer, elasticity,
#     projectile-motion, newtons-laws, oscillations, gas-laws,
#     consequences-of-motion
#   Multi-canvas pages (newtons-laws, oscillations, gas-laws,
#   consequences-of-motion) pick the right base aspect ratio per active
#   tab/topic before scaling — e.g. oscillations' spring demo stays
#   portrait-ish while pendulum/conical/physical stay landscape.
#
#   Scope note: embed routes (src/app/embed/*) were left untouched — they
#   render in a deliberately compact iframe-sized box, a different context
#   from the main site.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v11-responsive-canvases.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v11: bigger, responsive simulation canvases ──"
mkdir -p "src/app/simulations/consequences-of-motion" "src/app/simulations/de-broglie" "src/app/simulations/elasticity" "src/app/simulations/friction" "src/app/simulations/gas-laws" "src/app/simulations/heat-transfer" "src/app/simulations/newtons-laws" "src/app/simulations/ohms-law" "src/app/simulations/oscillations" "src/app/simulations/photoelectric-effect" "src/app/simulations/projectile-motion" "src/app/simulations/radioactive-decay" "src/app/simulations/refraction" "src/app/simulations/waves" "src/app/simulations/x-rays" "src/hooks"

echo "  → src/hooks/useResponsiveCanvasSize.ts"
cat > "src/hooks/useResponsiveCanvasSize.ts" << 'AFEOF'
'use client';
import { useEffect, useState, type RefObject } from 'react';

/**
 * Measures the width of a wrapping container (via an externally-created ref)
 * and returns a canvas size that fills it (up to maxWidth), preserving the
 * aspect ratio of baseWidth:baseHeight.
 *
 * Usage:
 *   const boxRef = useRef<HTMLDivElement>(null);
 *   const { width, height } = useResponsiveCanvasSize(boxRef, 640, 300, 980);
 *   <div ref={boxRef}><MyCanvas width={width} height={height} /></div>
 *
 * Every simulation canvas in this app reads its size either straight from
 * its `width`/`height` props or from the live <canvas> element's own
 * width/height attributes (which React keeps in sync with those same
 * props) — so simply passing a dynamically-computed width/height here is
 * enough to make the whole animation scale up, with no changes needed
 * inside the canvas components themselves.
 */
export function useResponsiveCanvasSize(
  containerRef: RefObject<HTMLElement | null>,
  baseWidth: number,
  baseHeight: number,
  maxWidth = 980,
) {
  const aspect = baseWidth / baseHeight;
  const [size, setSize] = useState({ width: baseWidth, height: baseHeight });

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;

    const update = () => {
      const available = el.clientWidth;
      if (!available) return;
      const w = Math.round(Math.min(available, maxWidth));
      const h = Math.round(w / aspect);
      setSize(prev => (prev.width === w && prev.height === h ? prev : { width: w, height: h }));
    };

    update();
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [aspect, maxWidth]);

  return size;
}
AFEOF

echo "  → src/app/simulations/friction/page.tsx"
cat > "src/app/simulations/friction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { FrictionCanvas, FrictionMode } from '@/components/simulation/FrictionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { flatFriction, inclineDynamics, frictionCurve } from '@/lib/physics/friction';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<FrictionMode, { title: string; icon: string; sub: string; eq: string }> = {
  flat:    { title: 'Flat surface', icon: '➡️', sub: 'Push a block along the ground', eq: 'f ≤ μsN,  f = μkN once sliding' },
  incline: { title: 'Inclined plane', icon: '⛰️', sub: 'A block on a slope',           eq: 'tanθr = μs' },
};

const TEACHER_NOTES: Record<FrictionMode, string[]> = {
  flat: [
    'Static friction is NOT fixed — it exactly matches the applied force, up to a maximum of μsN. Push harder within that limit and friction grows to match; nothing moves.',
    'Once the applied force exceeds μsN, the block breaks free and KINETIC friction takes over — μk is always a little LESS than μs, which is why things "jerk" into motion.',
    'Friction is independent of the contact area and (to a good approximation) of speed — but always proportional to the normal reaction N.',
    'N = mg only holds here because the surface is flat and the push is horizontal — on a slope, or with an angled push, N changes.',
    'Real applications: brake pads (want HIGH μ), ice skates and ball bearings (want LOW μ), why worn tyres skid more easily.',
  ],
  incline: [
    'The angle at which a block JUST starts to slide is the angle of repose θr, where tanθr = μs — a clean way to measure friction experimentally.',
    'On the slope, the FULL weight mg acts straight down — resolve it into two components relative to the incline: mg sinθ (down the slope, drives sliding) and mg cosθ (into the slope, balanced by the normal reaction N).',
    'Below θr the block is static and friction exactly balances mg sinθ. Above it, friction is capped at μkN and the block slides down: a = g(sinθ − μk cosθ).',
    'Pushing a block UP the slope needs the applied force to overcome BOTH mg sinθ and friction — and once moving, friction switches to act DOWN the slope, opposing the upward push, so more force is needed to keep it moving up than to just hold it in place.',
    'This is literally how a plumb-line/tilt-table experiment measures μs for sand, wood, or rubber in a school lab.',
    'A steeper slope always needs a HIGHER μ to prevent sliding — this is why steep roofs need rougher tiles.',
  ],
};

const EXERCISES: Record<FrictionMode, { q: string; a: string }[]> = {
  flat: [
    { q: 'A 10kg block has μs=0.4. What is the maximum static friction force before it starts to slide?', a: 'N=mg=10×9.81=98.1N. F_s,max=μsN=0.4×98.1=39.2N.' },
    { q: 'A 5kg box needs 20N to start moving and 15N to keep it moving at constant velocity. Find μs and μk.', a: 'N=5×9.81=49.05N. μs=20/49.05=0.41. μk=15/49.05=0.31.' },
    { q: 'A 2kg block slides with μk=0.25 under a 15N push. Find its acceleration.', a: 'f=μkN=0.25×2×9.81=4.9N. Net=15−4.9=10.1N. a=10.1/2=5.05 m/s².' },
  ],
  incline: [
    { q: 'A block just begins to slide on a slope at 22°. Find μs.', a: 'μs = tan22° ≈ 0.40.' },
    { q: 'A 4kg block sits on a 35° slope with μs=0.5. Does it slide? Show your working.', a: 'mg sinθ = 4×9.81×sin35° ≈ 22.5N. μs·mg cosθ = 0.5×4×9.81×cos35° ≈ 16.1N. Since 22.5N > 16.1N, YES it slides.' },
    { q: 'A block slides down a 40° slope with μk=0.2. Find its acceleration.', a: 'a = g(sinθ − μk cosθ) = 9.81(sin40° − 0.2cos40°) ≈ 9.81(0.643−0.153) ≈ 4.81 m/s².' },
    { q: 'A 5kg block on a 30° slope (μs=0.4, μk=0.3) is pushed with a 60N force up the slope. Find the acceleration.', a: 'mg sinθ=5×9.81×sin30°=24.5N. N=5×9.81×cos30°=42.5N. Kinetic friction=0.3×42.5=12.7N (acts down-slope, opposing the push). Net=60−24.5−12.7=22.8N. a=22.8/5≈4.56 m/s² up the slope.' },
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

function ToggleChip({ label, active, onClick, color }: { label: string; active: boolean; onClick: () => void; color: string }) {
  return (
    <button onClick={onClick}
      className={`flex items-center gap-1.5 rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
        active ? 'border-transparent text-white' : 'border-gray-200 bg-white text-gray-400'
      }`}
      style={active ? { backgroundColor: color } : undefined}>
      <span className={`inline-block h-1.5 w-1.5 rounded-full ${active ? 'bg-white' : 'bg-gray-300'}`} />
      {label}
    </button>
  );
}

function FrictionGraph({ mass, muS, muK, applied }: { mass: number; muS: number; muK: number; applied: number }) {
  const fMax = mass * 9.81 * muS * 2.2;
  const data = useMemo(() => frictionCurve(mass, muS, muK, fMax), [mass, muS, muK, fMax]);
  const r = flatFriction(mass, applied, muS, muK);
  const staticLimit = muS * mass * 9.81;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="F" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Applied force F (N)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Friction f (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'f']} labelFormatter={f => `F=${Number(f).toFixed(1)}N`} />
        <Line type="linear" dataKey="f" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={staticLimit} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'μsN', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(applied, fMax)} y={r.friction} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function FrictionPage() {
  const [mode, setMode] = useState<FrictionMode>('flat');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [mass, setMass] = useState(5);
  const [applied, setApplied] = useState(25);
  const [angle, setAngle] = useState(35);
  const [appliedIncline, setAppliedIncline] = useState(0); // 0 = gravity only (slides down if steep enough)
  const [muS, setMuS] = useState(0.4);
  const [muK, setMuK] = useState(0.3);

  // Force-arrow visibility — purely cosmetic, shared across both modes so a
  // preference carries over when switching tabs.
  const [showWeight, setShowWeight] = useState(true);
  const [showComponents, setShowComponents] = useState(true);
  const [showNormal, setShowNormal] = useState(true);
  const [showFriction, setShowFriction] = useState(true);
  const [showApplied, setShowApplied] = useState(true);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, mass, applied, angle, appliedIncline, muS, muK, reset]);

  const flat = flatFriction(mass, applied, muS, muK);
  const inc = inclineDynamics(mass, angle, muS, muK, appliedIncline, 0);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Friction</h1>
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
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as FrictionMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <FrictionCanvas key={resetKey} mode={mode} mass={mass} applied={applied} angle={angle}
                  appliedIncline={appliedIncline} muS={muS} muK={muK} isRunning={isRunning} isPaused={isPaused} resetKey={resetKey}
                  showWeight={showWeight} showComponents={showComponents} showNormal={showNormal}
                  showFriction={showFriction} showApplied={showApplied}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/friction"
                  title={`${MODE_META[mode].title} friction — A-Factor STEM Studio`}
                  params={{ mode, mass, applied, angle, appliedIncline, muS, muK }} />
              </div>

              {mode === 'flat' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Friction vs applied force</p>
                  <FrictionGraph mass={mass} muS={muS} muK={muK} applied={applied} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Friction RISES to match F (static), then plateaus at μkN once sliding
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Show forces</p>
                <div className="flex flex-wrap gap-1.5">
                  <ToggleChip label="Weight (mg)" active={showWeight} onClick={() => setShowWeight(v => !v)} color="#8b5cf6" />
                  {mode === 'incline' && (
                    <ToggleChip label="Components (∥ & ⊥)" active={showComponents} onClick={() => setShowComponents(v => !v)} color="#a855f7" />
                  )}
                  <ToggleChip label="Normal (N)" active={showNormal} onClick={() => setShowNormal(v => !v)} color="#3b82f6" />
                  <ToggleChip label="Friction (f)" active={showFriction} onClick={() => setShowFriction(v => !v)} color="#ef4444" />
                  <ToggleChip label="Applied (F)" active={showApplied} onClick={() => setShowApplied(v => !v)} color="#059669" />
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Mass" unit="kg" value={mass} min={1} max={20} step={0.5} set={setMass} color="#6366f1" />
                {mode === 'flat' && (
                  <Slider label="Applied force" unit="N" value={applied} min={0} max={80} step={1} set={setApplied} color="#f59e0b" />
                )}
                {mode === 'incline' && (
                  <>
                    <Slider label="Incline angle" unit="°" value={angle} min={0} max={60} step={1} set={setAngle} color="#f59e0b" />
                    <Slider label="Applied push (up-slope)" unit="N" value={appliedIncline} min={0} max={100} step={1} set={setAppliedIncline} color="#059669"
                      note="0 = gravity only. Push past mg sinθ + friction to send the block UP the slope." />
                  </>
                )}
                <Slider label="Static μs" unit="" value={muS} min={0.05} max={1} step={0.01} set={v => setMuS(Math.max(v, muK))} color="#10b981" />
                <Slider label="Kinetic μk" unit="" value={muK} min={0.05} max={1} step={0.01} set={v => setMuK(Math.min(v, muS))} color="#8b5cf6" note="μk is kept ≤ μs, as it always is physically" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'flat' && <>
                    <StatRow label="Normal reaction N" value={flat.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="Max static friction" value={flat.staticMax.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="Current friction" value={flat.friction.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="State" value={flat.moving ? 'sliding' : 'static'} unit="" color="text-rose-500" />
                    <StatRow label="Acceleration" value={flat.acceleration.toFixed(2)} unit="m/s²" color="text-purple-600" />
                  </>}
                  {mode === 'incline' && <>
                    <StatRow label="Weight (mg)" value={inc.weight.toFixed(1)} unit="N" color="text-violet-600" />
                    <StatRow label="Normal reaction N" value={inc.N.toFixed(1)} unit="N" color="text-indigo-600" />
                    <StatRow label="mg sinθ (∥ to slope)" value={inc.gravityAlong.toFixed(1)} unit="N" color="text-emerald-600" />
                    <StatRow label="mg cosθ (⊥ to slope)" value={inc.gravityPerp.toFixed(1)} unit="N" color="text-amber-600" />
                    <StatRow label="Max static friction" value={inc.staticMax.toFixed(1)} unit="N" color="text-rose-500" />
                    <StatRow label="Angle of repose" value={inc.reposeAngle.toFixed(1)} unit="°" color="text-purple-600" />
                    <StatRow label="At rest, would…" value={inc.direction === 'static' ? 'stay still' : inc.direction === 'up' ? 'move up' : 'slide down'} unit="" color="text-gray-600" />
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
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

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

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
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
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <WaveCanvas key={resetKey} mode={mode}
                  amplitude={A} frequency={f} wavelength={lambda}
                  amplitude2={A2} frequency2={f2} phase2={phase2}
                  isRunning={isRunning} isPaused={isPaused}
                  width={canvasSize.width} height={canvasSize.height} />
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
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { OpticsCanvas, OpticsMode } from '@/components/simulation/OpticsCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { snellTheta2, criticalAngle, thinLensImage, lensPower } from '@/lib/physics/optics';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

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

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
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
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <OpticsCanvas mode={mode} n1={n1} n2={n2} theta1={theta1}
                  focal={focal} objectDist={objectDist} converging={converging}
                  width={canvasSize.width} height={canvasSize.height} />
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
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

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

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
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
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <CircuitCanvas key={resetKey} mode={mode} voltage={V} r1={r1} r2={r2} r3={r3}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
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

echo "  → src/app/simulations/radioactive-decay/page.tsx"
cat > "src/app/simulations/radioactive-decay/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DecayCanvas, DecayGraph } from '@/components/simulation/DecayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { decayConstant, activity, remaining } from '@/lib/physics/decay';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

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

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
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

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Random decay, predictable statistics</span>
            <span className="text-sm font-semibold font-mono text-gray-900">N = N₀ · 2^(−t/T½)</span>
            <span className="text-xs text-gray-400 ml-2">λ = ln2/T½ &nbsp;|&nbsp; A = λN</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DecayCanvas n0={n0} halfLife={halfLife} resetKey={resetKey}
                  isRunning={isRunning} isPaused={isPaused}
                  onTick={handleTick} width={canvasSize.width} height={canvasSize.height} />
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

echo "  → src/app/simulations/photoelectric-effect/page.tsx"
cat > "src/app/simulations/photoelectric-effect/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { PhotoelectricCanvas } from '@/components/simulation/PhotoelectricCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { METALS, keMaxEV, thresholdF14, stoppingPotential, photonEnergyEV, wavelengthNm, keLine } from '@/lib/physics/photoelectric';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'The killer observation classical physics could NOT explain: below the threshold frequency f₀ = φ/h, NO electrons are emitted no matter how intense the light. Try it — set red light on zinc and crank the intensity.',
  'Light arrives as PHOTONS of energy E = hf. One photon frees at most one electron: hf = φ + KEmax (Einstein, Nobel Prize 1921).',
  'Intensity controls the NUMBER of photons → the photocurrent. Frequency controls the ENERGY of each electron. Watch: more intensity = more electrons, not faster ones.',
  'The KEmax–f graph is a straight line with slope h/e (the same for every metal!) and x-intercept f₀. Different metals shift the line, never tilt it.',
  'Stopping potential Vs: the reverse voltage that just stops the fastest electrons — eVs = KEmax, so Vs in volts equals KEmax in eV.',
];

const EXERCISES = [
  { q: 'Light of frequency 7×10¹⁴ Hz falls on sodium (φ = 2.28 eV). Find the photon energy and KEmax. (h = 6.63×10⁻³⁴ Js, e = 1.6×10⁻¹⁹ C)', a: 'E = hf = 6.63e-34 × 7e14 = 4.64e-19 J = 2.90 eV. KEmax = 2.90 − 2.28 = 0.62 eV ≈ 1.0×10⁻¹⁹ J.' },
  { q: 'The threshold wavelength of a metal is 500 nm. Find its work function in eV.', a: 'φ = hc/λ₀ = (6.63e-34 × 3e8)/5e-7 = 3.98e-19 J ≈ 2.48 eV.' },
  { q: 'Doubling the intensity of light on a photocell does what to (a) the current, (b) the KEmax?', a: '(a) Current doubles — twice as many photons free twice as many electrons. (b) KEmax is unchanged — each photon still carries the same energy hf.' },
  { q: 'For caesium (φ = 2.1 eV) lit at f = 8×10¹⁴ Hz, find the stopping potential.', a: 'E = hf = 3.31 eV. KEmax = 3.31 − 2.1 = 1.21 eV, so Vs = 1.21 V.' },
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

// KEmax vs f graph: straight line of universal slope h/e, x-intercept f₀.
function KEGraph({ phiEV, f14 }: { phiEV: number; f14: number }) {
  const fMax = 14;
  const data = useMemo(() => keLine(phiEV, fMax), [phiEV]);
  const f0 = thresholdF14(phiEV);
  const ke = keMaxEV(f14, phiEV);
  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="f" type="number" tick={{ fontSize: 10 }} domain={[0, fMax]}>
          <Label value="Frequency f (×10¹⁴ Hz)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="KEmax (eV)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' eV', 'KEmax']} labelFormatter={f => `f = ${f}×10¹⁴ Hz`} />
        <Line type="linear" dataKey="ke" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={f0} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'f₀', position: 'top', fontSize: 10, fill: '#d97706' }} />
        <ReferenceDot x={Math.min(f14, fMax)} y={ke} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function PhotoelectricPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [metalIdx, setMetalIdx] = useState(0);
  const [f14, setF14] = useState(6.0);
  const [intensity, setIntensity] = useState(5);

  const metal = METALS[metalIdx];
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [metalIdx, f14, intensity, reset]);

  const ke = keMaxEV(f14, metal.phi);
  const f0 = thresholdF14(metal.phi);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Photoelectric effect</h1>
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
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Einstein&apos;s photoelectric equation</span>
            <span className="text-sm font-semibold font-mono text-gray-900">hf = φ + KEmax</span>
            <span className="text-xs text-gray-400 ml-2">f₀ = φ/h &nbsp;|&nbsp; eVs = KEmax</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <PhotoelectricCanvas f14={f14} intensity={intensity} phiEV={metal.phi} metalName={metal.name}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/photoelectric"
                  title="Photoelectric effect — A-Factor STEM Studio"
                  params={{ metal: metalIdx, f: f14, i: intensity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">KEmax against frequency</p>
                <KEGraph phiEV={metal.phi} f14={f14} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Slope = h/e for EVERY metal · x-intercept = threshold f₀ · red dot = your current light
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {METALS.map((m, i) => (
                    <button key={m.name} onClick={() => setMetalIdx(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        metalIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{m.name} ({m.phi} eV)</button>
                  ))}
                </div>
                <Slider label="Light frequency" unit="×10¹⁴ Hz" value={f14} min={2} max={14} step={0.1} set={setF14} color="#6366f1"
                  note={`Threshold for ${metal.name}: f₀ = ${f0.toFixed(2)}×10¹⁴ Hz — drop below it and emission stops`} />
                <Slider label="Intensity" unit="" value={intensity} min={1} max={10} step={1} set={setIntensity} color="#f59e0b"
                  note="Changes how MANY electrons per second — never their energy" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Photon energy hf" value={photonEnergyEV(f14).toFixed(2)} unit="eV" color="text-indigo-600" />
                  <StatRow label="Wavelength λ" value={wavelengthNm(f14).toFixed(0)} unit="nm" color="text-emerald-600" />
                  <StatRow label="Work function φ" value={metal.phi.toFixed(2)} unit="eV" color="text-amber-600" />
                  <StatRow label="Threshold f₀" value={f0.toFixed(2)} unit="×10¹⁴ Hz" color="text-rose-500" />
                  <StatRow label="KEmax" value={ke.toFixed(2)} unit="eV" color="text-purple-600" />
                  <StatRow label="Stopping potential" value={stoppingPotential(f14, metal.phi).toFixed(2)} unit="V" color="text-gray-600" />
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

echo "  → src/app/simulations/de-broglie/page.tsx"
cat > "src/app/simulations/de-broglie/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { DeBroglieCanvas } from '@/components/simulation/DeBroglieCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PARTICLES, deBroglieLambda, momentum, formatLambda, lambdaFromVoltage } from '@/lib/physics/debroglie';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'De Broglie (1924): if light waves can behave as particles (photons), then particles should behave as waves — λ = h/mv. Confirmed by Davisson–Germer electron diffraction in 1927.',
  'The key comparison: an electron at 2×10⁶ m/s has λ ≈ 0.36 nm (atom-sized → diffracts off crystals) while a cricket ball has λ ≈ 10⁻³⁴ m — unimaginably smaller than a nucleus, so we never see cricket balls diffract.',
  'Larger momentum → shorter wavelength. Switch particles and watch λ collapse: mass in the denominator is why wave behaviour is invisible for everyday objects.',
  'Electron microscopes exploit this: electrons accelerated through kilovolts get λ far below visible light (400–700 nm), resolving individual atoms.',
  'For an electron accelerated through voltage V: λ = h/√(2meV) ≈ 1.23/√V nm — a favourite exam derivation (KE = eV = p²/2m).',
];

const EXERCISES = [
  { q: 'Find the de Broglie wavelength of an electron (m = 9.11×10⁻³¹ kg) moving at 2×10⁶ m/s.', a: 'λ = h/mv = 6.63e-34 / (9.11e-31 × 2e6) = 3.6×10⁻¹⁰ m = 0.36 nm.' },
  { q: 'A 0.16 kg cricket ball travels at 30 m/s. Find λ and explain why we never observe its wave nature.', a: 'λ = 6.63e-34/(0.16×30) ≈ 1.4×10⁻³⁴ m — about 10¹⁹ times smaller than a nucleus, far too small for any slit or detector.' },
  { q: 'An electron is accelerated from rest through 100 V. Find its de Broglie wavelength.', a: 'λ = h/√(2meV) = 6.63e-34/√(2×9.11e-31×1.6e-19×100) ≈ 1.23×10⁻¹⁰ m ≈ 0.123 nm.' },
  { q: 'A proton and an electron have the SAME speed. Which has the longer wavelength and by what factor?', a: 'λ ∝ 1/m at fixed v, so the electron: longer by mp/me ≈ 1836 times.' },
];

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value.toExponential(2)} <span className="text-gray-400 font-normal">{unit}</span></span>
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

export default function DeBrogliePage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [pIdx, setPIdx] = useState(0);
  const particle = PARTICLES[pIdx];
  const [velocity, setVelocity] = useState(particle.vDefault);
  const [accelV, setAccelV] = useState(100);

  const selectParticle = (i: number) => { setPIdx(i); setVelocity(PARTICLES[i].vDefault); };

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [pIdx, velocity, reset]);

  const lambda = deBroglieLambda(particle.mass, velocity);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 280, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">De Broglie hypothesis</h1>
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
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Matter waves</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λ = h/mv = h/p</span>
            <span className="text-xs text-gray-400 ml-2">accelerated electron: λ = h/√(2meV)</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <DeBroglieCanvas mass={particle.mass} velocity={velocity} particleName={particle.name}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/debroglie"
                  title="De Broglie wavelength — A-Factor STEM Studio"
                  params={{ p: pIdx, v: velocity }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <div className="flex flex-wrap gap-1.5">
                  {PARTICLES.map((p, i) => (
                    <button key={p.name} onClick={() => selectParticle(i)}
                      className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                        pIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                      }`}>{p.emoji} {p.name}</button>
                  ))}
                </div>
                <Slider label="Speed v" unit="m/s" value={velocity} min={particle.vMin} max={particle.vMax}
                  step={(particle.vMax - particle.vMin) / 200} set={setVelocity} color="#6366f1"
                  note="Faster → more momentum → SHORTER wavelength" />
                <div className="rounded-xl bg-indigo-50 border border-indigo-100 p-3 space-y-2">
                  <p className="text-[11px] font-medium text-indigo-700">Electron gun calculator: λ = h/√(2meV)</p>
                  <Slider label="Accelerating voltage" unit="V" value={accelV} min={10} max={10000} step={10} set={setAccelV} color="#8b5cf6" />
                  <p className="text-xs text-indigo-800 font-mono">
                    V = {accelV} V → λ = {formatLambda(lambdaFromVoltage(accelV))}
                  </p>
                </div>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="Mass m" value={particle.mass.toExponential(2)} unit="kg" color="text-indigo-600" />
                  <StatRow label="Momentum p" value={momentum(particle.mass, velocity).toExponential(2)} unit="kg·m/s" color="text-emerald-600" />
                  <StatRow label="Wavelength λ" value={formatLambda(lambda)} unit="" color="text-amber-600" />
                  <StatRow label="vs atom (0.1nm)" value={(lambda / 1e-10).toExponential(1)} unit="×" color="text-rose-500" />
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

echo "  → src/app/simulations/x-rays/page.tsx"
cat > "src/app/simulations/x-rays/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef, useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { XrayCanvas } from '@/components/simulation/XrayCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { lambdaMinNm, maxPhotonEnergyKeV, xraySpectrum, MO_K_ALPHA_NM, MO_K_BETA_NM, MO_EXCITATION_KV } from '@/lib/physics/xrays';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TEACHER_NOTES = [
  'X-ray production is the photoelectric effect in REVERSE: fast electrons in, photons out. Electrons accelerated through kV strike a metal target; ~99% of their energy becomes heat, ~1% becomes X-rays (which is why anodes are cooled or rotated).',
  'The continuous (bremsstrahlung = "braking radiation") spectrum has a sharp cutoff λmin = hc/eV — the Duane–Hunt limit. An electron cannot give a photon more than its whole kinetic energy eV.',
  'Raise the tube voltage: λmin slides LEFT (shorter, more penetrating "harder" X-rays). Raise the filament current: MORE X-rays (taller spectrum), same λmin.',
  'The sharp Kα/Kβ characteristic lines appear only when electrons can knock out inner-shell electrons of the target (Mo: above ~20 kV). Their wavelengths identify the target element — the basis of X-ray spectroscopy.',
  'Properties for exams: travel in straight lines, not deflected by electric/magnetic fields (uncharged), ionise gases, penetrate matter (absorbed by dense material like bone/lead), affect photographic film.',
];

const EXERCISES = [
  { q: 'An X-ray tube runs at 50 kV. Find the minimum wavelength produced. (h = 6.63×10⁻³⁴ Js, c = 3×10⁸ m/s, e = 1.6×10⁻¹⁹ C)', a: 'λmin = hc/eV = (6.63e-34 × 3e8)/(1.6e-19 × 5e4) = 2.49×10⁻¹¹ m ≈ 0.025 nm.' },
  { q: 'What is the maximum photon energy (in keV) from a 80 kV tube, and why is it a maximum?', a: '80 keV — a photon cannot carry more than the full kinetic energy eV of one electron; most electrons give up their energy in stages (heat + softer photons).' },
  { q: 'Doubling the filament current does what to (a) the spectrum height, (b) λmin?', a: '(a) Doubles the intensity everywhere — twice as many electrons. (b) λmin unchanged: it depends only on the tube voltage.' },
  { q: 'Why do the Kα and Kβ lines disappear when the tube voltage drops below 20 kV (Mo target)?', a: 'Below 20 kV the electrons lack the energy to eject a K-shell electron from molybdenum, so no inner-shell vacancies form and no characteristic photons are emitted.' },
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

function SpectrumGraph({ kV, current }: { kV: number; current: number }) {
  const data = useMemo(() => xraySpectrum(kV, current), [kV, current]);
  const lMin = lambdaMinNm(kV);
  return (
    <ResponsiveContainer width="100%" height={210}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="lambda" type="number" tick={{ fontSize: 10 }} domain={[0, 0.14]}>
          <Label value="Wavelength λ (nm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Intensity" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2), 'I']} labelFormatter={l => `λ=${Number(l).toFixed(3)}nm`} />
        <Line type="linear" dataKey="i" stroke="#8b5cf6" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={lMin} stroke="#ef4444" strokeDasharray="4 4"
          label={{ value: 'λmin', position: 'top', fontSize: 10, fill: '#dc2626' }} />
        {kV >= MO_EXCITATION_KV && <>
          <ReferenceLine x={MO_K_ALPHA_NM} stroke="#e2e8f0"
            label={{ value: 'Kα', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
          <ReferenceLine x={MO_K_BETA_NM} stroke="#e2e8f0"
            label={{ value: 'Kβ', position: 'top', fontSize: 9, fill: '#94a3b8' }} />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function XraysPage() {
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);

  const [kV, setKV] = useState(35);
  const [current, setCurrent] = useState(5);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [kV, current, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Modern physics</p>
                <h1 className="text-lg font-semibold text-gray-900">X-rays</h1>
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
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Duane–Hunt limit</span>
            <span className="text-sm font-semibold font-mono text-gray-900">λmin = hc/eV</span>
            <span className="text-xs text-gray-400 ml-2">max photon energy = eV</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <XrayCanvas kV={kV} current={current}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/xrays"
                  title="X-ray tube — A-Factor STEM Studio"
                  params={{ kV, i: current }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">X-ray spectrum (Mo target)</p>
                <SpectrumGraph kV={kV} current={current} />
                <p className="text-[10px] text-gray-400 mt-2 text-center">
                  Continuous bremsstrahlung with sharp cutoff at λmin — Kα/Kβ characteristic lines above {MO_EXCITATION_KV} kV
                </p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Tube voltage" unit="kV" value={kV} min={5} max={100} step={1} set={setKV} color="#6366f1"
                  note="Higher V → shorter λmin → harder, more penetrating X-rays" />
                <Slider label="Filament current" unit="" value={current} min={1} max={10} step={1} set={setCurrent} color="#f59e0b"
                  note="More electrons → more X-rays, but λmin does not move" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="λmin" value={lambdaMinNm(kV).toFixed(4)} unit="nm" color="text-indigo-600" />
                  <StatRow label="Max photon energy" value={maxPhotonEnergyKeV(kV).toFixed(0)} unit="keV" color="text-emerald-600" />
                  <StatRow label="Electron KE" value={kV.toFixed(0)} unit="keV" color="text-amber-600" />
                  <StatRow label="K lines" value={kV >= MO_EXCITATION_KV ? 'visible' : 'absent'} unit="" color="text-rose-500" />
                  <StatRow label="Energy → heat" value="~99" unit="%" color="text-purple-600" />
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

echo "  → src/app/simulations/heat-transfer/page.tsx"
cat > "src/app/simulations/heat-transfer/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { HeatTransferCanvas, HeatMode } from '@/components/simulation/HeatTransferCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { celsiusToKelvin, radiatedPower, netRadiation } from '@/lib/physics/heat';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<HeatMode, { title: string; icon: string; sub: string; eq: string }> = {
  conduction: { title: 'Conduction', icon: '🔗', sub: 'Solids — particle to particle', eq: 'Q/t = kAΔT/L' },
  convection: { title: 'Convection', icon: '🌀', sub: 'Fluids — bulk movement',        eq: 'warm rises, cool sinks' },
  radiation:  { title: 'Radiation',  icon: '☀️', sub: 'EM waves — needs no medium',    eq: 'P = εσAT⁴' },
};

const TEACHER_NOTES: Record<HeatMode, string[]> = {
  conduction: [
    'Particles do NOT travel down the rod — they vibrate in place and pass energy to their neighbours, like a row of people jiggling a rope.',
    'Metals conduct well because free (delocalised) electrons carry energy quickly through the lattice; non-metals lack these free electrons.',
    'Rate of heat flow: Q/t = kAΔT/L — bigger area or ΔT speeds it up, a thicker (longer) barrier slows it down. This is exactly why we use thick walls and small windows to keep buildings warm.',
    'Compare copper (k≈385) with glass (k≈0.8): copper conducts about 480 times faster — try both in the material list.',
    'Trapped air (double glazing, wool, fur) is a poor conductor and makes an excellent insulator, precisely because it has such a low k.',
  ],
  convection: [
    'Unlike conduction, the medium ITSELF moves in convection — warm fluid expands, becomes less dense, and rises; cooler, denser fluid sinks to replace it, setting up a convection current.',
    'This only happens in fluids (liquids and gases) — solids cannot flow, so they never convect.',
    'Real examples: sea breezes (land heats faster than sea by day), the radiator in a room (warms air rises, circulates the whole room), boiling water in a pot.',
    'Convection needs gravity (or an equivalent force) to drive the density difference — it does not work in free-fall / microgravity.',
    'The hotter the source, the faster and more vigorous the circulation — watch the particle loop speed up as you raise the temperature.',
  ],
  radiation: [
    'Radiation is the only mode of heat transfer that needs NO medium — infrared electromagnetic waves cross the vacuum of space, which is how the Sun warms the Earth.',
    'Stefan–Boltzmann law: P = εσAT⁴ — power radiated depends on the FOURTH power of absolute temperature, so a small temperature rise causes a huge jump in radiated power.',
    'Dull, black (matte) surfaces are good absorbers AND good emitters (high emissivity ε); shiny, silvered surfaces are poor absorbers/emitters — why vacuum flasks are silvered and radiators are painted matte black.',
    'All objects above 0 K radiate; the object also absorbs radiation from its surroundings, so the NET transfer depends on the temperature difference (T⁴ − T₀⁴).',
    'Applications: thermal imaging cameras detect the infrared radiated by warm bodies; a car left in the sun heats up mainly by absorbed solar radiation.',
  ],
};

const EXERCISES: Record<HeatMode, { q: string; a: string }[]> = {
  conduction: [
    { q: 'A copper bar (k=385 W/mK) of area 0.002m² and length 0.5m has a 60°C temperature difference across it. Find the rate of heat flow.', a: 'Q/t = kAΔT/L = 385×0.002×60/0.5 = 92.4 W.' },
    { q: 'Why do metal spoons feel colder to touch than wooden ones at the same room temperature?', a: 'Metal has much higher thermal conductivity, so it conducts heat away from your hand much faster than wood, feeling colder even though both are at the same temperature.' },
    { q: 'A wall has half the thickness of another identical wall. How does the rate of heat conduction compare?', a: 'Q/t ∝ 1/L, so halving the thickness DOUBLES the rate of heat loss.' },
  ],
  convection: [
    { q: 'Explain, using convection, why a radiator is placed near the floor rather than the ceiling.', a: 'Air warmed by the radiator becomes less dense and rises, setting up a convection current that circulates warm air throughout the whole room from the bottom up.' },
    { q: 'Why does a hot air balloon rise?', a: 'The burner heats the air inside, making it less dense than the surrounding cooler air, so the balloon experiences a net upward (buoyant) force — exactly like a convection current.' },
    { q: 'Why can convection not occur in a solid?', a: 'Convection requires bulk movement of particles; particles in a solid are fixed in place and cannot flow to create a circulation current.' },
  ],
  radiation: [
    { q: 'A black surface of area 0.01m² at 500K radiates into surroundings at 300K. Find the net power radiated. (σ = 5.67×10⁻⁸ W/m²K⁴, ε=1)', a: 'P = εσA(T⁴−T₀⁴) = 5.67e-8×0.01×(500⁴−300⁴) = 5.67e-10×(6.25e10−8.1e9) ≈ 30.7 W.' },
    { q: 'Why are the pipes of a solar water heater usually painted matte black?', a: 'Matte black surfaces are excellent absorbers of radiation, maximising the energy absorbed from sunlight to heat the water.' },
    { q: 'A star doubles in absolute temperature. By what factor does its radiated power increase?', a: 'P ∝ T⁴, so doubling T increases power by 2⁴ = 16 times.' },
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

export default function HeatTransferPage() {
  const [mode, setMode] = useState<HeatMode>('conduction');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [hotTemp, setHotTemp] = useState(90);
  const [coldTemp, setColdTemp] = useState(20);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 80);
  }, [mode, hotTemp, coldTemp, reset]);

  const Thot = celsiusToKelvin(hotTemp), Tcold = celsiusToKelvin(coldTemp);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 300, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Thermal physics</p>
                <h1 className="text-lg font-semibold text-gray-900">Modes of heat transfer</h1>
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
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as HeatMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <HeatTransferCanvas mode={mode} hotTemp={hotTemp} coldTemp={coldTemp}
                  isRunning={isRunning} isPaused={isPaused} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/heat"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={{ mode, hot: hotTemp, cold: coldTemp }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                <Slider label="Hot temperature" unit="°C" value={hotTemp} min={30} max={120} step={5} set={setHotTemp} color="#ef4444" />
                <Slider label="Cold / surroundings temperature" unit="°C" value={coldTemp} min={0} max={40} step={5} set={setColdTemp} color="#3b82f6" />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  <StatRow label="ΔT" value={(hotTemp - coldTemp).toFixed(0)} unit="°C" color="text-indigo-600" />
                  {mode === 'radiation' && <>
                    <StatRow label="Hot object radiates" value={radiatedPower(1, 0.01, Thot).toFixed(2)} unit="W" color="text-emerald-600" />
                    <StatRow label="Net transfer" value={netRadiation(1, 0.01, Thot, Tcold).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="T⁴ ratio" value={Math.pow(Thot / Tcold, 4).toFixed(1)} unit="×" color="text-rose-500" />
                  </>}
                  {mode !== 'radiation' && (
                    <StatRow label="Direction" value="hot → cold" unit="always" color="text-emerald-600" />
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

echo "  → src/app/simulations/elasticity/page.tsx"
cat > "src/app/simulations/elasticity/page.tsx" << 'AFEOF'
'use client';
import { useState, useMemo, useRef } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot, ReferenceLine } from 'recharts';
import { AppHeader } from '@/components/layout/AppHeader';
import { ElasticityCanvas, ElasticityMode } from '@/components/simulation/ElasticityCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { extension, springEnergy, forceExtensionCurve, wireExtension, stress, strain, youngModulus, WIRE_MATERIALS } from '@/lib/physics/elasticity';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const MODE_META: Record<ElasticityMode, { title: string; icon: string; sub: string; eq: string }> = {
  hooke: { title: "Hooke's law", icon: '🌀', sub: 'A loaded spring',       eq: 'F = ke' },
  wire:  { title: 'Young modulus', icon: '🧵', sub: 'Stretching a wire', eq: 'E = σ/ε = FL/(Ae)' },
};

const TEACHER_NOTES: Record<ElasticityMode, string[]> = {
  hooke: [
    "Hooke's law: extension is directly proportional to the applied force, e ∝ F, i.e. F = ke — but only up to the ELASTIC LIMIT.",
    'Beyond the elastic limit the spring deforms PERMANENTLY: it will not return to its natural length when the load is removed, and F = ke no longer applies.',
    'The spring constant k (N/m) measures stiffness: a bigger k means a stiffer spring that stretches less for the same force.',
    'Energy stored in a stretched (or compressed) spring: E = ½Fe = ½ke² — the area under a force–extension graph, used in catapults, archery bows, and pogo sticks.',
    'Springs in series share the load but each stretches independently (softer overall); springs in parallel share the extension (stiffer overall) — a nice follow-up demonstration.',
  ],
  wire: [
    'Stress σ = F/A (force per unit cross-sectional area) and strain ε = e/L (extension per unit original length) — both are needed because a thick wire stretches less than a thin one under the same force.',
    "Young's modulus E = σ/ε is a property of the MATERIAL only — steel always has the same E, whatever the wire's length or thickness.",
    'Real wire extensions under normal loads are tiny (often fractions of a millimetre) — this simulation magnifies the extension so you can see it; the true value is always shown in the info card.',
    'A stress–strain graph for a ductile material (like copper) shows a straight (Hookean) region, then plastic deformation, then a breaking point — steel and glass behave very differently here.',
    'Practical use: engineers select materials by their E value — steel cables for bridges need high E (stiff, minimal sag) while rubber seals need low E (flexible).',
  ],
};

const EXERCISES: Record<ElasticityMode, { q: string; a: string }[]> = {
  hooke: [
    { q: 'A spring stretches 4cm under a 20N load. Find its spring constant k.', a: 'k = F/e = 20/0.04 = 500 N/m.' },
    { q: 'A spring of k=250 N/m is stretched by 6cm. Find the elastic energy stored.', a: 'E = ½ke² = ½×250×0.06² = 0.45 J.' },
    { q: 'A spring obeys Hooke\'s law up to 30N, extending 10cm at that load. What extension would 45N (beyond the limit) roughly NOT follow, and why?', a: 'It would NOT simply extend to 15cm proportionally — beyond the elastic limit the material deforms plastically and extension grows faster than F for a given increase in load, and the deformation becomes permanent.' },
  ],
  wire: [
    { q: 'A steel wire (E=200 GPa) of length 2m and cross-sectional area 1×10⁻⁶ m² carries a 100N load. Find its extension.', a: 'e = FL/(AE) = (100×2)/(1e-6×200e9) = 200/200000 = 1×10⁻³ m = 1mm.' },
    { q: 'A wire of diameter 0.5mm stretches 0.8mm under a 50N load over 1.5m. Find the stress and strain.', a: 'A=π(0.00025)²≈1.96×10⁻⁷m². σ=F/A=50/1.96e-7≈2.55×10⁸ Pa. ε=e/L=0.0008/1.5≈5.33×10⁻⁴.' },
    { q: 'Using the previous answer, find the Young\'s modulus.', a: 'E=σ/ε=2.55×10⁸/5.33×10⁻⁴≈4.78×10¹¹ Pa ≈ 478 GPa.' },
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

function ForceExtensionGraph({ k, elasticLimitF, load }: { k: number; elasticLimitF: number; load: number }) {
  const fMax = elasticLimitF * 2.2;
  const data = useMemo(() => forceExtensionCurve(k, elasticLimitF, fMax), [k, elasticLimitF, fMax]);
  const e = extension(Math.min(load, elasticLimitF), k) * 100;
  const eLimitCm = (elasticLimitF / k) * 100;
  return (
    <ResponsiveContainer width="100%" height={190}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="e" type="number" tick={{ fontSize: 10 }}>
          <Label value="Extension e (cm)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis dataKey="F" tick={{ fontSize: 10 }}>
          <Label value="Force F (N)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(2) + ' N', 'F']} labelFormatter={e => `e=${Number(e).toFixed(2)}cm`} />
        <Line type="linear" dataKey="F" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
        <ReferenceLine x={eLimitCm} stroke="#f59e0b" strokeDasharray="4 4"
          label={{ value: 'elastic limit', position: 'top', fontSize: 9, fill: '#d97706' }} />
        <ReferenceDot x={e} y={Math.min(load, elasticLimitF)} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}

export default function ElasticityPage() {
  const [mode, setMode] = useState<ElasticityMode>('hooke');
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [load, setLoad] = useState(8);
  const [k, setK] = useState(200);
  const [elasticLimitF, setElasticLimitF] = useState(15);

  const [wireLength, setWireLength] = useState(2);
  const [wireDiamMm, setWireDiamMm] = useState(0.5);
  const [matIdx, setMatIdx] = useState(0);
  const [wireLoad, setWireLoad] = useState(60);
  const material = WIRE_MATERIALS[matIdx];

  const A = Math.PI * Math.pow((wireDiamMm / 1000) / 2, 2);
  const e = wireExtension(wireLoad, wireLength, A, material.E);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 640, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Elasticity</h1>
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
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(MODE_META) as ElasticityMode[]).map(m => (
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
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ElasticityCanvas mode={mode}
                  load={mode === 'hooke' ? load : wireLoad} k={k} elasticLimitF={elasticLimitF}
                  wireLength={wireLength} wireDiamMm={wireDiamMm} youngE={material.E} materialName={material.name}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex justify-end">
                <EmbedButton path="/embed/elasticity"
                  title={`${MODE_META[mode].title} — A-Factor STEM Studio`}
                  params={mode === 'hooke' ? { mode, load, k, limit: elasticLimitF } : { mode, mat: matIdx, L: wireLength, d: wireDiamMm, F: wireLoad }} />
              </div>

              {mode === 'hooke' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-2">Force–extension graph</p>
                  <ForceExtensionGraph k={k} elasticLimitF={elasticLimitF} load={load} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    Linear (Hooke) region, then plastic deformation beyond the elastic limit
                  </p>
                </div>
              )}

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>
                {mode === 'hooke' && <>
                  <Slider label="Load F" unit="N" value={load} min={0} max={30} step={0.5} set={setLoad} color="#6366f1" />
                  <Slider label="Spring constant k" unit="N/m" value={k} min={50} max={500} step={10} set={setK} color="#f59e0b" />
                  <Slider label="Elastic limit" unit="N" value={elasticLimitF} min={5} max={25} step={1} set={setElasticLimitF} color="#ef4444" />
                </>}
                {mode === 'wire' && <>
                  <div className="flex flex-wrap gap-1.5">
                    {WIRE_MATERIALS.map((m, i) => (
                      <button key={m.name} onClick={() => setMatIdx(i)}
                        className={`rounded-full border px-2.5 py-1 text-[11px] font-medium transition ${
                          matIdx === i ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500 hover:border-indigo-200'
                        }`}>{m.name}</button>
                    ))}
                  </div>
                  <Slider label="Load F" unit="N" value={wireLoad} min={5} max={200} step={5} set={setWireLoad} color="#6366f1" />
                  <Slider label="Wire length L" unit="m" value={wireLength} min={0.5} max={5} step={0.1} set={setWireLength} color="#10b981" />
                  <Slider label="Wire diameter" unit="mm" value={wireDiamMm} min={0.1} max={2} step={0.05} set={setWireDiamMm} color="#8b5cf6" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {mode === 'hooke' && <>
                    <StatRow label="Extension e" value={(extension(Math.min(load, elasticLimitF), k) * 100).toFixed(2)} unit="cm" color="text-indigo-600" />
                    <StatRow label="Energy stored" value={springEnergy(k, extension(Math.min(load, elasticLimitF), k)).toFixed(3)} unit="J" color="text-emerald-600" />
                    <StatRow label="Within limit?" value={load <= elasticLimitF ? 'yes' : 'NO — plastic'} unit="" color="text-amber-600" />
                  </>}
                  {mode === 'wire' && <>
                    <StatRow label="Cross-section A" value={(A * 1e6).toFixed(4)} unit="mm²" color="text-indigo-600" />
                    <StatRow label="Stress σ" value={(stress(wireLoad, A) / 1e6).toFixed(1)} unit="MPa" color="text-emerald-600" />
                    <StatRow label="Strain ε" value={strain(e, wireLength).toExponential(2)} unit="" color="text-amber-600" />
                    <StatRow label="Extension e" value={(e * 1000).toFixed(3)} unit="mm" color="text-rose-500" />
                    <StatRow label="Young modulus" value={(youngModulus(wireLoad, A, e, wireLength) / 1e9).toFixed(0)} unit="GPa" color="text-purple-600" />
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

            {/* Col 1: canvas + controls + sliders */}
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

              {/* Sliders */}
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
            </div>

            {/* Col 2: analytics */}
            <div className="space-y-3">
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

echo "  → src/app/simulations/newtons-laws/page.tsx"
cat > "src/app/simulations/newtons-laws/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useMemo, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { NewtonsFirstCanvas } from '@/components/simulation/NewtonsFirstCanvas';
import { NewtonsSecondCanvas } from '@/components/simulation/NewtonsSecondCanvas';
import { NewtonsThirdCanvas } from '@/components/simulation/NewtonsThirdCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { NewtonsGraph } from '@/components/simulation/NewtonsGraph';
import { ThirdLawGraph } from '@/components/simulation/ThirdLawGraph';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import {
  secondLawAnalytics, thirdLawAnalytics, firstLawTrajectory, secondLawTrajectory, thirdLawTrajectory,
  firstLawAcceleration, ROCKET_GRAPH_DURATION, FirstLawState, SecondLawState,
} from '@/lib/physics/newtons-laws';

type Law = '1st' | '2nd' | '3rd';
type GraphType = 'v' | 'a' | 'x';
type Scenario3 = 'push' | 'rocket' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META = {
  '1st': { title: "Newton's 1st law", sub: 'Law of inertia', eq: 'ΣF = 0 → v = constant', color: '#6366f1' },
  '2nd': { title: "Newton's 2nd law", sub: 'Law of acceleration', eq: 'F = ma', color: '#10b981' },
  '3rd': { title: "Newton's 3rd law", sub: 'Law of action & reaction', eq: 'F₁₂ = −F₂₁', color: '#f59e0b' },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  '1st': [
    "An object stays at rest or moves at constant velocity unless a net external force acts on it.",
    "Inertia is the resistance to change in motion — heavier objects have more inertia.",
    "On a frictionless surface (μ=0), a moving block never stops. On Earth, friction provides the net force.",
    "Common misconception: students think a moving object needs a continuous force to keep moving. It doesn't — only to accelerate it.",
    "Demonstrate: set initial velocity, then toggle friction on/off mid-animation to show inertia.",
  ],
  '2nd': [
    "F = ma: net force equals mass times acceleration. Doubling force doubles acceleration; doubling mass halves it.",
    "Net force, not applied force, causes acceleration. Subtract friction: F_net = F_applied − μmg.",
    "The F-a relationship is linear — the graph of a vs F (constant m) is a straight line through the origin.",
    "Unit check: 1 Newton = 1 kg·m/s². If m=2kg and a=3m/s², F_net=6N.",
    "Show students: with enough friction, a block won't move even with applied force (static friction ≥ F_applied).",
  ],
  '3rd': [
    "For every action there is an equal and opposite reaction — the forces act on DIFFERENT objects.",
    "Common exam trap: students cancel action-reaction pairs. They can't — they act on different bodies.",
    "Rocket propulsion: hot gas is pushed backward (action), rocket is pushed forward (reaction).",
    "The forces are always equal in magnitude — but accelerations differ because masses differ (a = F/m).",
    "Walking: you push the ground backward (action), the ground pushes you forward (reaction).",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  '1st': [
    { q: "A 5kg block moves at 10 m/s on a frictionless surface. What net force is needed to maintain this speed?", a: "Zero — by Newton's 1st law, no net force is needed to maintain constant velocity. ΣF = 0." },
    { q: "A 10kg block is pushed at 4 m/s and then released on a surface with μ = 0.3. Find the deceleration. (g=10 m/s²)", a: "Friction = μmg = 0.3×10×10 = 30N. a = F/m = 30/10 = 3 m/s² deceleration." },
    { q: "Why do passengers lurch forward when a bus brakes suddenly?", a: "Passengers tend to continue moving at the bus's original speed (inertia) while the bus decelerates. The seat provides no forward force, so they lurch forward relative to the bus." },
  ],
  '2nd': [
    { q: "A 4kg block is pushed with 20N on a surface with μ = 0.25. Find the acceleration. (g=10 m/s²)", a: "Friction = 0.25×4×10 = 10N. F_net = 20−10 = 10N. a = 10/4 = 2.5 m/s²" },
    { q: "A force of 30N gives a 6kg object an acceleration of 4 m/s². Find the frictional force.", a: "F_net = ma = 6×4 = 24N. Friction = F_applied − F_net = 30−24 = 6N" },
    { q: "How long does it take a 3kg block to reach 12 m/s if pushed with 15N on a frictionless surface?", a: "a = F/m = 15/3 = 5 m/s². t = v/a = 12/5 = 2.4s" },
  ],
  '3rd': [
    { q: "A 70kg person stands on a 500kg boat and pushes the boat with 100N. Find both accelerations.", a: "Both experience 100N. Person: a=100/70=1.43 m/s² backward. Boat: a=100/500=0.2 m/s² forward." },
    { q: "A rocket of mass 2000kg expels gas producing 40,000N thrust. Find the rocket's acceleration.", a: "a = F/m = 40000/2000 = 20 m/s². (Ignoring gravity and changing mass for simplicity.)" },
    { q: "Why does a gun recoil when fired? Use Newton's 3rd Law.", a: "The gun exerts force on bullet (action, bullet moves forward). Bullet exerts equal and opposite force on gun (reaction, gun recoils backward). Forces equal, but gun's larger mass means smaller acceleration." },
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

export default function NewtonsLawsPage() {
  const [law, setLaw] = useState<Law>('1st');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);
  const [graphType, setGraphType] = useState<GraphType>('v');
  // Live marker position only — the curve itself is precomputed up front
  // (see the ghost-trajectory useMemos below) and shown in full immediately,
  // so this just tracks "where on that curve are we right now".
  const [live1st, setLive1st] = useState({ t: 0, v: 0, a: 0, x: 0 });
  const [live2nd, setLive2nd] = useState({ t: 0, v: 0, a: 0, x: 0 });
  const [live3rd, setLive3rd] = useState({ t: 0, v1: 0, v2: 0 });

  // 1st law params
  const [mass1, setMass1] = useState(5);
  const [friction1, setFriction1] = useState(0);
  const [initV, setInitV] = useState(5);
  const [forceOn, setForceOn] = useState(false);
  const [force1, setForce1] = useState(10);

  // 2nd law params
  const [mass2, setMass2] = useState(5);
  const [applied, setApplied] = useState(30);
  const [friction2, setFriction2] = useState(0.2);

  // 3rd law params
  const [mass3a, setMass3a] = useState(5);
  const [mass3b, setMass3b] = useState(10);
  const [force3, setForce3] = useState(20);
  const [scenario3, setScenario3] = useState<Scenario3>('push');

  const secAnalytics = secondLawAnalytics({ mass: mass2, appliedForce: applied, friction: friction2 });
  const thdAnalytics = thirdLawAnalytics({ type: scenario3, mass1: mass3a, mass2: mass3b, force: force3 });

  // Stable object identity: without this, every graph tick (setGraphData)
  // re-renders the page and recreates this object as a new reference, which
  // re-triggers NewtonsSecondCanvas's reset effect on every single frame —
  // snapping the block back to the start each tick ("vibrating on the
  // spot") and collapsing the graph's time axis back near 0 repeatedly.
  const secondLawParams = useMemo(
    () => ({ mass: mass2, appliedForce: applied, friction: friction2 }),
    [mass2, applied, friction2]
  );

  // Precomputed "ghost" curves — the whole predicted picture, available the
  // instant a slider changes, before Run is ever pressed.
  const firstLawGhost = useMemo(
    () => firstLawTrajectory(mass1, friction1, initV, forceOn, force1),
    [mass1, friction1, initV, forceOn, force1]
  );
  const secondLawGhost = useMemo(() => secondLawTrajectory(secondLawParams), [secondLawParams]);
  const thirdLawGhost = useMemo(
    () => thirdLawTrajectory(scenario3, mass3a, mass3b, force3),
    [scenario3, mass3a, mass3b, force3]
  );

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastTickRef = useRef(0);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setLive1st({ t: 0, v: 0, a: 0, x: 0 });
    setLive2nd({ t: 0, v: 0, a: 0, x: 0 });
    setLive3rd({ t: 0, v1: 0, v2: 0 });
    lastTickRef.current = 0;
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [law, mass1, friction1, initV, force1, mass2, applied, friction2, mass3a, mass3b, force3, scenario3, reset]);

  const handle1stTick = useCallback((s: FirstLawState) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    const a = firstLawAcceleration(s.v, mass1, friction1, forceOn ? force1 : 0);
    setLive1st({ t: s.time, v: s.v, a, x: s.x });
  }, [mass1, friction1, forceOn, force1]);

  const handle2ndTick = useCallback((s: SecondLawState) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    setLive2nd({ t: s.time, v: s.v, a: s.a, x: s.x });
  }, []);

  const handle3rdTick = useCallback((t: number, v1: number, v2: number) => {
    const now = performance.now();
    if (now - lastTickRef.current < 40) return;
    lastTickRef.current = now;
    setLive3rd({ t, v1, v2 });
  }, []);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 210, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics</p>
                <h1 className="text-lg font-semibold text-gray-900">Newton&apos;s laws of motion</h1>
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

          {/* Law tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(['1st', '2nd', '3rd'] as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-4 py-2 rounded-lg text-xs font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                {LAW_META[l].title}
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{LAW_META[law].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{LAW_META[law].eq}</span>
          </div>

          {/* Main layout */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Col 1: Canvas + controls + sliders */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {law === '1st' && (
                  <NewtonsFirstCanvas
                    key={resetKey} mass={mass1} friction={friction1}
                    initialVelocity={initV} forceOn={forceOn} appliedForce={force1}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle1stTick}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
                {law === '2nd' && (
                  <NewtonsSecondCanvas
                    key={resetKey} params={secondLawParams}
                    isRunning={isRunning} isPaused={isPaused} onTick={handle2ndTick}
                    onComplete={() => { setIsComplete(true); setIsRunning(false); }}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
                {law === '3rd' && (
                  <NewtonsThirdCanvas
                    key={resetKey} mass1={mass3a} mass2={mass3b} force={force3}
                    scenario={scenario3} isRunning={isRunning} isPaused={isPaused}
                    onTick={handle3rdTick}
                    width={canvasSize.width} height={canvasSize.height}
                  />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning && !isComplete} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
              </div>

              {/* Live graph — full predicted curve shown immediately, with a
                  live marker riding along it as the animation plays. */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <div className="flex items-center justify-between mb-3">
                  <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">
                    {law === '3rd' ? 'Velocity graph' : 'Live graph'}
                  </p>
                  {law !== '3rd' && (
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg">
                      {(['v', 'a', 'x'] as GraphType[]).map(g => (
                        <button key={g} onClick={() => setGraphType(g)}
                          className={`px-3 py-1 rounded-md text-xs font-medium transition ${
                            graphType === g ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{g === 'v' ? 'Velocity' : g === 'a' ? 'Acceleration' : 'Displacement'}</button>
                      ))}
                    </div>
                  )}
                </div>
                {law === '1st' && (
                  <NewtonsGraph data={firstLawGhost} show={graphType} liveT={live1st.t} liveValue={live1st[graphType]} />
                )}
                {law === '2nd' && (
                  <NewtonsGraph data={secondLawGhost} show={graphType} liveT={live2nd.t} liveValue={live2nd[graphType]} />
                )}
                {law === '3rd' && (() => {
                  const rocketA = force3 / mass3a;
                  const wrappedT = scenario3 === 'rocket' ? live3rd.t % ROCKET_GRAPH_DURATION : live3rd.t;
                  const wrappedV1 = scenario3 === 'rocket' ? rocketA * wrappedT : live3rd.v1;
                  return (
                    <ThirdLawGraph data={thirdLawGhost} scenario={scenario3}
                      liveT={wrappedT} liveV1={wrappedV1} liveV2={live3rd.v2} />
                  );
                })()}
              </div>

              {law === '3rd' && (
                <p className="text-[10px] text-gray-400 -mt-2 px-1">
                  {scenario3 === 'rocket'
                    ? 'Rocket velocity keeps climbing as fuel burns — this graph loops to show the same constant-acceleration shape each cycle.'
                    : 'Same force, different acceleration: the lighter object always reaches a larger speed by the time contact ends.'}
                </p>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {law === '1st' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass1} min={1} max={20} step={0.5} set={setMass1} color="#6366f1" />
                    <Slider label="Initial velocity" unit="m/s" value={initV} min={0} max={20} step={0.5} set={setInitV} color="#f59e0b" />
                    <Slider label="Friction coefficient μ" unit="" value={friction1} min={0} max={0.8} step={0.01} set={setFriction1} color="#ef4444" note="0 = frictionless surface" />
                    <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                      <div>
                        <p className="text-xs font-medium text-gray-700">Applied force</p>
                        <p className="text-[10px] text-gray-400">Toggle to show Newton&apos;s 1st law</p>
                      </div>
                      <button onClick={() => setForceOn(f => !f)}
                        className={`relative w-11 h-6 rounded-full transition ${forceOn ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                        <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${forceOn ? 'translate-x-5' : ''}`} />
                      </button>
                    </div>
                    {forceOn && (
                      <Slider label="Force" unit="N" value={force1} min={1} max={50} step={1} set={setForce1} color="#10b981" />
                    )}
                  </>
                )}

                {law === '2nd' && (
                  <>
                    <Slider label="Mass" unit="kg" value={mass2} min={1} max={20} step={0.5} set={setMass2} color="#6366f1" />
                    <Slider label="Applied force" unit="N" value={applied} min={1} max={100} step={1} set={setApplied} color="#10b981" />
                    <Slider label="Friction coefficient μ" unit="" value={friction2} min={0} max={0.8} step={0.01} set={setFriction2} color="#ef4444" note="0 = frictionless" />
                  </>
                )}

                {law === '3rd' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['push', 'rocket', 'collision'] as Scenario3[]).map(s => (
                        <button key={s} onClick={() => setScenario3(s)}
                          className={`py-1.5 rounded-lg text-xs font-medium capitalize transition ${
                            scenario3 === s ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{s}</button>
                      ))}
                    </div>
                    <Slider label="Object 1 mass" unit="kg" value={mass3a} min={1} max={50} step={1} set={setMass3a} color="#6366f1" />
                    <Slider label="Object 2 mass" unit="kg" value={mass3b} min={1} max={50} step={1} set={setMass3b} color="#10b981" />
                    <Slider label="Interaction force" unit="N" value={force3} min={5} max={100} step={5} set={setForce3} color="#f59e0b" />
                  </>
                )}
              </div>
            </div>

            {/* Col 2: Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {law === '1st' && [
                    { l: 'Mass', v: `${mass1} kg`, c: 'text-indigo-600' },
                    { l: 'Initial velocity', v: `${initV} m/s`, c: 'text-amber-600' },
                    { l: 'Friction (μ)', v: friction1.toFixed(2), c: 'text-red-500' },
                    { l: 'Friction force', v: `${(friction1 * mass1 * 9.81).toFixed(1)} N`, c: 'text-red-400' },
                    { l: 'Net force', v: forceOn ? `${(force1 - friction1 * mass1 * 9.81).toFixed(1)} N` : `${(friction1 * mass1 * 9.81 * -1).toFixed(1)} N`, c: 'text-gray-700' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '2nd' && [
                    { l: 'Applied force', v: `${applied} N`, c: 'text-emerald-600' },
                    { l: 'Friction force', v: `${secAnalytics.frictionForce} N`, c: 'text-red-500' },
                    { l: 'Net force', v: `${secAnalytics.netForce} N`, c: 'text-indigo-600' },
                    { l: 'Acceleration', v: `${secAnalytics.acceleration} m/s²`, c: 'text-amber-600' },
                    { l: 'F = ma check', v: `${secAnalytics.netForce} = ${mass2}×${secAnalytics.acceleration}`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {law === '3rd' && [
                    { l: 'Action force', v: `${force3} N`, c: 'text-emerald-600' },
                    { l: 'Reaction force', v: `−${force3} N`, c: 'text-red-500' },
                    { l: `a₁ (${mass3a}kg)`, v: `${thdAnalytics.a1.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: `a₂ (${mass3b}kg)`, v: `${thdAnalytics.a2.toFixed(2)} m/s²`, c: 'text-amber-600' },
                    { l: 'Force equal?', v: 'Yes — always', c: 'text-emerald-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Curriculum */}
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

            {/* Col 3: Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[law].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
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

echo "  → src/app/simulations/oscillations/page.tsx"
cat > "src/app/simulations/oscillations/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { PendulumCanvas } from '@/components/simulation/PendulumCanvas';
import { SpringCanvas } from '@/components/simulation/SpringCanvas';
import { ConicalPendulumCanvas } from '@/components/simulation/ConicalPendulumCanvas';
import { PhysicalPendulumCanvas } from '@/components/simulation/PhysicalPendulumCanvas';
import { BifilarCanvas } from '@/components/simulation/BifilarCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { SHMGraph } from '@/components/simulation/SHMGraph';
import {
  pendulumOmega, pendulumPeriod,
  springOmega, springPeriod, springStaticExtension,
  conicalPendulumOmega, conicalPendulumPeriod, conicalPendulumTension, conicalPendulumSpeed,
  physicalPendulumPeriod, rodPendulumPeriod,
  bifilarPeriodSimple, cantileverStiffness, cantileverDeflection, cantileverPeriod,
} from '@/lib/physics/shm';

type Topic = 'pendulum' | 'spring' | 'conical' | 'physical' | 'bifilar';
type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  pendulum: { title: 'Simple pendulum',       icon: '⏱️', sub: 'SHM for small angles', eq: 'T = 2π√(L/g)' },
  spring:   { title: 'Loaded spring',         icon: '🌀', sub: 'Mass-spring system',    eq: 'T = 2π√(m/k)' },
  conical:  { title: 'Conical pendulum',      icon: '🔄', sub: 'Circular motion + tension', eq: 'ω² = g/(L cosθ)' },
  physical: { title: 'Physical pendulum',     icon: '📏', sub: 'Extended rigid body',   eq: 'T = 2π√(I/mgd)' },
  bifilar:  { title: 'Bifilar / Cantilever',  icon: '🏗️', sub: 'Torsion & beam flexure', eq: 'T = 2π√(Il/mgd²)' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  pendulum: [
    "Period T = 2π√(L/g) is INDEPENDENT of mass and amplitude (for small angles < 15°).",
    "This independence of mass is why a pendulum makes a good clock — it keeps time regardless of the bob.",
    "For large amplitudes, the period increases — the small-angle approximation (sinθ ≈ θ) breaks down.",
    "On the Moon (g=1.6 m/s²), the same pendulum runs ~2.5× slower. The gravity slider demonstrates this.",
    "A seconds pendulum (T=2s) has length L = g/π² ≈ 0.993m — almost exactly 1 metre.",
  ],
  spring: [
    "T = 2π√(m/k): period increases with mass, decreases with spring stiffness. Mass affects it; length does not.",
    "The static extension x₀ = mg/k gives the equilibrium position. SHM occurs about this point.",
    "Hooke's Law F = kx and SHM are directly linked: F = −kx gives a = −(k/m)x → ω² = k/m.",
    "Energy: at equilibrium (x=0) all energy is KE. At amplitude (x=A) all energy is PE. Total E = ½mω²A² always.",
    "The phase space graph (v vs x) is an ellipse — a perfect circle if axes are scaled to same range.",
  ],
  conical: [
    "The bob moves in a horizontal circle — this is NOT SHM, but links circular motion to pendulums.",
    "Key equations: T cosθ = mg (vertical), T sinθ = mω²r (horizontal). Dividing: tanθ = ω²r/g.",
    "As ω increases, θ increases (bob rises). As θ → 90°, r → L and ω → ∞ (impossible in practice).",
    "Period decreases as angle increases: T = 2π√(L cosθ / g). Faster spin = shorter period.",
    "Good link to centripetal force: the horizontal component of tension provides centripetal force.",
  ],
  physical: [
    "A physical pendulum uses the full rigid-body rotation: T = 2π√(I/mgd) where I is about the pivot.",
    "For a uniform rod pivoted at the end: I = mL²/3, d = L/2 → T = 2π√(2L/3g). Compare to simple T = 2π√(L/g).",
    "The physical pendulum always has a longer period than the simple pendulum of the same length.",
    "There are two pivot points that give the same period — the 'centre of oscillation' concept used in precision timing.",
    "The equivalent simple pendulum length L_eq = I/(md). This is what IGCSE/JUPEB exam questions test.",
  ],
  bifilar: [
    "Bifilar suspension: a rod hung by two parallel wires undergoes TORSIONAL oscillation (twisting).",
    "T = (2π/d)√(Il/mg) where d = half wire separation, l = wire length, I = moment of inertia.",
    "Used to measure moment of inertia experimentally: measure T, know l and d, solve for I.",
    "Cantilever beam: one end fixed, free end deflects under load. Stiffness k = 3EI/L³.",
    "Cantilever vibration period T = 2π√(m_eff/k). The effective mass ≈ 0.24 × beam mass + tip mass.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  pendulum: [
    { q: "A pendulum has period 2s on Earth (g=9.81 m/s²). Find its length.", a: "T=2π√(L/g) → L=g(T/2π)²=9.81×(2/2π)²=9.81×0.1013=0.993m ≈ 1m" },
    { q: "A 2m pendulum is taken to a planet where g=4 m/s². Find the new period.", a: "T=2π√(L/g)=2π√(2/4)=2π×0.707=4.44s" },
    { q: "Why does doubling the mass of a pendulum bob not change its period?", a: "Both restoring force and inertia scale with mass, so they cancel in the period equation T=2π√(L/g) — mass doesn't appear." },
  ],
  spring: [
    { q: "A 0.5kg mass on a spring of k=200 N/m. Find period and frequency.", a: "T=2π√(m/k)=2π√(0.5/200)=2π×0.05=0.314s. f=1/T=3.18Hz" },
    { q: "A spring extends 0.05m under a 2kg load (g=10 m/s²). Find k and the SHM period.", a: "k=F/x=mg/x=20/0.05=400 N/m. T=2π√(2/400)=2π×0.0707=0.444s" },
    { q: "A spring-mass system has total energy 0.4J and amplitude 0.1m. Find the spring constant k.", a: "E=½kA² → k=2E/A²=2×0.4/0.01=80 N/m" },
  ],
  conical: [
    { q: "A conical pendulum of length 0.5m makes angle 30° with vertical. Find ω and period. (g=10)", a: "ω=√(g/Lcosθ)=√(10/0.5×cos30°)=√(10/0.433)=√23.1=4.81 rad/s. T=2π/ω=1.31s" },
    { q: "Find the tension in the string of a 0.2kg bob at θ=45°. (g=10)", a: "T=mg/cosθ=0.2×10/cos45°=2/0.707=2.83N" },
    { q: "As the angular velocity of a conical pendulum increases, what happens to the angle θ?", a: "θ increases — the bob rises outward. Since ω²=g/(Lcosθ), larger ω requires smaller cosθ, meaning larger θ." },
  ],
  physical: [
    { q: "A uniform rod of length 1.2m and mass 0.5kg is pivoted at one end. Find the period. (g=9.81)", a: "I=mL²/3=0.5×1.44/3=0.24 kg·m². d=L/2=0.6m. T=2π√(I/mgd)=2π√(0.24/0.5×9.81×0.6)=2π×0.285=1.79s" },
    { q: "Compare this to a simple pendulum of the same length.", a: "T_simple=2π√(1.2/9.81)=2π×0.350=2.20s. The physical pendulum (1.79s) is FASTER — its effective length is 2L/3=0.8m, shorter than L." },
    { q: "What is the equivalent simple pendulum length for a uniform rod pivoted at one end?", a: "L_eq=I/(md)=(mL²/3)/(m×L/2)=2L/3. For L=1.2m: L_eq=0.8m." },
  ],
  bifilar: [
    { q: "A 2kg rod (L=0.6m) hangs on wires of length 1m, separation 0.4m. Find the period.", a: "I=mL²/12=2×0.36/12=0.06 kg·m². T=2π√(Il/mgd²)=2π√(0.06×1/2×9.81×0.04)=2π√(0.0765)=2π×0.277=1.74s" },
    { q: "A cantilever beam: E=200GPa, b=30mm, h=5mm, L=0.5m. Find stiffness k.", a: "I_beam=bh³/12=0.03×(0.005)³/12=3.125×10⁻¹⁰m⁴. k=3EI/L³=3×200×10⁹×3.125×10⁻¹⁰/0.125=1500 N/m" },
    { q: "Why is bifilar suspension used to measure moment of inertia experimentally?", a: "The period T=(2π/d)√(Il/mg) can be rearranged to I=mgd²T²/(4π²l). By measuring T and knowing all other quantities, I is found without needing to integrate over the shape." },
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

export default function OscillationsPage() {
  const [topic, setTopic] = useState<Topic>('pendulum');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'JUPEB']);
  const [graphMode, setGraphMode] = useState<GraphMode>('displacement');
  const [currentT, setCurrentT] = useState(0);

  // Pendulum params
  const [pendL, setPendL] = useState(1.0);
  const [pendA, setPendA] = useState(15);
  const [pendG, setPendG] = useState(9.81);
  const [pendM, setPendM] = useState(0.5);

  // Spring params
  const [spK, setSpK] = useState(50);
  const [spM, setSpM] = useState(1.0);
  const [spA, setSpA] = useState(0.1);

  // Conical params
  const [conL, setConL] = useState(0.8);
  const [conTheta, setConTheta] = useState(30);
  const [conM, setConM] = useState(0.3);

  // Physical pendulum params
  const [physL, setPhysL] = useState(1.0);
  const [physM, setPhysM] = useState(0.5);
  const [physPF, setPhysPF] = useState(0); // pivot fraction from top (0=top end, 0.5=centre)

  // Bifilar/Cantilever params
  const [bifMode, setBifMode] = useState<'bifilar' | 'cantilever'>('bifilar');
  const [bifM, setBifM] = useState(2);
  const [bifL, setBifL] = useState(0.6);
  const [bifWire, setBifWire] = useState(1.0);
  const [bifSep, setBifSep] = useState(0.3);
  const [cantL, setCantL] = useState(0.5);
  const [cantH, setCantH] = useState(10); // mm
  const [cantLoad, setCantLoad] = useState(5);

  // Derived analytics
  const pendOmega = pendulumOmega(pendL, pendG);
  const pendT = pendulumPeriod(pendL, pendG);
  const spOmega = springOmega(spK, spM);
  const spT = springPeriod(spK, spM);
  const spStaticX = springStaticExtension(spM, spK);
  const conOmega = conicalPendulumOmega(conL, conTheta * Math.PI / 180);
  const conT = conicalPendulumPeriod(conL, conTheta * Math.PI / 180);
  const conTens = conicalPendulumTension(conM, conTheta * Math.PI / 180);
  const conSpeed = conicalPendulumSpeed(conL, conTheta * Math.PI / 180);
  // Pivot-dependent — must mirror PhysicalPendulumCanvas exactly, otherwise
  // the graph's ω differs from the canvas's ω whenever the pivot slider moves
  // and the live dot drifts off the rod's motion.
  const physD = Math.max(Math.abs(physL / 2 - physPF * physL), 0.001);
  const physI = physM * physL * physL / 12 + physM * physD * physD;
  const physT_actual = physicalPendulumPeriod(physI, physM, physD);
  const physT_simple = rodPendulumPeriod(physL);
  const bifT = bifilarPeriodSimple(bifM, bifL, bifWire, bifSep / 2);
  const cantK = cantileverStiffness(200e9, 0.03, cantH / 1000, cantL);
  const cantDef = cantileverDeflection(cantLoad, 200e9, 0.03, cantH / 1000, cantL);
  const cantT = cantileverPeriod(1, 200e9, 0.03, cantH / 1000, cantL);

  // Graph data — omega/A must match what the canvas actually animates so the
  // live dot on the curve tracks the mass/bob/rod exactly.
  const bifOmega = bifMode === 'bifilar' ? 2 * Math.PI / bifT : 2 * Math.PI / cantT;
  const graphA = topic === 'pendulum' ? pendA * Math.PI / 180 * pendL :
                 topic === 'spring' ? spA :
                 topic === 'physical' ? 0.25 :          // rad — canvas uses A_rad = 0.25
                 bifMode === 'bifilar' ? 0.3 :           // rad — bifilar canvas uses 0.3
                 0.3 * cantDef;                          // m — cantilever tip oscillates ±0.3·δ
  const graphOmega = topic === 'pendulum' ? pendOmega :
                     topic === 'spring' ? spOmega :
                     topic === 'physical' ? 2 * Math.PI / physT_actual :
                     bifOmega;
  const graphM = topic === 'pendulum' ? pendM : topic === 'spring' ? spM :
                 topic === 'physical' ? physM : bifM;
  const graphK = topic === 'pendulum' ? pendM * pendOmega * pendOmega :
                 topic === 'spring' ? spK :
                 graphM * graphOmega * graphOmega;

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setResetKey(k => k + 1); setCurrentT(0);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, pendL, pendA, pendG, pendM, spK, spM, spA, conL, conTheta, conM, physL, physM, physPF, bifM, bifL, bifWire, bifSep, cantL, cantH, cantLoad, bifMode, reset]);

  // Throttle marker updates to ~12fps. Updating React state on every
  // animation frame re-rendered the whole page (and the Recharts graph)
  // 60+ times a second — the graph would visibly stutter and lag behind
  // the canvas. The canvas itself animates via its own rAF loop and is
  // unaffected by this throttle.
  const lastTickRef = useRef(0);
  const handleTick = useCallback((t: number) => {
    const now = performance.now();
    if (now - lastTickRef.current > 40) {
      lastTickRef.current = now;
      setCurrentT(t);
    }
  }, []);

  // Each topic was tuned with its own aspect ratio (spring is a tall,
  // portrait-ish demo; the others are wider) — pick the matching base
  // before scaling it up to fill the available width.
  const oscBase = topic === 'spring' ? { w: 280, h: 320 }
    : topic === 'bifilar' ? { w: 380, h: 280 }
    : { w: 380, h: 300 };
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, oscBase.w, oscBase.h, 650);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mechanics — Oscillations</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple Harmonic Motion</h1>
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

          {/* Topic tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); setGraphMode('displacement'); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span>
                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
            {topic !== 'conical' && (
              <span className="text-xs text-gray-400 ml-2">a = −ω²x &nbsp;|&nbsp; x = A cos(ωt)</span>
            )}
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + graph + controls + sliders */}
            <div className="space-y-3 min-w-0">

              {/* Canvas */}
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {topic === 'pendulum' && (
                  <PendulumCanvas key={resetKey} length={pendL} amplitude={pendA}
                    gravity={pendG} mass={pendM}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'spring' && (
                  <SpringCanvas key={resetKey} k={spK} mass={spM} amplitude={spA}
                    isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'conical' && (
                  <ConicalPendulumCanvas key={resetKey} length={conL} theta_deg={conTheta}
                    mass={conM} isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'physical' && (
                  <PhysicalPendulumCanvas key={resetKey} length={physL} mass={physM}
                    pivotFraction={physPF} isRunning={isRunning} isPaused={isPaused}
                    onTick={(t) => handleTick(t)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'bifilar' && (
                  <div className="space-y-2">
                    <div className="flex gap-1 bg-gray-100 p-1 rounded-xl w-fit">
                      {(['bifilar', 'cantilever'] as const).map(m => (
                        <button key={m} onClick={() => setBifMode(m)}
                          className={`px-4 py-1.5 rounded-lg text-xs font-medium transition capitalize ${
                            bifMode === m ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{m}</button>
                      ))}
                    </div>
                    <BifilarCanvas key={`${resetKey}-${bifMode}`}
                      mode={bifMode} mass={bifM} rodLength={bifL}
                      wireLength={bifWire} separation={bifSep}
                      beamLength={cantL} beamWidth={30} beamHeight={cantH}
                      youngModulus={200} load={cantLoad}
                      isRunning={isRunning} isPaused={isPaused}
                      onTick={(t) => handleTick(t)}
                      width={canvasSize.width} height={canvasSize.height} />
                  </div>
                )}
              </div>

              {/* Controls */}
              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls
                  isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)}
                  onReset={reset}
                />
                {topic !== 'bifilar' && (
                  <EmbedButton
                    path="/embed/oscillations"
                    title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                    params={
                      topic === 'pendulum' ? { topic, L: pendL, A: pendA, g: pendG, m: pendM } :
                      topic === 'spring'   ? { topic, k: spK, m: spM, A: spA } :
                      topic === 'conical'  ? { topic, L: conL, theta: conTheta, m: conM } :
                      { topic, L: physL, m: physM, pf: physPF }
                    }
                  />
                )}
              </div>

              {/* Graph */}
              {topic !== 'conical' && (
                <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between mb-3 flex-wrap gap-2">
                    <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Graph</p>
                    <div className="flex gap-1 bg-gray-100 p-0.5 rounded-lg overflow-x-auto">
                      {(['displacement', 'velocity', 'acceleration', 'energy', 'phase'] as GraphMode[]).map(gm => (
                        <button key={gm} onClick={() => setGraphMode(gm)}
                          className={`shrink-0 px-2.5 py-1 rounded-md text-[10px] font-medium transition ${
                            graphMode === gm ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>
                          {gm === 'displacement' ? 'x–t' : gm === 'velocity' ? 'v–t' : gm === 'acceleration' ? 'a–t' : gm === 'energy' ? 'Energy' : 'Phase (v–x)'}
                        </button>
                      ))}
                    </div>
                  </div>
                  <SHMGraph A={graphA} omega={graphOmega} m={graphM} k={graphK}
                    mode={graphMode} currentT={currentT} />
                  <p className="text-[10px] text-gray-400 mt-2 text-center">
                    {graphMode === 'displacement' && 'Cosine wave — starts at +A, returns to +A each period T'}
                    {graphMode === 'velocity' && 'Sine wave — 90° ahead of displacement. Maximum at x=0'}
                    {graphMode === 'acceleration' && 'Cosine wave — always opposite to displacement (a = −ω²x)'}
                    {graphMode === 'energy' && 'KE and PE exchange; total energy E = ½mω²A² = constant (dashed)'}
                    {graphMode === 'phase' && 'Ellipse in phase space — SHM traces a closed orbit'}
                  </p>
                </div>
              )}

              {/* Sliders */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'pendulum' && <>
                  <Slider label="Length" unit="m" value={pendL} min={0.1} max={3} step={0.05} set={setPendL} color="#6366f1" />
                  <Slider label="Amplitude" unit="°" value={pendA} min={2} max={30} step={1} set={setPendA} color="#f59e0b" note="Keep < 15° for accurate SHM" />
                  <Slider label="Mass" unit="kg" value={pendM} min={0.1} max={2} step={0.1} set={setPendM} color="#94a3b8" note="Does not affect period" />
                  <Slider label="Gravity" unit="m/s²" value={pendG} min={1.6} max={25} step={0.1} set={setPendG} color="#10b981" note="Moon=1.6  Earth=9.81  Jupiter=24.8" />
                </>}

                {topic === 'spring' && <>
                  <Slider label="Spring constant k" unit="N/m" value={spK} min={5} max={500} step={5} set={setSpK} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={spM} min={0.1} max={5} step={0.1} set={setSpM} color="#f59e0b" />
                  <Slider label="Amplitude" unit="m" value={spA} min={0.01} max={0.3} step={0.01} set={setSpA} color="#10b981" note="Must be less than static extension" />
                </>}

                {topic === 'conical' && <>
                  <Slider label="String length" unit="m" value={conL} min={0.2} max={2} step={0.05} set={setConL} color="#6366f1" />
                  <Slider label="Half-angle θ" unit="°" value={conTheta} min={5} max={75} step={1} set={setConTheta} color="#f59e0b" />
                  <Slider label="Mass" unit="kg" value={conM} min={0.1} max={1} step={0.05} set={setConM} color="#10b981" />
                </>}

                {topic === 'physical' && <>
                  <Slider label="Rod length" unit="m" value={physL} min={0.2} max={2} step={0.05} set={setPhysL} color="#6366f1" />
                  <Slider label="Mass" unit="kg" value={physM} min={0.1} max={2} step={0.1} set={setPhysM} color="#f59e0b" />
                  <Slider label="Pivot position (fraction from top)" unit="" value={physPF} min={0} max={0.45} step={0.05} set={setPhysPF} color="#10b981" note="0 = top end, 0.5 = centre (infinite period)" />
                </>}

                {topic === 'bifilar' && bifMode === 'bifilar' && <>
                  <Slider label="Rod mass" unit="kg" value={bifM} min={0.5} max={5} step={0.1} set={setBifM} color="#6366f1" />
                  <Slider label="Rod length" unit="m" value={bifL} min={0.2} max={1.5} step={0.05} set={setBifL} color="#f59e0b" />
                  <Slider label="Wire length" unit="m" value={bifWire} min={0.3} max={2} step={0.05} set={setBifWire} color="#10b981" />
                  <Slider label="Wire separation (2d)" unit="m" value={bifSep} min={0.1} max={0.8} step={0.02} set={setBifSep} color="#8b5cf6" />
                </>}

                {topic === 'bifilar' && bifMode === 'cantilever' && <>
                  <Slider label="Beam length" unit="m" value={cantL} min={0.1} max={1} step={0.05} set={setCantL} color="#6366f1" />
                  <Slider label="Beam height (thickness)" unit="mm" value={cantH} min={2} max={20} step={1} set={setCantH} color="#f59e0b" />
                  <Slider label="End load" unit="N" value={cantLoad} min={0} max={50} step={1} set={setCantLoad} color="#ef4444" />
                </>}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'pendulum' && [
                    { l: 'Angular freq ω', v: `${pendOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${pendT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/pendT).toFixed(3)} Hz`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(pendA * Math.PI/180 * pendL * pendOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Max acceleration', v: `${(pendA * Math.PI/180 * pendL * pendOmega**2).toFixed(3)} m/s²`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'spring' && [
                    { l: 'Angular freq ω', v: `${spOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${spT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Static extension', v: `${spStaticX.toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'Max velocity', v: `${(spA * spOmega).toFixed(3)} m/s`, c: 'text-rose-500' },
                    { l: 'Total energy', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-purple-600' },
                    { l: 'Max KE = Max PE', v: `${(0.5 * spK * spA * spA).toFixed(4)} J`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'conical' && [
                    { l: 'Angular velocity ω', v: `${conOmega.toFixed(3)} rad/s`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${conT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Orbital radius r', v: `${(conL * Math.sin(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-amber-600' },
                    { l: 'String tension T', v: `${conTens.toFixed(3)} N`, c: 'text-rose-500' },
                    { l: 'Orbital speed v', v: `${conSpeed.toFixed(3)} m/s`, c: 'text-purple-600' },
                    { l: 'Vertical height', v: `${(conL * Math.cos(conTheta*Math.PI/180)).toFixed(3)} m`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'physical' && [
                    { l: 'I (about pivot)', v: `${physI.toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period (physical)', v: `${physT_actual.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Period (simple, same L)', v: `${physT_simple.toFixed(3)} s`, c: 'text-amber-600' },
                    { l: 'Equiv. simple length', v: `${(physI/(physM*physD)).toFixed(3)} m`, c: 'text-rose-500' },
                    { l: 'Ratio T_phys/T_simple', v: `${(physT_actual/physT_simple).toFixed(3)}`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'bifilar' && [
                    { l: 'I (rod)', v: `${(bifM*bifL**2/12).toFixed(4)} kg·m²`, c: 'text-indigo-600' },
                    { l: 'Period T', v: `${bifT.toFixed(3)} s`, c: 'text-emerald-600' },
                    { l: 'Frequency f', v: `${(1/bifT).toFixed(3)} Hz`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'bifilar' && bifMode === 'cantilever' && [
                    { l: 'Stiffness k', v: `${cantK.toFixed(0)} N/m`, c: 'text-indigo-600' },
                    { l: 'Deflection δ', v: `${(cantDef*1000).toFixed(2)} mm`, c: 'text-emerald-600' },
                    { l: 'Nat. frequency', v: `${(1/cantT).toFixed(2)} Hz`, c: 'text-amber-600' },
                    { l: 'Period T', v: `${cantT.toFixed(3)} s`, c: 'text-rose-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
                </div>
              </div>

              {/* Curriculum */}
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

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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

echo "  → src/app/simulations/gas-laws/page.tsx"
cat > "src/app/simulations/gas-laws/page.tsx" << 'AFEOF'
'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { BoylesCanvas } from '@/components/simulation/BoylesCanvas';
import { CharlesCanvas } from '@/components/simulation/CharlesCanvas';
import { PressureLawCanvas } from '@/components/simulation/PressureLawCanvas';
import { IdealGasCanvas } from '@/components/simulation/IdealGasCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { GasLawGraph } from '@/components/simulation/GasLawGraph';
import {
  idealGasPressure, idealGasVolume, idealGasMoles, idealGasTemperature,
  charlesNewVolume, pressureLawNewPressure, VAN_DER_WAALS,
} from '@/lib/physics/gas-laws';

type Law = 'boyle' | 'charles' | 'pressure' | 'ideal' | 'real';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const LAW_META: Record<Law, { title: string; equation: string; condition: string; graphLabel: string; graphDesc: string }> = {
  boyle:    { title: "Boyle's Law",    equation: 'P₁V₁ = P₂V₂',   condition: 'constant T, n',            graphLabel: 'P–V graph',           graphDesc: 'Hyperbolic isotherm. Yellow dot = current state.' },
  charles:  { title: "Charles' Law",   equation: 'V₁/T₁ = V₂/T₂', condition: 'constant P, n — T in K',  graphLabel: 'V–T graph',           graphDesc: 'Straight line → 0 K. Yellow dot = current state.' },
  pressure: { title: 'Pressure Law',   equation: 'P₁/T₁ = P₂/T₂', condition: 'constant V, n — T in K',  graphLabel: 'P–T graph',           graphDesc: 'Straight line → 0 K. Pressure rises with temperature.' },
  ideal:    { title: 'Ideal Gas Law',  equation: 'PV = nRT',        condition: 'R = 8.314 J mol⁻¹ K⁻¹', graphLabel: 'P–V isotherms',       graphDesc: 'Three isotherms at different mole counts. All obey PV = nRT.' },
  real:     { title: 'Real Gases',     equation: '(P + an²/V²)(V − nb) = nRT', condition: 'Van der Waals equation', graphLabel: 'Compressibility (Z vs P)', graphDesc: 'Z = PV/nRT. Ideal gas Z = 1 always. Real gases deviate at high pressure.' },
};

const TEACHER_NOTES: Record<Law, string[]> = {
  boyle: [
    "Boyle's Law: at constant T, pressure and volume are inversely proportional — P₁V₁ = P₂V₂.",
    "The P–V graph is a hyperbola. Each curve (isotherm) represents a different temperature.",
    "Higher temperature isotherms sit above lower ones — more energy means higher pressure at same volume.",
    "Real gases deviate from this at very high pressures or near condensation.",
    "Ask: what happens to particles when volume decreases? Why does pressure increase?",
  ],
  charles: [
    "Charles' Law: at constant P, volume is proportional to absolute temperature — V₁/T₁ = V₂/T₂.",
    "Temperature MUST be in Kelvin. 0°C is not zero molecular motion — 0 K is.",
    "Extended to 0 K, the V–T graph passes through the origin — this is how absolute zero was estimated.",
    "A gas at 0 K would have zero volume — impossible for real gases (they liquefy first).",
    "Ask: why do hot air balloons rise? Why do car tyres stiffen in cold weather?",
  ],
  pressure: [
    "Pressure Law (Gay-Lussac): at constant V, pressure is proportional to T — P₁/T₁ = P₂/T₂.",
    "This is what happens in rigid sealed containers like pressure cookers and aerosol cans.",
    "NEVER heat a sealed rigid container — pressure rises until it ruptures.",
    "The P–T graph is a straight line through 0 K, just like Charles' Law.",
    "Combined with Boyle's and Charles' Law, this gives the ideal gas law: PV = nRT.",
  ],
  ideal: [
    "The ideal gas law PV = nRT unifies Boyle's, Charles', and the Pressure Law into one equation.",
    "R = 8.314 J mol⁻¹ K⁻¹ is the universal gas constant — the same for every gas.",
    "An ideal gas has no intermolecular forces and particles occupy zero volume.",
    "Use the calculator: input any 3 of P, V, n, T and solve for the 4th.",
    "At standard conditions (STP: 0°C, 100 kPa), 1 mol of ideal gas occupies 22.4 L.",
  ],
  real: [
    "Real gases deviate from ideal behaviour due to: (1) intermolecular attractions and (2) finite particle volume.",
    "The Van der Waals equation corrects for both: (P + an²/V²)(V − nb) = nRT. 'a' corrects for attractions; 'b' for particle volume.",
    "Z = PV/nRT is the compressibility factor. For ideal gas Z = 1. Real gases: Z < 1 at moderate P (attractions dominate), Z > 1 at high P (volume dominates).",
    "CO₂ and NH₃ show strong deviation (large 'a') — they have strong intermolecular forces.",
    "Helium and H₂ are nearly ideal — small, non-polar molecules with weak forces.",
  ],
};

const EXERCISES: Record<Law, { q: string; a: string }[]> = {
  boyle: [
    { q: "A gas at 200 kPa occupies 4 L. Find the volume at 400 kPa (constant T).", a: "V₂ = P₁V₁/P₂ = (200×4)/400 = 2 L" },
    { q: "A gas at 100 kPa occupies 8 L. Find the pressure at 2 L.", a: "P₂ = P₁V₁/V₂ = (100×8)/2 = 400 kPa" },
    { q: "Why is the P–V graph a hyperbola and not a straight line?", a: "P and V are inversely proportional (PV = constant), so plotting one against the other gives a rectangular hyperbola." },
  ],
  charles: [
    { q: "A gas occupies 3 L at 300 K. Find its volume at 600 K (constant P).", a: "V₂ = V₁T₂/T₁ = (3×600)/300 = 6 L" },
    { q: "A balloon is 2 L at 27°C. Find volume at 127°C.", a: "T₁=300K, T₂=400K → V₂ = (2×400)/300 = 2.67 L" },
    { q: "Why must temperature be in Kelvin for gas law calculations?", a: "Kelvin measures absolute thermal energy starting from 0 K (zero molecular motion). Celsius 0 is arbitrary — ratios in Celsius give wrong answers." },
  ],
  pressure: [
    { q: "Gas in a rigid container: 150 kPa at 300 K. Find pressure at 600 K.", a: "P₂ = P₁T₂/T₁ = (150×600)/300 = 300 kPa" },
    { q: "An aerosol can: 250 kPa at 20°C. Find pressure at 60°C.", a: "T₁=293K, T₂=333K → P₂ = (250×333)/293 ≈ 284 kPa" },
    { q: "Why is it dangerous to throw an aerosol can into a fire?", a: "Fixed volume means rising temperature causes pressure to rise proportionally — eventually exceeding the can's rated limit, causing explosion." },
  ],
  ideal: [
    { q: "Calculate the volume of 2 mol of ideal gas at 300 K and 100 kPa.", a: "V = nRT/P = (2 × 8.314 × 300) / (100×1000) = 0.0499 m³ = 49.9 L" },
    { q: "What pressure does 0.5 mol of gas exert in a 10 L container at 27°C?", a: "T=300K, V=0.01m³ → P = nRT/V = (0.5×8.314×300)/0.01 = 124,710 Pa ≈ 125 kPa" },
    { q: "At STP (0°C, 100 kPa), what volume does 1 mol of ideal gas occupy?", a: "V = nRT/P = (1×8.314×273)/(100,000) = 0.0227 m³ = 22.7 L (≈ 22.4 L)" },
  ],
  real: [
    { q: "Why does CO₂ deviate more from ideal behaviour than helium?", a: "CO₂ has stronger intermolecular attractions (large 'a' = 3.64) and larger molecular volume (larger 'b'). Helium has a = 0.034 — nearly ideal." },
    { q: "At what conditions do real gases behave most like ideal gases?", a: "High temperature and low pressure — high T means thermal energy dominates over attractions; low P means molecules are far apart and volume is negligible." },
    { q: "What does Z < 1 tell us about a real gas?", a: "Intermolecular attractions are dominant — the gas is more compressed than an ideal gas at the same conditions. Common at moderate pressures." },
  ],
};

const REAL_WORLD: Record<Law, { icon: string; text: string }[]> = {
  boyle:    [{ icon: '🤿', text: 'Scuba — gas in lungs expands as diver ascends.' }, { icon: '🩺', text: 'Breathing — diaphragm lowers volume to draw air in.' }, { icon: '💉', text: 'Syringes — reduced pressure draws in fluid.' }],
  charles:  [{ icon: '🎈', text: 'Hot air balloons — heat expands gas, reducing density.' }, { icon: '🚗', text: 'Car tyres stiffen in cold — volume decreases.' }, { icon: '🍞', text: 'Bread rising — CO₂ expands in oven heat.' }],
  pressure: [{ icon: '🥘', text: 'Pressure cooker — sealed volume means pressure rises with T.' }, { icon: '💣', text: 'Aerosol cans — never incinerate, pressure rises rapidly.' }, { icon: '🌡️', text: 'Gas thermometers measure T by pressure change at fixed V.' }],
  ideal:    [{ icon: '🏭', text: 'Industrial gas storage — engineers use PV = nRT to size tanks.' }, { icon: '🚀', text: 'Rocket propellant — gas behaviour at extreme T and P.' }, { icon: '⚗️', text: 'Lab calculations — molar volume, stoichiometry of gases.' }],
  real:     [{ icon: '❄️', text: 'Refrigerants — real gas properties essential for cooling cycles.' }, { icon: '🏗️', text: 'High-pressure pipelines — Van der Waals correction at 200+ atm.' }, { icon: '🌊', text: 'Deep-sea gas pockets — extreme P makes gas behaviour non-ideal.' }],
};

type SolveFor = 'P' | 'V' | 'n' | 'T';

export default function GasLawsPage() {
  const [law, setLaw] = useState<Law>('boyle');
  const [volume, setVolume] = useState(4);
  const [temperature, setTemperature] = useState(300);
  const [pressure, setPressure] = useState(200);
  const [moles, setMoles] = useState(0.1);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE']);
  const [selectedGas, setSelectedGas] = useState('CO2');
  const [solveFor, setSolveFor] = useState<SolveFor>('P');

  // Derived values
  const derivedP_boyle  = idealGasPressure(moles, temperature, volume) / 1000;
  const derivedV_charles = charlesNewVolume(3, 300, temperature);
  const derivedP_pressure = pressureLawNewPressure(200, 300, temperature);

  // Ideal gas solver
  const solvedValue = (() => {
    if (solveFor === 'P') return { label: 'P', value: (idealGasPressure(moles, temperature, volume) / 1000).toFixed(2), unit: 'kPa' };
    if (solveFor === 'V') return { label: 'V', value: idealGasVolume(moles, temperature, pressure).toFixed(3), unit: 'L' };
    if (solveFor === 'n') return { label: 'n', value: idealGasMoles(pressure, volume, temperature).toFixed(4), unit: 'mol' };
    return { label: 'T', value: idealGasTemperature(pressure, volume, moles).toFixed(1), unit: 'K' };
  })();

  const toggleC = (c: string) =>
    setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c]);

  const meta = LAW_META[law];

  // This card sits in a narrower grid column (alongside a graph/stats
  // column), so it gets a smaller cap than the full-width single-canvas
  // sims elsewhere in the app.
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 280, 240, 460);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-5">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-1">Thermal physics</p>
                <h1 className="text-lg sm:text-xl font-semibold text-gray-900">Gas laws</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c} onClick={() => toggleC(c)}
                    className={`text-xs px-2.5 py-1 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-5 space-y-4">

          {/* Tabs */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(LAW_META) as Law[]).map(l => (
              <button key={l} onClick={() => { setLaw(l); setOpenEx(null); }}
                className={`shrink-0 px-3 sm:px-4 py-2 rounded-lg text-xs font-medium transition ${
                  law === l ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>{LAW_META[l].title}</button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">Equation</span>
            <span className="text-sm font-semibold text-gray-900 font-mono">{meta.equation}</span>
            <span className="text-xs text-gray-400">{meta.condition}</span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">

            {/* Left: canvas / calculator */}
            <div className="space-y-3">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">
                  {law === 'boyle' ? 'Compression (constant T)' :
                   law === 'charles' ? 'Expansion (constant P)' :
                   law === 'pressure' ? 'Rigid container (constant V)' :
                   law === 'ideal' ? 'Ideal gas container' :
                   'Real vs ideal gas'}
                </p>

                {law === 'boyle'    && <BoylesCanvas volume={volume} temperature={temperature} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'charles'  && <CharlesCanvas temperature={temperature} pressure={pressure} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'pressure' && <PressureLawCanvas temperature={temperature} volume={volume} moles={moles} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'ideal'    && <IdealGasCanvas pressure={pressure} volume={volume} temperature={temperature} moles={moles} solveFor={solveFor} width={canvasSize.width} height={canvasSize.height} />}
                {law === 'real'     && (
                  <div className="space-y-3">
                    <div className="rounded-xl border border-gray-100 bg-gray-50 p-3">
                      <p className="text-xs text-gray-400 mb-2">Select gas</p>
                      <div className="grid grid-cols-2 gap-1.5">
                        {Object.entries(VAN_DER_WAALS).filter(([k]) => k !== 'ideal').map(([key, g]) => (
                          <button key={key} onClick={() => setSelectedGas(key)}
                            className={`text-xs px-2 py-1.5 rounded-lg border font-medium transition text-left ${
                              selectedGas === key ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
                            }`}>
                            <span className="font-mono">{g.formula}</span>
                            <span className="text-[10px] block opacity-70">{g.name}</span>
                          </button>
                        ))}
                      </div>
                    </div>
                    <div className="rounded-xl border border-gray-100 bg-gray-50 p-3 text-xs space-y-1.5">
                      <p className="font-medium text-gray-600">Van der Waals constants</p>
                      <div className="flex gap-4">
                        <span className="text-gray-500">a = <span className="font-mono font-medium text-gray-800">{VAN_DER_WAALS[selectedGas].a}</span> Pa·m⁶/mol²</span>
                        <span className="text-gray-500">b = <span className="font-mono font-medium text-gray-800">{VAN_DER_WAALS[selectedGas].b}</span> m³/mol</span>
                      </div>
                      <p className="text-gray-400 text-[10px]">a = intermolecular attractions · b = particle volume</p>
                    </div>
                  </div>
                )}
              </div>

              {/* Sliders / calculator */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">
                  {law === 'ideal' ? 'PV = nRT calculator' : 'Adjust parameters'}
                </p>

                {law === 'ideal' && (
                  <>
                    <div className="grid grid-cols-4 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['P', 'V', 'n', 'T'] as SolveFor[]).map(s => (
                        <button key={s} onClick={() => setSolveFor(s)}
                          className={`py-1.5 rounded-lg text-xs font-medium transition ${
                            solveFor === s ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>Solve {s}</button>
                      ))}
                    </div>
                    {solveFor !== 'P' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Pressure</span><span className="font-medium tabular-nums">{pressure} kPa</span></div>
                        <input type="range" min="10" max="1000" step="10" value={pressure} onChange={e => setPressure(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                      </div>
                    )}
                    {solveFor !== 'V' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Volume</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                        <input type="range" min="0.5" max="20" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                      </div>
                    )}
                    {solveFor !== 'n' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Moles</span><span className="font-medium tabular-nums">{moles.toFixed(2)} mol</span></div>
                        <input type="range" min="0.01" max="1" step="0.01" value={moles} onChange={e => setMoles(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                      </div>
                    )}
                    {solveFor !== 'T' && (
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                        <input type="range" min="100" max="1000" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#ef4444' }} />
                      </div>
                    )}
                    <div className="rounded-xl bg-indigo-50 px-4 py-3 text-center">
                      <p className="text-xs text-indigo-400 mb-1">Solving for {solveFor}</p>
                      <p className="text-xl font-bold text-indigo-700 font-mono">{solvedValue.value} <span className="text-sm font-normal">{solvedValue.unit}</span></p>
                    </div>
                  </>
                )}

                {law === 'boyle' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature (constant)</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                      <input type="range" min="200" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="rounded-xl bg-indigo-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-indigo-700">P = {derivedP_boyle.toFixed(1)} kPa</span>
                    </div>
                  </>
                )}

                {law === 'charles' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Pressure (constant)</span><span className="font-medium tabular-nums">{pressure} kPa</span></div>
                      <input type="range" min="50" max="500" step="10" value={pressure} onChange={e => setPressure(Number(e.target.value))} className="w-full" style={{ accentColor: '#10b981' }} />
                    </div>
                    <div className="rounded-xl bg-emerald-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-emerald-700">V = {derivedV_charles.toFixed(2)} L</span>
                    </div>
                  </>
                )}

                {law === 'pressure' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K ({temperature - 273}°C)</span></div>
                      <input type="range" min="100" max="600" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Volume (constant)</span><span className="font-medium tabular-nums">{volume.toFixed(1)} L</span></div>
                      <input type="range" min="0.5" max="10" step="0.1" value={volume} onChange={e => setVolume(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <div className="rounded-xl bg-red-50 px-3 py-2.5">
                      <span className="text-sm font-medium text-red-700">P = {derivedP_pressure.toFixed(1)} kPa</span>
                    </div>
                  </>
                )}

                {law === 'real' && (
                  <>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Temperature</span><span className="font-medium tabular-nums">{temperature} K</span></div>
                      <input type="range" min="200" max="800" step="10" value={temperature} onChange={e => setTemperature(Number(e.target.value))} className="w-full" style={{ accentColor: '#f59e0b' }} />
                    </div>
                    <div className="space-y-1.5">
                      <div className="flex justify-between text-xs"><span className="text-gray-500">Moles</span><span className="font-medium tabular-nums">{moles.toFixed(2)} mol</span></div>
                      <input type="range" min="0.01" max="1" step="0.01" value={moles} onChange={e => setMoles(Number(e.target.value))} className="w-full" style={{ accentColor: '#6366f1' }} />
                    </div>
                    <p className="text-xs text-gray-400">Lower T and higher P = more deviation from ideal. Try CO₂ vs He.</p>
                  </>
                )}
              </div>
            </div>

            {/* Graph */}
            <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
              <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-1">{meta.graphLabel}</p>
              <p className="text-xs text-gray-400 mb-4">{meta.graphDesc}</p>
              <GasLawGraph
                law={law}
                currentV={volume}
                currentP={law === 'boyle' ? derivedP_boyle : law === 'pressure' ? derivedP_pressure : pressure}
                currentT={temperature}
                moles={moles}
                selectedGas={selectedGas}
              />
              <div className="mt-4 rounded-xl border border-indigo-100 bg-indigo-50 p-3">
                <p className="text-xs font-medium text-indigo-600 mb-2">Real world</p>
                <ul className="space-y-1.5">
                  {REAL_WORLD[law].map((r, i) => (
                    <li key={i} className="text-xs text-indigo-800 flex gap-2 leading-relaxed">
                      <span className="shrink-0">{r.icon}</span>{r.text}
                    </li>
                  ))}
                </ul>
              </div>
              <div className="mt-3">
                <p className="text-xs text-gray-400 mb-1.5">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CURRICULUM_COLORS[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 md:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
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
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  → src/app/simulations/consequences-of-motion/page.tsx"
cat > "src/app/simulations/consequences-of-motion/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useRef, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ElevatorCanvas } from '@/components/simulation/ElevatorCanvas';
import { WalkingCanvas } from '@/components/simulation/WalkingCanvas';
import { CollisionCanvas } from '@/components/simulation/CollisionCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  apparentWeight, solveCollision, rocketAnalytics,
  ElevatorState, CollisionParams, g,
} from '@/lib/physics/consequences';

type Topic = 'elevator' | 'weightlessness' | 'walking' | 'propulsion' | 'collision';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; law: string }> = {
  elevator:       { title: 'Elevator / Lift',      icon: '🛗', sub: 'Apparent weight and Newton\'s 2nd Law', law: 'R = m(g + a)' },
  weightlessness: { title: 'Weightlessness',        icon: '🚀', sub: 'Zero apparent weight in free fall and orbit', law: 'W_app = 0 when a = −g' },
  walking:        { title: 'Walking',               icon: '🚶', sub: 'Newton\'s 3rd Law — action and reaction', law: 'F_foot = −F_ground' },
  propulsion:     { title: 'Propulsion',            icon: '🛸', sub: 'Rockets, jets — momentum conservation', law: 'Thrust = v_e × ṁ' },
  collision:      { title: 'Collision & Impact',    icon: '💥', sub: 'Elastic vs inelastic — impulse-momentum', law: 'J = Δp = FΔt' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  elevator: [
    "Apparent weight = R = m(g + a). When a > 0 (accelerating up), R > mg — person feels heavier.",
    "When a < 0 (accelerating down), R < mg — person feels lighter. When a = −g (free fall), R = 0.",
    "The scale reads apparent weight, not true weight. This is what WAEC/IGCSE questions actually ask for.",
    "Common exam trap: during constant speed (a=0), the person feels exactly their true weight regardless of how fast they're going.",
    "Deceleration at the top of an upward journey = acceleration downward → lighter feeling, not heavier.",
  ],
  weightlessness: [
    "True weightlessness only exists at infinite distance from all masses. Everything else is apparent weightlessness.",
    "Astronauts in the ISS aren't weightless — they're in constant free fall (orbiting). g ≈ 8.8 m/s² at ISS altitude.",
    "An object in free fall experiences zero apparent weight because both the person and the scale accelerate at g.",
    "Apparent weightlessness can be experienced in a falling lift, a parabolic flight path, or orbital trajectory.",
    "JUPEB/IGCSE: distinguish carefully between 'gravitational field strength', 'weight', and 'apparent weight'.",
  ],
  walking: [
    "Walking is entirely powered by Newton's 3rd Law. Your foot pushes backward on the ground; ground pushes you forward.",
    "Without friction, there is no reaction force and you cannot walk — demonstrated by trying to walk on ice.",
    "The forward force on a person is the ground's reaction — it's an external force that accelerates the person.",
    "Common misconception: students think the push from the foot makes you move. It's the ground's reaction that moves you.",
    "Swimming: hand/foot pushes water backward (action), water pushes swimmer forward (reaction). Same principle.",
  ],
  propulsion: [
    "Rocket thrust = exhaust speed × mass flow rate (T = v_e × ṁ). Nothing to 'push against' — momentum conservation.",
    "As fuel burns, rocket mass decreases → same thrust gives increasing acceleration (a = T/m, m decreasing).",
    "Jet engines work in atmosphere (air provides reaction mass). Rockets carry their own oxidiser — work in vacuum.",
    "Specific impulse: efficiency measure for rockets. Higher exhaust velocity = more efficient propulsion.",
    "Conservation of momentum: before = 0 (at rest). After = rocket momentum + exhaust momentum. Always sums to 0.",
  ],
  collision: [
    "Momentum is always conserved in collisions (no external forces). Kinetic energy may or may not be conserved.",
    "Elastic collision: KE conserved (e=1). Inelastic: KE lost (e<1). Perfectly inelastic: objects stick together (e=0).",
    "Impulse = change in momentum = FΔt. Increasing contact time (crumple zones, airbags) reduces peak force.",
    "The impulse-momentum theorem is why cars have airbags — same Δp, longer Δt, smaller F on passenger.",
    "WAEC exam: most collision questions just apply p_before = p_after. Check if KE is asked separately.",
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  elevator: [
    { q: "A 60kg person stands in a lift accelerating upward at 2 m/s². Find their apparent weight. (g=10)", a: "R = m(g+a) = 60×(10+2) = 60×12 = 720 N. True weight = 600 N." },
    { q: "A 70kg person is in a lift decelerating at 3 m/s² while moving upward. Find apparent weight. (g=10)", a: "Decelerating upward means a = −3 m/s². R = 70×(10−3) = 70×7 = 490 N." },
    { q: "A scale reads 0 N for a 50kg person in a lift. What is happening?", a: "The lift is in free fall (a = −g = −10 m/s²). R = m(g + a) = 50×(10−10) = 0 N. Apparent weightlessness." },
  ],
  weightlessness: [
    { q: "Why do astronauts in the ISS float, even though gravity still acts on them?", a: "The ISS is in continuous free fall (orbiting). Both astronauts and station fall toward Earth at the same rate, so there's no normal force between them — apparent weightlessness." },
    { q: "A 80kg person is in a freely falling lift. What does a scale beneath them read?", a: "0 N — both person and scale fall at g, so no contact force exists between them." },
    { q: "Is there gravity on the Moon? Explain apparent weightlessness vs true weightlessness.", a: "Yes — g_moon ≈ 1.6 m/s². Astronauts have weight on the Moon but feel about 1/6 of Earth weight. True weightlessness only exists at infinite distance from all masses." },
  ],
  walking: [
    { q: "Explain why you cannot walk on a perfectly frictionless surface using Newton's Laws.", a: "When you push your foot backward, the ground needs friction to push back. Without friction, no reaction force acts forward on you, so by Newton's 1st Law, you don't move." },
    { q: "A 70kg person accelerates from rest to 2 m/s in 1s while walking. Find the average forward friction force.", a: "F = ma = 70 × (2/1) = 140 N forward (provided by ground friction as reaction to foot's push)." },
    { q: "Swimming: identify the action and reaction forces when a swimmer pushes off a wall.", a: "Action: swimmer pushes wall backward with force F. Reaction: wall pushes swimmer forward with equal force F. Swimmer accelerates; wall (attached to Earth) doesn't noticeably move." },
  ],
  propulsion: [
    { q: "A rocket of mass 5000 kg ejects gas at 2000 m/s at a rate of 10 kg/s. Find thrust and initial acceleration.", a: "Thrust = v_e × ṁ = 2000 × 10 = 20,000 N. a = F/m = 20000/5000 = 4 m/s²." },
    { q: "Why do rockets work in the vacuum of space but car engines don't?", a: "Rockets carry their own fuel AND oxidiser, ejecting exhaust backward. Cars need atmospheric oxygen to combust fuel. In vacuum, no air = no combustion for a car engine." },
    { q: "A 2 kg toy rocket is at rest. It ejects 0.5 kg of gas at 40 m/s. Find the rocket's speed after.", a: "Momentum conservation: 0 = 1.5 × v_rocket − 0.5 × 40. v_rocket = 20/1.5 ≈ 13.3 m/s." },
  ],
  collision: [
    { q: "A 3kg ball at 6 m/s hits a stationary 1kg ball. They stick together. Find their common velocity.", a: "Perfectly inelastic: (3×6 + 1×0) = (3+1)×v. v = 18/4 = 4.5 m/s." },
    { q: "A 0.1kg bullet at 400 m/s embeds in a 4.9kg block at rest. Find the block's velocity after.", a: "(0.1×400) = (0.1+4.9)×v. v = 40/5 = 8 m/s." },
    { q: "An airbag increases impact time from 0.01s to 0.1s for a 70kg person decelerating from 15 m/s to 0. Compare forces.", a: "Impulse = Δp = 70×15 = 1050 N·s. Without bag: F = 1050/0.01 = 105,000 N. With bag: F = 1050/0.1 = 10,500 N — 10× less force." },
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

export default function ConsequencesPage() {
  const [topic, setTopic] = useState<Topic>('elevator');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [isComplete, setIsComplete] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  // Elevator params
  const [elevMass, setElevMass] = useState(60);
  const [elevState, setElevState] = useState<ElevatorState>('rest');
  const [elevAccel, setElevAccel] = useState(3);

  // Weightlessness
  const [wlHeight, setWlHeight] = useState(400); // km orbit

  // Walking
  const [frictionEnabled, setFrictionEnabled] = useState(true);

  // Propulsion
  const [rocketMass, setRocketMass] = useState(5000);
  const [exhaustSpeed, setExhaustSpeed] = useState(2000);
  const [massFlowRate, setMassFlowRate] = useState(10);

  // Collision
  const [collM1, setCollM1] = useState(3);
  const [collM2, setCollM2] = useState(2);
  const [collU1, setCollU1] = useState(6);
  const [collU2, setCollU2] = useState(0);
  const [collType, setCollType] = useState<CollisionParams['type']>('perfectly-inelastic');
  const [collE, setCollE] = useState(0.6);
  const [collResult, setCollResult] = useState<ReturnType<typeof solveCollision> | null>(null);

  const collParams: CollisionParams = { m1: collM1, m2: collM2, u1: collU1, u2: collU2, type: collType, e: collE };
  const rocketA = rocketAnalytics(rocketMass, exhaustSpeed, massFlowRate);
  const elevAppW = apparentWeight(elevMass, elevState === 'freefall' ? -g : elevState.includes('up') ? (elevState.includes('accel') ? elevAccel : elevState.includes('decel') ? -elevAccel : 0) : elevState.includes('down') ? (elevState.includes('accel') ? -elevAccel : elevState.includes('decel') ? elevAccel : 0) : 0);
  const collRes = solveCollision(collParams);

  // Orbit g
  const orbitG = g * Math.pow(6371 / (6371 + wlHeight), 2);

  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false);
    setIsComplete(false); setResetKey(k => k + 1);
    setCollResult(null);
  }, []);

  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, elevMass, elevState, elevAccel, frictionEnabled, rocketMass, exhaustSpeed, massFlowRate, collM1, collM2, collU1, collU2, collType, collE, reset]);

  // Elevator is a tall, portrait-ish shaft; walking/collision are wide
  // and short — pick the matching base aspect before scaling up.
  const consBase = topic === 'elevator' ? { w: 500, h: 320 } : { w: 660, h: 200 };
  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, consBase.w, consBase.h, 900);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Applications of Newton&apos;s Laws</p>
                <h1 className="text-lg font-semibold text-gray-900">Consequences of motion</h1>
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

          {/* Topic tabs — scrollable on mobile */}
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span>
                <span className="hidden sm:inline">{TOPIC_META[t].title}</span>
                <span className="sm:hidden">{TOPIC_META[t].icon}</span>
              </button>
            ))}
          </div>

          {/* Equation banner */}
          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].law}</span>
          </div>

          {/* Main grid */}
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">

            {/* Canvas + controls + params */}
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">

                {topic === 'elevator' && (
                  <ElevatorCanvas key={resetKey} mass={elevMass} elevState={elevState}
                    manualAccel={elevAccel} isRunning={isRunning} isPaused={isPaused}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'weightlessness' && (
                  <div className="space-y-4 p-4">
                    <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                      {[
                        { label: 'On Earth surface', g: 9.81, color: 'bg-red-50 border-red-200', textColor: 'text-red-700', icon: '🌍' },
                        { label: `At ${wlHeight}km orbit`, g: orbitG, color: 'bg-blue-50 border-blue-200', textColor: 'text-blue-700', icon: '🛸' },
                        { label: 'In free fall', g: 0, color: 'bg-purple-50 border-purple-200', textColor: 'text-purple-700', icon: '🪂' },
                      ].map(s => (
                        <div key={s.label} className={`rounded-xl border ${s.color} p-4 text-center`}>
                          <span className="text-2xl block mb-2">{s.icon}</span>
                          <p className="text-xs text-gray-500 mb-1">{s.label}</p>
                          <p className={`text-lg font-bold ${s.textColor}`}>{s.g.toFixed(2)} m/s²</p>
                          <p className="text-xs text-gray-400 mt-1">
                            Apparent weight: {(elevMass * Math.max(0, s.g - (s.g === 0 ? 9.81 : 0))).toFixed(0)} N
                          </p>
                          <p className="text-xs font-medium mt-2 text-gray-600">
                            {s.g === 0 ? '✓ Weightless' : s.g < 5 ? 'Near weightless' : 'Normal weight'}
                          </p>
                        </div>
                      ))}
                    </div>
                    <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-4 text-center">
                      <p className="text-xs text-indigo-500 mb-1">Key insight</p>
                      <p className="text-sm text-indigo-800 leading-relaxed">
                        At {wlHeight}km altitude, g = {orbitG.toFixed(2)} m/s² — gravity is still {(orbitG/9.81*100).toFixed(0)}% of Earth surface gravity.
                        Astronauts float not because gravity is absent, but because they are in continuous free fall (orbit).
                      </p>
                    </div>
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 text-center">
                      {[
                        { label: 'ISS orbit', h: 400 }, { label: 'GPS orbit', h: 20200 },
                        { label: 'GEO orbit', h: 35786 }, { label: 'Moon orbit', h: 384400 },
                      ].map(o => (
                        <button key={o.label} onClick={() => setWlHeight(o.h)}
                          className={`rounded-xl border p-3 transition text-xs ${wlHeight === o.h ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white border-gray-200 text-gray-600 hover:border-gray-300'}`}>
                          <p className="font-medium">{o.label}</p>
                          <p className="opacity-70">{o.h < 1000 ? `${o.h}km` : `${(o.h/1000).toFixed(0)}k km`}</p>
                        </button>
                      ))}
                    </div>
                  </div>
                )}

                {topic === 'walking' && (
                  <WalkingCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    frictionEnabled={frictionEnabled} surfaceMass={70}
                    width={canvasSize.width} height={canvasSize.height} />
                )}

                {topic === 'propulsion' && (
                  <div className="p-4 space-y-4">
                    {/* Rocket diagram */}
                    <div className="relative h-44 rounded-xl border border-gray-100 bg-gradient-to-b from-slate-900 to-slate-800 overflow-hidden">
                      {/* Stars */}
                      {Array.from({ length: 30 }, (_, i) => (
                        <div key={i} className="absolute w-0.5 h-0.5 bg-white rounded-full opacity-60"
                          style={{ left: `${(i * 37) % 100}%`, top: `${(i * 53) % 100}%` }} />
                      ))}
                      {/* Rocket */}
                      <div className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 flex items-center gap-0">
                        {/* Exhaust */}
                        <div className="flex flex-col gap-0.5 mr-1">
                          {[...Array(4)].map((_, i) => (
                            <div key={i} className="h-1.5 rounded-full bg-orange-400 opacity-80"
                              style={{ width: `${20 + i * 12}px`, marginLeft: `${i * 4}px` }} />
                          ))}
                        </div>
                        {/* Body */}
                        <div className="w-20 h-12 bg-indigo-400 rounded-lg flex items-center justify-center">
                          <span className="text-white text-xs font-bold">{rocketMass}kg</span>
                        </div>
                        {/* Nose */}
                        <div className="w-0 h-0 border-t-[24px] border-t-transparent border-b-[24px] border-b-transparent border-l-[20px] border-l-indigo-500" />
                      </div>
                      {/* Labels */}
                      <div className="absolute bottom-2 left-0 right-0 flex justify-between px-4">
                        <span className="text-red-400 text-xs">← Exhaust (reaction)</span>
                        <span className="text-emerald-400 text-xs">Thrust → motion (action)</span>
                      </div>
                    </div>
                    {/* Analytics */}
                    <div className="grid grid-cols-2 gap-3">
                      {[
                        { l: 'Thrust', v: `${rocketA.thrust.toFixed(0)} N`, c: 'text-amber-600' },
                        { l: 'Acceleration', v: `${rocketA.acceleration.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                        { l: 'Exhaust speed', v: `${exhaustSpeed} m/s`, c: 'text-emerald-600' },
                        { l: 'Mass flow rate', v: `${massFlowRate} kg/s`, c: 'text-rose-500' },
                      ].map(s => (
                        <div key={s.l} className="rounded-xl bg-gray-50 border border-gray-100 px-3 py-2.5 text-center">
                          <p className="text-xs text-gray-400 mb-0.5">{s.l}</p>
                          <p className={`text-sm font-semibold ${s.c}`}>{s.v}</p>
                        </div>
                      ))}
                    </div>
                    <div className="rounded-xl border border-indigo-100 bg-indigo-50 p-3 text-xs text-indigo-800">
                      <p className="font-medium mb-1">Momentum conservation</p>
                      <p>Before launch: total momentum = 0. After ejecting exhaust backward at {exhaustSpeed} m/s, rocket gains equal momentum forward. No external force needed — rockets work in vacuum.</p>
                    </div>
                  </div>
                )}

                {topic === 'collision' && (
                  <CollisionCanvas key={resetKey} params={collParams}
                    isRunning={isRunning} isPaused={isPaused}
                    onComplete={r => { setCollResult(r); setIsComplete(true); setIsRunning(false); }}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              {/* Controls */}
              {topic !== 'weightlessness' && topic !== 'propulsion' && (
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <SimulationControls
                    isRunning={isRunning && !isComplete} isPaused={isPaused}
                    onRun={() => { setIsRunning(true); setIsPaused(false); setIsComplete(false); }}
                    onPause={() => setIsPaused(p => !p)}
                    onReset={reset}
                  />
                  {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Complete — Reset to go again</span>}
                </div>
              )}

              {/* Params */}
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'elevator' && (
                  <>
                    <Slider label="Mass" unit="kg" value={elevMass} min={10} max={150} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Acceleration magnitude" unit="m/s²" value={elevAccel} min={0.5} max={9.8} step={0.1} set={setElevAccel} color="#f59e0b" />
                    <div>
                      <p className="text-xs text-gray-500 mb-2">Elevator state</p>
                      <div className="grid grid-cols-2 gap-1.5">
                        {([
                          ['rest', 'At rest'], ['accel-up', 'Accelerating ↑'],
                          ['constant-up', 'Constant speed ↑'], ['decel-up', 'Decelerating ↑'],
                          ['accel-down', 'Accelerating ↓'], ['constant-down', 'Constant speed ↓'],
                          ['decel-down', 'Decelerating ↓'], ['freefall', '🆘 Free fall'],
                        ] as [ElevatorState, string][]).map(([s, l]) => (
                          <button key={s} onClick={() => setElevState(s)}
                            className={`px-2 py-1.5 rounded-lg text-xs font-medium border transition ${
                              elevState === s
                                ? s === 'freefall' ? 'bg-red-500 text-white border-red-500' : 'bg-indigo-600 text-white border-indigo-600'
                                : 'bg-white text-gray-600 border-gray-200 hover:border-gray-300'
                            }`}>{l}</button>
                        ))}
                      </div>
                    </div>
                  </>
                )}

                {topic === 'weightlessness' && (
                  <>
                    <Slider label="Person mass" unit="kg" value={elevMass} min={40} max={120} step={5} set={setElevMass} color="#6366f1" />
                    <Slider label="Orbit altitude" unit="km" value={wlHeight} min={200} max={400000} step={100} set={setWlHeight} color="#8b5cf6" />
                  </>
                )}

                {topic === 'walking' && (
                  <div className="flex items-center justify-between rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
                    <div>
                      <p className="text-xs font-medium text-gray-700">Ground friction</p>
                      <p className="text-[10px] text-gray-400">{frictionEnabled ? 'Normal ground — walking works' : 'Frictionless ice — cannot walk'}</p>
                    </div>
                    <button onClick={() => setFrictionEnabled(f => !f)}
                      className={`relative w-11 h-6 rounded-full transition ${frictionEnabled ? 'bg-indigo-600' : 'bg-gray-200'}`}>
                      <span className={`absolute top-0.5 left-0.5 w-5 h-5 rounded-full bg-white shadow transition-transform ${frictionEnabled ? 'translate-x-5' : ''}`} />
                    </button>
                  </div>
                )}

                {topic === 'propulsion' && (
                  <>
                    <Slider label="Rocket mass" unit="kg" value={rocketMass} min={500} max={50000} step={500} set={setRocketMass} color="#6366f1" />
                    <Slider label="Exhaust speed" unit="m/s" value={exhaustSpeed} min={200} max={5000} step={100} set={setExhaustSpeed} color="#f59e0b" />
                    <Slider label="Mass flow rate" unit="kg/s" value={massFlowRate} min={1} max={100} step={1} set={setMassFlowRate} color="#10b981" />
                  </>
                )}

                {topic === 'collision' && (
                  <>
                    <div className="grid grid-cols-3 gap-1 bg-gray-100 p-1 rounded-xl">
                      {(['elastic', 'inelastic', 'perfectly-inelastic'] as CollisionParams['type'][]).map(t => (
                        <button key={t} onClick={() => setCollType(t)}
                          className={`py-1.5 rounded-lg text-[10px] font-medium transition ${
                            collType === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500'
                          }`}>{t === 'perfectly-inelastic' ? 'Stick together' : t.charAt(0).toUpperCase() + t.slice(1)}</button>
                      ))}
                    </div>
                    <Slider label="Mass 1 (blue)" unit="kg" value={collM1} min={0.5} max={10} step={0.5} set={setCollM1} color="#6366f1" />
                    <Slider label="Velocity 1" unit="m/s" value={collU1} min={-10} max={20} step={0.5} set={setCollU1} color="#6366f1" />
                    <Slider label="Mass 2 (green)" unit="kg" value={collM2} min={0.5} max={10} step={0.5} set={setCollM2} color="#10b981" />
                    <Slider label="Velocity 2" unit="m/s" value={collU2} min={-10} max={10} step={0.5} set={setCollU2} color="#10b981" note="Negative = moving left" />
                    {collType === 'inelastic' && (
                      <Slider label="Coefficient of restitution (e)" unit="" value={collE} min={0.01} max={0.99} step={0.01} set={setCollE} color="#f59e0b" note="0 = stick together, 1 = elastic" />
                    )}
                  </>
                )}
              </div>
            </div>

            {/* Analytics */}
            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Results</p>
                <div className="space-y-2">
                  {topic === 'elevator' && [
                    { l: 'True weight', v: `${(elevMass * g).toFixed(1)} N`, c: 'text-gray-600' },
                    { l: 'Apparent weight', v: `${elevAppW.toFixed(1)} N`, c: elevAppW > elevMass * g ? 'text-emerald-600' : elevAppW < elevMass * g ? 'text-red-500' : 'text-indigo-600' },
                    { l: 'Difference', v: `${(elevAppW - elevMass * g).toFixed(1)} N`, c: 'text-amber-600' },
                    { l: 'Scale reads', v: `${(elevAppW / g).toFixed(2)} kg`, c: 'text-purple-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'weightlessness' && [
                    { l: 'True weight (Earth)', v: `${(elevMass * 9.81).toFixed(0)} N`, c: 'text-gray-600' },
                    { l: `g at ${wlHeight}km`, v: `${orbitG.toFixed(2)} m/s²`, c: 'text-indigo-600' },
                    { l: 'Weight at altitude', v: `${(elevMass * orbitG).toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Apparent (orbit)', v: '0 N (free fall)', c: 'text-red-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'walking' && [
                    { l: 'Reaction force', v: frictionEnabled ? 'Present ✓' : 'None ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Locomotion', v: frictionEnabled ? 'Possible ✓' : 'Impossible ✗', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Action', v: 'Foot pushes back', c: 'text-gray-600' },
                    { l: 'Reaction', v: frictionEnabled ? 'Ground pushes forward' : 'No reaction', c: frictionEnabled ? 'text-emerald-600' : 'text-red-500' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'propulsion' && [
                    { l: 'Thrust', v: `${rocketA.thrust.toFixed(0)} N`, c: 'text-amber-600' },
                    { l: 'Acceleration', v: `${rocketA.acceleration.toFixed(3)} m/s²`, c: 'text-indigo-600' },
                    { l: 'T = v_e × ṁ', v: `${exhaustSpeed}×${massFlowRate}=${rocketA.thrust.toFixed(0)}`, c: 'text-gray-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}

                  {topic === 'collision' && [
                    { l: 'v₁ after', v: `${collRes.v1.toFixed(2)} m/s`, c: 'text-indigo-600' },
                    { l: 'v₂ after', v: `${collRes.v2.toFixed(2)} m/s`, c: 'text-emerald-600' },
                    { l: 'p before', v: `${collRes.momentumBefore.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'p after', v: `${collRes.momentumAfter.toFixed(2)} kg·m/s`, c: 'text-gray-600' },
                    { l: 'KE lost', v: `${collRes.keLost.toFixed(2)} J`, c: collRes.keLost < 0.01 ? 'text-emerald-600' : 'text-red-500' },
                    { l: 'Impulse', v: `${collRes.impulse.toFixed(2)} N·s`, c: 'text-amber-600' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-sm font-semibold ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
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

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
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
echo "✓ Patch v11 applied — 16 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check a few sims at different browser widths — the canvas should now"
echo "fill the available column width (up to its cap) instead of sitting"
echo "at a small fixed size, and should stay crisp (not stretched/blurry)."
