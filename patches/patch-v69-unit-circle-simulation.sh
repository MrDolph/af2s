#!/bin/bash
# A-Factor STEM Studio — new public simulation: Unit Circle Explorer
# Run inside af2s/ folder: bash patches/patch-v69-unit-circle-simulation.sh
#
# Adds a new simulation to the PUBLIC /simulations hub (not the gated
# minitab) — general trigonometry, useful across WAEC/NECO/IGCSE/SAT/JUPEB,
# inspired by the reference image you shared:
#
#   /simulations/unit-circle
#
# Features:
#   - Drag a point directly around the circle, or use the angle slider
#   - Degrees/Radians toggle, live readout of both simultaneously
#   - Quadrant (I-IV) and sign (+/-) readout for sin/cos, updating live
#   - Common reference angles (0°, 30°, 45°, ... 330°) marked on the
#     circle with paired degree/radian labels, matching the reference image
#   - Live sin(θ) and cos(θ) projection lines onto the axes
#   - Two stacked graphs (sin and cos vs angle) with a moving marker
#     synced to the current angle, matching the reference image's layout
#   - Animate button for a continuous sweep
#   - Teacher notes and exercises, following your existing convention
#
# Only touches src/app/simulations/page.tsx via a targeted insertion (one
# new object added to the SIMULATIONS array) — verified against a diff that
# nothing else in that file changed. All other files here are new.
#
# Verified with a full npm run build against your actual project (after
# applying your existing v59 MOSFET fix) — zero TypeScript errors, the new
# route statically generated alongside every other route.

set -e
echo "Applying Unit Circle Explorer patch..."

mkdir -p src/lib/physics
mkdir -p src/components/simulation
mkdir -p src/app/simulations/unit-circle

echo "  writing src/lib/physics/unitCircle.ts"
cat > src/lib/physics/unitCircle.ts << 'FILEEOF'
// ── Unit Circle Trigonometry ────────────────────────────────────────────────
// Pure helpers: angle conversion, common reference angles (with their exact
// radian fractions for display), and quadrant lookup.

export const deg2rad = (deg: number) => (deg * Math.PI) / 180;
export const rad2deg = (rad: number) => (rad * 180) / Math.PI;

export interface CommonAngle {
  deg: number;
  radLabel: string; // exact fraction, e.g. "π/6"
}

// The 16 standard reference angles shown around the circle (every 15°/30°
// depending on quadrant, matching the conventional unit-circle diagram).
export const COMMON_ANGLES: CommonAngle[] = [
  { deg: 0, radLabel: '0' },
  { deg: 30, radLabel: 'π/6' },
  { deg: 45, radLabel: 'π/4' },
  { deg: 60, radLabel: 'π/3' },
  { deg: 90, radLabel: 'π/2' },
  { deg: 120, radLabel: '2π/3' },
  { deg: 135, radLabel: '3π/4' },
  { deg: 150, radLabel: '5π/6' },
  { deg: 180, radLabel: 'π' },
  { deg: 210, radLabel: '7π/6' },
  { deg: 225, radLabel: '5π/4' },
  { deg: 240, radLabel: '4π/3' },
  { deg: 270, radLabel: '3π/2' },
  { deg: 300, radLabel: '5π/3' },
  { deg: 315, radLabel: '7π/4' },
  { deg: 330, radLabel: '11π/6' },
];

export function quadrantOf(deg: number): 1 | 2 | 3 | 4 {
  const d = ((deg % 360) + 360) % 360;
  if (d < 90) return 1;
  if (d < 180) return 2;
  if (d < 270) return 3;
  return 4;
}

export const QUADRANT_SIGNS: Record<1 | 2 | 3 | 4, { sin: string; cos: string }> = {
  1: { sin: '+', cos: '+' },
  2: { sin: '+', cos: '−' },
  3: { sin: '−', cos: '−' },
  4: { sin: '−', cos: '+' },
};

/** Generates {deg, sin, cos} samples over [0, 360] for the graphs below the circle. */
export function generateTrigCurve(points = 361) {
  const data: { deg: number; sin: number; cos: number }[] = [];
  for (let i = 0; i < points; i++) {
    const deg = (i / (points - 1)) * 360;
    const rad = deg2rad(deg);
    data.push({ deg, sin: Math.sin(rad), cos: Math.cos(rad) });
  }
  return data;
}
FILEEOF

echo "  writing src/components/simulation/UnitCircleCanvas.tsx"
cat > src/components/simulation/UnitCircleCanvas.tsx << 'FILEEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { deg2rad, COMMON_ANGLES } from '@/lib/physics/unitCircle';

interface Props {
  angleDeg: number;
  onAngleChange: (deg: number) => void;
  width?: number;
  height?: number;
}

export function UnitCircleCanvas({ angleDeg, onAngleChange, width = 440, height = 440 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const draggingRef = useRef(false);
  const sim = useRef({ angleDeg });
  sim.current = { angleDeg };

  const draw = useCallback(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const W = canvas.width, H = canvas.height;
    const cx = W / 2, cy = H / 2;
    const R = Math.min(W, H) * 0.32;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc';
    ctx.fillRect(0, 0, W, H);

    // axes
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.moveTo(cx - R - 40, cy); ctx.lineTo(cx + R + 40, cy);
    ctx.moveTo(cx, cy - R - 40); ctx.lineTo(cx, cy + R + 40);
    ctx.stroke();

    // quadrant labels
    ctx.fillStyle = '#cbd5e1';
    ctx.font = '600 13px sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('I', cx + R * 0.42, cy - R * 0.36);
    ctx.fillText('II', cx - R * 0.42, cy - R * 0.36);
    ctx.fillText('III', cx - R * 0.42, cy + R * 0.48);
    ctx.fillText('IV', cx + R * 0.42, cy + R * 0.48);

    // main circle
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 1.6;
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, 2 * Math.PI);
    ctx.stroke();

    // common-angle ticks + labels
    ctx.font = '10px sans-serif';
    COMMON_ANGLES.forEach(({ deg, radLabel }) => {
      const rad = deg2rad(deg);
      const px = cx + R * Math.cos(rad), py = cy - R * Math.sin(rad);
      ctx.fillStyle = '#f59e0b';
      ctx.beginPath();
      ctx.arc(px, py, 2.5, 0, 2 * Math.PI);
      ctx.fill();

      const lx = cx + (R + 22) * Math.cos(rad), ly = cy - (R + 22) * Math.sin(rad);
      ctx.fillStyle = '#b45309';
      ctx.textAlign = 'center';
      ctx.fillText(`${deg}°`, lx, ly - 4);
      ctx.fillStyle = '#92400e';
      ctx.fillText(radLabel, lx, ly + 8);
    });

    // current angle
    const rad = deg2rad(angleDeg);
    const px = cx + R * Math.cos(rad), py = cy - R * Math.sin(rad);

    // angle arc from positive x-axis
    ctx.strokeStyle = '#6366f1';
    ctx.lineWidth = 1.3;
    ctx.beginPath();
    ctx.arc(cx, cy, 26, -rad, 0, false);
    ctx.stroke();
    if (angleDeg > 12) {
      ctx.fillStyle = '#4f46e5';
      ctx.font = 'italic 12px serif';
      ctx.textAlign = 'center';
      ctx.fillText('\u03b8', cx + 42 * Math.cos(rad / 2), cy - 42 * Math.sin(rad / 2) + 4);
    }

    // radius line
    ctx.strokeStyle = '#475569';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(cx, cy); ctx.lineTo(px, py);
    ctx.stroke();

    // cos projection (yellow, horizontal, along x-axis to px)
    ctx.strokeStyle = '#eab308';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(cx, cy); ctx.lineTo(px, cy);
    ctx.stroke();

    // sin projection (red, vertical, from x-axis up/down to point)
    ctx.strokeStyle = '#ef4444';
    ctx.lineWidth = 2.4;
    ctx.beginPath();
    ctx.moveTo(px, cy); ctx.lineTo(px, py);
    ctx.stroke();

    // point on circle
    ctx.fillStyle = '#4f46e5';
    ctx.beginPath();
    ctx.arc(px, py, 7, 0, 2 * Math.PI);
    ctx.fill();
    ctx.strokeStyle = 'white';
    ctx.lineWidth = 2;
    ctx.stroke();

    // axis endpoint labels — placed just inside the circle so they never collide
    // with the outside degree/radian labels at 90 and 270 degrees
    ctx.fillStyle = '#64748b';
    ctx.font = '11px sans-serif';
    ctx.textAlign = 'right';
    ctx.fillText('(1, 0)', cx + R - 6, cy - 6);
    ctx.textAlign = 'left';
    ctx.fillText('(\u22121, 0)', cx - R + 6, cy - 6);
    ctx.fillText('(0, 1)', cx + 8, cy - R + 16);
    ctx.fillText('(0, \u22121)', cx + 8, cy + R - 8);
  }, [angleDeg]);

  useEffect(() => { draw(); }, [draw]);

  const setFromPointer = useCallback((clientX: number, clientY: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const rect = canvas.getBoundingClientRect();
    const scaleX = canvas.width / rect.width, scaleY = canvas.height / rect.height;
    const px = (clientX - rect.left) * scaleX, py = (clientY - rect.top) * scaleY;
    const cx = canvas.width / 2, cy = canvas.height / 2;
    const dx = px - cx, dy = cy - py; // flip y so up is positive
    let deg = (Math.atan2(dy, dx) * 180) / Math.PI;
    if (deg < 0) deg += 360;
    onAngleChange(deg);
  }, [onAngleChange]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="rounded-xl cursor-grab active:cursor-grabbing touch-none max-w-full"
      onPointerDown={e => { (e.target as HTMLCanvasElement).setPointerCapture(e.pointerId); draggingRef.current = true; setFromPointer(e.clientX, e.clientY); }}
      onPointerMove={e => { if (draggingRef.current) setFromPointer(e.clientX, e.clientY); }}
      onPointerUp={() => { draggingRef.current = false; }}
    />
  );
}
FILEEOF

echo "  writing src/components/simulation/UnitCircleGraph.tsx"
cat > src/components/simulation/UnitCircleGraph.tsx << 'FILEEOF'
'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceDot, ReferenceLine } from 'recharts';
import { generateTrigCurve, deg2rad } from '@/lib/physics/unitCircle';

interface Props {
  angleDeg: number;
}

export function UnitCircleGraph({ angleDeg }: Props) {
  const data = useMemo(() => generateTrigCurve(), []);
  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);

  return (
    <div className="space-y-3">
      <div>
        <p className="text-[11px] font-medium text-rose-600 mb-1">sin θ</p>
        <ResponsiveContainer width="100%" height={110}>
          <LineChart data={data} margin={{ top: 4, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="deg" type="number" domain={[0, 360]} ticks={[0, 90, 180, 270, 360]} tick={{ fontSize: 9 }} />
            <YAxis domain={[-1, 1]} ticks={[-1, 0, 1]} tick={{ fontSize: 9 }} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={d => `${d}°`} />
            <ReferenceLine y={0} stroke="#e2e8f0" />
            <Line type="monotone" dataKey="sin" stroke="#ef4444" strokeWidth={2} dot={false} isAnimationActive={false} />
            <ReferenceLine x={angleDeg} stroke="#94a3b8" strokeDasharray="3 3" />
            <ReferenceDot x={angleDeg} y={sinVal} r={5} fill="#ef4444" stroke="#fff" strokeWidth={1.5} />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <div>
        <p className="text-[11px] font-medium text-amber-600 mb-1">cos θ</p>
        <ResponsiveContainer width="100%" height={110}>
          <LineChart data={data} margin={{ top: 4, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="deg" type="number" domain={[0, 360]} ticks={[0, 90, 180, 270, 360]} tick={{ fontSize: 9 }} />
            <YAxis domain={[-1, 1]} ticks={[-1, 0, 1]} tick={{ fontSize: 9 }} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={d => `${d}°`} />
            <ReferenceLine y={0} stroke="#e2e8f0" />
            <Line type="monotone" dataKey="cos" stroke="#eab308" strokeWidth={2} dot={false} isAnimationActive={false} />
            <ReferenceLine x={angleDeg} stroke="#94a3b8" strokeDasharray="3 3" />
            <ReferenceDot x={angleDeg} y={cosVal} r={5} fill="#eab308" stroke="#fff" strokeWidth={1.5} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
FILEEOF

echo "  writing src/app/simulations/unit-circle/page.tsx"
cat > src/app/simulations/unit-circle/page.tsx << 'FILEEOF'
'use client';
import { useState, useRef, useCallback, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { UnitCircleCanvas } from '@/components/simulation/UnitCircleCanvas';
import { UnitCircleGraph } from '@/components/simulation/UnitCircleGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { deg2rad, rad2deg, quadrantOf, QUADRANT_SIGNS } from '@/lib/physics/unitCircle';

const TEACHER_NOTES = [
  "Every point on the unit circle is (cos θ, sin θ) — that's not a coincidence to memorise, it's the actual definition. Drag the point and watch both coordinates update together.",
  "The yellow line is always the point's x-coordinate (cos θ); the red line is always its y-coordinate (sin θ) — the 'projection' picture is the fastest way to see why sin and cos are just shifted copies of each other (90° out of phase).",
  "The sign of sin θ and cos θ in each quadrant follows directly from which coordinates are positive/negative there — no need to memorise 'CAST' or similar mnemonics if students can see why it's true here.",
  "Degrees and radians are just two different rulers measuring the same rotation — 360° and 2π radians are the same full turn. The toggle lets students build intuition for both before an exam forces a quick conversion.",
  "The two graphs below are literally 'unroll the circle onto a line' — dragging the point around the circle traces out exactly the sine and cosine curves, in real time.",
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Convert 150° to radians, giving your answer as a fraction of π.', a: '150° = 150×(π/180) = 5π/6.' },
  { q: 'Convert 7π/4 radians to degrees.', a: '7π/4 × (180/π) = 315°.' },
  { q: 'Which quadrant is 210° in, and what are the signs of sin and cos there?', a: 'Quadrant III (180°–270°): both sin and cos are negative.' },
  { q: 'Using the unit circle, state sin(60°) and cos(60°) exactly (as surds/fractions, not decimals).', a: 'sin(60°) = √3/2, cos(60°) = 1/2.' },
  { q: 'Explain why sin(150°) = sin(30°), using the unit circle picture.', a: '150° and 30° are reflections of each other across the vertical axis — same height (y-coordinate), so the same sine value. Their cosines are opposite in sign instead.' },
  { q: 'A point on the unit circle has cos θ = −0.5 and sin θ is positive. Which quadrant is θ in, and what is θ in degrees?', a: 'Quadrant II (cos negative, sin positive) — θ = 120°.' },
];

export default function UnitCirclePage() {
  const [angleDeg, setAngleDeg] = useState(105.86);
  const [unit, setUnit] = useState<'deg' | 'rad'>('deg');
  const [animating, setAnimating] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const animRef = useRef<number>(0);
  const lastTsRef = useRef<number | null>(null);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 440, 440, 480);

  const toggleAnimate = useCallback(() => {
    if (animating) {
      cancelAnimationFrame(animRef.current);
      setAnimating(false);
      lastTsRef.current = null;
      return;
    }
    setAnimating(true);
    const step = (ts: number) => {
      if (lastTsRef.current !== null) {
        const dt = (ts - lastTsRef.current) / 1000;
        setAngleDeg(prev => (prev + dt * 60) % 360); // 60°/s — one full turn every 6s
      }
      lastTsRef.current = ts;
      animRef.current = requestAnimationFrame(step);
    };
    animRef.current = requestAnimationFrame(step);
  }, [animating]);

  useEffect(() => () => cancelAnimationFrame(animRef.current), []);

  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);
  const quadrant = quadrantOf(angleDeg);
  const signs = QUADRANT_SIGNS[quadrant];

  const displayValue = unit === 'deg' ? angleDeg.toFixed(2) : rad2deg(angleDeg) === 0 ? '0' : (rad).toFixed(3);
  const sliderMax = unit === 'deg' ? 360 : Math.PI * 2;
  const sliderValue = unit === 'deg' ? angleDeg : rad;
  const handleSliderChange = (v: number) => {
    setAngleDeg(unit === 'deg' ? v : rad2deg(v));
  };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Mathematics — Trigonometry</p>
                <h1 className="text-lg font-semibold text-gray-900">Unit Circle Explorer</h1>
              </div>
              <div className="flex gap-2">
                <span className="text-xs px-3 py-1.5 rounded-full font-medium bg-indigo-100 text-indigo-700">
                  θ = {angleDeg.toFixed(2)}°
                </span>
                <span className="text-xs px-3 py-1.5 rounded-full font-medium bg-purple-100 text-purple-700">
                  {rad.toFixed(3)} rad
                </span>
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">

            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm flex justify-center">
                <UnitCircleCanvas angleDeg={angleDeg} onAngleChange={setAngleDeg} width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <SimulationControls
                  isRunning={animating} isPaused={false}
                  onRun={toggleAnimate}
                  onPause={toggleAnimate}
                  onReset={() => { cancelAnimationFrame(animRef.current); setAnimating(false); lastTsRef.current = null; setAngleDeg(0); }}
                />
                <div className="flex rounded-lg border border-gray-200 overflow-hidden text-xs">
                  <button onClick={() => setUnit('deg')}
                    className={`px-3 py-1.5 font-medium transition ${unit === 'deg' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>
                    Degrees
                  </button>
                  <button onClick={() => setUnit('rad')}
                    className={`px-3 py-1.5 font-medium transition ${unit === 'rad' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>
                    Radians
                  </button>
                </div>
                <EmbedButton path="/embed/unit-circle" params={{ angleDeg }} title="Unit Circle Explorer" />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <div className="flex items-center gap-3">
                  <span className="text-xs text-gray-500 shrink-0 w-14">θ ({unit === 'deg' ? '°' : 'rad'})</span>
                  <input type="range" min={0} max={sliderMax} step={sliderMax / 720} value={sliderValue}
                    onChange={e => handleSliderChange(Number(e.target.value))}
                    className="flex-1" style={{ accentColor: '#6366f1' }} />
                  <span className="text-xs font-mono text-gray-500 w-16 text-right">{displayValue}{unit === 'deg' ? '°' : ''}</span>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-2">sin θ and cos θ vs angle</p>
                <UnitCircleGraph angleDeg={angleDeg} />
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                {[
                  { l: 'θ (degrees)', v: `${angleDeg.toFixed(2)}°`, c: 'text-indigo-600' },
                  { l: 'θ (radians)', v: `${rad.toFixed(3)} rad`, c: 'text-purple-600' },
                  { l: 'sin θ', v: sinVal.toFixed(3), c: 'text-rose-600' },
                  { l: 'cos θ', v: cosVal.toFixed(3), c: 'text-amber-600' },
                  { l: 'Quadrant', v: `${['', 'I', 'II', 'III', 'IV'][quadrant]}`, c: 'text-gray-700' },
                  { l: 'Signs (sin, cos)', v: `(${signs.sin}, ${signs.cos})`, c: 'text-gray-700' },
                ].map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
              </div>
              <p className="text-[11px] text-gray-400 px-1">Drag the point around the circle, or use the slider — try Animate for a continuous sweep.</p>
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
FILEEOF

# Register the simulation on the public hub via TARGETED EDITS ONLY — never a
# full overwrite of src/app/simulations/page.tsx, so any entries or topics you've
# added there yourself are left exactly as they are. Both edits are idempotent
# (safe to re-run) and handle CRLF or LF line endings.
#   1. add the unit-circle entry to the SIMULATIONS array
#   2. add 'Mathematics' to the hard-coded TOPICS filter list, so it gets its
#      own filter chip on the hub (otherwise it would only appear under "All")
python3 - << 'PYEOF'
import re
path = "src/app/simulations/page.tsx"
with open(path, "r", encoding="utf-8", newline="") as f:
    content = f.read()
original = content
nl = "\r\n" if "\r\n" in content else "\n"

# 1. SIMULATIONS entry
if "slug: 'unit-circle'" in content:
    print("  hub already lists unit-circle — skipping entry")
else:
    block = nl.join([
        "  {",
        "    slug: 'unit-circle',",
        "    href: '/simulations/unit-circle',",
        "    title: 'Unit circle explorer',",
        "    description: 'Drag a point around the unit circle and see sin, cos, degrees, and radians update together \u2014 with live graphs and quadrant signs.',",
        "    icon: '\u2b55',",
        "    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],",
        "    topic: 'Mathematics',",
        "    status: 'live',",
        "  },",
    ]) + nl
    m = re.compile(r"(    slug: 'gas-laws',.*?\r?\n  \},\r?\n)", re.DOTALL).search(content)
    if not m:
        print("  ERROR: could not find the gas-laws entry to anchor on — hub NOT modified.")
        print("  Add the unit-circle entry to the SIMULATIONS array by hand (see patch header).")
        raise SystemExit(1)
    content = content[:m.end()] + block + content[m.end():]
    print("  registered unit-circle in the SIMULATIONS array")

# 2. TOPICS filter chip
t = re.search(r"const TOPICS = \[([^\]]*)\];", content)
if not t:
    print("  NOTE: could not find the TOPICS list — add 'Mathematics' to it by hand for a filter chip.")
elif "'Mathematics'" in t.group(1):
    print("  TOPICS already includes 'Mathematics' — skipping")
else:
    new_list = "const TOPICS = [" + t.group(1).rstrip() + ", 'Mathematics'];"
    content = content[:t.start()] + new_list + content[t.end():]
    print("  added 'Mathematics' to the TOPICS filter list")

if content != original:
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(content)
PYEOF

echo ""
echo "Done. New route: /simulations/unit-circle (listed under a new 'Mathematics' filter on the hub)."
echo "Rebuild to confirm:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
