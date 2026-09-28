#!/bin/bash
# A-Factor STEM Studio — Mathematics section (nav tab + hub + Unit Circle move)
# Run inside af2s/ folder: bash patches/patch-v70-mathematics-section.sh
#
# This SUPERSEDES patch-v69. It is fully self-contained, so:
#   - if you have NOT run v69, just run this one and skip v69;
#   - if you HAVE run v69, this cleans up after it (see below).
#
# WHY: the Unit Circle explorer is mathematics, not physics, and the Physics
# hub is titled "Physics simulations for every curriculum" — so it shouldn't
# live inside it. This creates a proper, easy-to-find Mathematics section.
#
# WHAT IT ADDS
#   - A "Mathematics" tab in the main nav (desktop + mobile), on every page
#   - /mathematics            a dedicated hub, same card style as the Physics
#                             hub. Its topic filter is built automatically from
#                             the simulations listed, so future maths topics
#                             need no extra wiring.
#   - /mathematics/unit-circle the Unit Circle explorer (moved here)
#   - /embed/unit-circle       an embed page. v69's Embed button pointed at a
#                             route that did not exist (a dead link) — fixed.
#                             Params: angleDeg=150  unit=rad  graph=0  controls=0
#   - A "Mathematics →" link beside "All simulations →" on the home hero, and a
#     "Mathematics simulations →" pill in the Physics hub hero, so students
#     can find it from either place.
#
# WHAT IT CHANGES IN EXISTING FILES (all TARGETED, IDEMPOTENT edits — never a
# full overwrite, safe to re-run, CRLF/LF-aware):
#   src/components/layout/AppHeader.tsx  add one entry to the NAV array
#   src/app/simulations/page.tsx         (a) remove the unit-circle entry and the
#                                        'Mathematics' topic chip that v69 added,
#                                        if present; (b) add the pointer pill
#   src/app/page.tsx                     add the small "Mathematics →" link
#
# If v69 was applied, the old /simulations/unit-circle page becomes a redirect
# to /mathematics/unit-circle so existing links keep working.
#
# The nav-tab edit is REQUIRED: if its anchor can't be found the script stops
# and tells you the one line to add by hand. The two cross-links are optional
# nice-to-haves: if an anchor is missing they are skipped with a note.

set -e
echo "Applying Mathematics section patch..."

mkdir -p src/lib/physics
mkdir -p src/components/simulation
mkdir -p src/app/mathematics/unit-circle
mkdir -p src/app/embed/unit-circle

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

echo "  writing src/app/mathematics/page.tsx"
cat > src/app/mathematics/page.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700',
  NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

interface MathSimulation {
  slug: string;
  href: string;
  title: string;
  description: string;
  icon: string;
  tags: string[];
  topic: string;
  status: 'live' | 'coming';
}

// Add new mathematics simulations here. The topic filter below is built from
// whatever topics appear in this list, so a new topic gets its own chip
// automatically — nothing else needs editing.
const MATH_SIMULATIONS: MathSimulation[] = [
  {
    slug: 'unit-circle',
    href: '/mathematics/unit-circle',
    title: 'Unit circle explorer',
    description: 'Drag a point around the unit circle and see sin, cos, degrees, and radians update together — with live graphs and quadrant signs.',
    icon: '⭕',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Trigonometry',
    status: 'live',
  },
];

const TOPICS = ['All', ...Array.from(new Set(MATH_SIMULATIONS.map(s => s.topic)))];

export default function MathematicsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visible = selectedTopic === 'All'
    ? MATH_SIMULATIONS
    : MATH_SIMULATIONS.filter(s => s.topic === selectedTopic);

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
                Mathematics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive tools for the maths behind physics — see how an idea works by moving it,
                not just reading about it.
              </p>
              <Link href="/simulations"
                className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-3 py-1 text-xs font-medium text-gray-600 hover:border-indigo-300 hover:text-indigo-700 transition">
                Looking for physics? Physics simulations →
              </Link>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — only worth showing once there is more than one topic */}
          {TOPICS.length > 2 && (
            <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
              {TOPICS.map(t => {
                const count = t === 'All' ? MATH_SIMULATIONS.length : MATH_SIMULATIONS.filter(s => s.topic === t).length;
                const active = selectedTopic === t;
                return (
                  <button key={t} onClick={() => setSelectedTopic(t)}
                    className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                      }`}>
                    {t}
                    <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>{count}</span>
                  </button>
                );
              })}
            </div>
          )}

          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visible.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${sim.status === 'live'
                ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md'
                : 'border-gray-100 opacity-70'
                }`}>
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse" />
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}
                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    <div className="flex items-center gap-2 mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>
                    <h2 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">{sim.title}</h2>
                    <p className="text-xs text-gray-500 leading-relaxed mb-3">{sim.description}</p>
                    <div className="flex flex-wrap gap-1.5">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag] ?? 'bg-gray-100 text-gray-600'}`}>{tag}</span>
                      ))}
                    </div>
                  </div>
                </Link>
              </div>
            ))}
          </div>

          <p className="mt-10 text-center text-xs text-gray-400">
            More mathematics simulations will be added here.
          </p>
        </section>
      </main>
    </>
  );
}
FILEEOF

echo "  writing src/app/mathematics/unit-circle/page.tsx"
cat > src/app/mathematics/unit-circle/page.tsx << 'FILEEOF'
'use client';
import { useState, useRef, useCallback, useEffect } from 'react';
import Link from 'next/link';
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
                <p className="text-xs text-gray-400 mb-0.5">
                  <Link href="/mathematics" className="hover:text-indigo-600 transition">Mathematics</Link> — Trigonometry
                </p>
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

echo "  writing src/app/embed/unit-circle/page.tsx"
cat > src/app/embed/unit-circle/page.tsx << 'FILEEOF'
'use client';
import { Suspense, useState, useRef, useCallback, useEffect } from 'react';
import { useSearchParams } from 'next/navigation';
import { UnitCircleCanvas } from '@/components/simulation/UnitCircleCanvas';
import { UnitCircleGraph } from '@/components/simulation/UnitCircleGraph';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { deg2rad, quadrantOf } from '@/lib/physics/unitCircle';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

// Supported query params:
//   angleDeg=150   starting angle in degrees (0-360)
//   unit=rad       show the readout in radians instead of degrees
//   graph=0        hide the sin/cos graphs
//   controls=0     lock the embed at the given angle (no dragging, slider or animate) —
//                  handy for worksheets that need to show one specific angle
function UnitCircleEmbedInner() {
  const sp = useSearchParams();
  const showGraph = sp.get('graph') !== '0';
  const showControls = sp.get('controls') !== '0';

  const [angleDeg, setAngleDeg] = useState(() => num(sp, 'angleDeg', 45, 0, 360));
  const [unit, setUnit] = useState<'deg' | 'rad'>(sp.get('unit') === 'rad' ? 'rad' : 'deg');
  const [animating, setAnimating] = useState(false);
  const animRef = useRef<number>(0);
  const lastTsRef = useRef<number | null>(null);

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 420, 420, 420);

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
        setAngleDeg(prev => (prev + dt * 60) % 360);
      }
      lastTsRef.current = ts;
      animRef.current = requestAnimationFrame(step);
    };
    animRef.current = requestAnimationFrame(step);
  }, [animating]);

  useEffect(() => () => cancelAnimationFrame(animRef.current), []);

  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);
  const quadrant = ['', 'I', 'II', 'III', 'IV'][quadrantOf(angleDeg)];
  const thetaText = unit === 'deg' ? `${angleDeg.toFixed(1)}°` : `${rad.toFixed(3)} rad`;

  return (
    <div className="p-3 flex flex-col md:flex-row gap-3">
      <div ref={boxRef} className="md:w-[420px] md:shrink-0 flex justify-center">
        <UnitCircleCanvas
          angleDeg={angleDeg}
          onAngleChange={showControls ? setAngleDeg : () => {}}
          width={size.width}
          height={size.height}
        />
      </div>

      <div className="flex-1 min-w-0 space-y-3">
        <div className="grid grid-cols-2 gap-2 text-xs">
          {[
            { l: 'θ', v: thetaText, c: 'text-indigo-600' },
            { l: 'Quadrant', v: quadrant, c: 'text-gray-700' },
            { l: 'sin θ', v: sinVal.toFixed(3), c: 'text-rose-600' },
            { l: 'cos θ', v: cosVal.toFixed(3), c: 'text-amber-600' },
          ].map(r => (
            <div key={r.l} className="flex justify-between rounded-lg bg-gray-50 px-3 py-2">
              <span className="text-gray-500">{r.l}</span>
              <span className={`font-semibold tabular-nums ${r.c}`}>{r.v}</span>
            </div>
          ))}
        </div>

        {showControls && (
          <div className="flex flex-wrap items-center gap-2">
            <button onClick={toggleAnimate}
              className="text-xs px-3 py-1.5 rounded-lg border border-gray-200 bg-white font-medium text-gray-600 hover:border-indigo-300 transition">
              {animating ? '⏸ Stop' : '▶ Animate'}
            </button>
            <div className="flex rounded-lg border border-gray-200 overflow-hidden text-xs">
              <button onClick={() => setUnit('deg')}
                className={`px-3 py-1.5 font-medium transition ${unit === 'deg' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>Degrees</button>
              <button onClick={() => setUnit('rad')}
                className={`px-3 py-1.5 font-medium transition ${unit === 'rad' ? 'bg-indigo-600 text-white' : 'bg-white text-gray-500'}`}>Radians</button>
            </div>
            <input type="range" min={0} max={360} step={0.5} value={angleDeg}
              onChange={e => setAngleDeg(Number(e.target.value))}
              className="flex-1 min-w-[120px]" style={{ accentColor: '#6366f1' }} aria-label="Angle" />
          </div>
        )}

        {showGraph && <UnitCircleGraph angleDeg={angleDeg} />}

        <p className="text-[10px] text-gray-400">A-Factor STEM Studio · Unit circle explorer</p>
      </div>
    </div>
  );
}

export default function UnitCircleEmbedPage() {
  // useSearchParams() needs a Suspense boundary in the App Router, or the
  // build fails during static prerendering.
  return (
    <Suspense fallback={<div className="p-6 text-sm text-gray-400">Loading…</div>}>
      <UnitCircleEmbedInner />
    </Suspense>
  );
}
FILEEOF

# If v69 was applied, turn its old page into a redirect so links/bookmarks keep working.
if [ -d src/app/simulations/unit-circle ]; then
  echo "  replacing old /simulations/unit-circle page (from v69) with a redirect"
  cat > src/app/simulations/unit-circle/page.tsx << 'FILEEOF'
import { redirect } from 'next/navigation';

// The unit circle explorer now lives under Mathematics. This keeps any link
// or bookmark to the old address working.
export default function OldUnitCircleRedirect() {
  redirect('/mathematics/unit-circle');
}
FILEEOF
fi

python3 - << 'PYEOF'
import re, sys

def read(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        return f.read()

def write(path, s):
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(s)

problems = []   # REQUIRED edits that could not be applied
notes = []      # optional edits that were skipped

# ── A. Nav tab (required) ─────────────────────────────────────────────
p = "src/components/layout/AppHeader.tsx"
s = read(p)
nl = "\r\n" if "\r\n" in s else "\n"
if "href: '/mathematics'" in s:
    print("  nav already has a Mathematics tab — skipping")
else:
    m = re.search(r"([ \t]*)\{ label: 'Simulations', href: '/simulations' \},[ \t]*\r?\n", s)
    if not m:
        problems.append("AppHeader.tsx: could not find the Simulations entry in the NAV array. "
                        "Add this line to NAV by hand:  { label: 'Mathematics', href: '/mathematics' },")
    else:
        s = s[:m.end()] + m.group(1) + "{ label: 'Mathematics', href: '/mathematics' }," + nl + s[m.end():]
        write(p, s)
        print("  added the Mathematics tab to the nav")

# ── B. Physics hub: undo v69's edits, add the pointer pill ────────────
p = "src/app/simulations/page.tsx"
s = read(p)
orig = s
nl = "\r\n" if "\r\n" in s else "\n"

m = re.search(r"  \{\r?\n    slug: 'unit-circle',.*?\r?\n  \},\r?\n", s, re.DOTALL)
if m:
    s = s[:m.start()] + s[m.end():]
    print("  removed the unit-circle entry from the Physics hub")
else:
    print("  Physics hub has no unit-circle entry — nothing to remove")

t = re.search(r"const TOPICS = \[([^\]]*)\];", s)
if t and "'Mathematics'" in t.group(1):
    cleaned = re.sub(r",\s*'Mathematics'", "", t.group(1))
    s = s[:t.start()] + "const TOPICS = [" + cleaned + "];" + s[t.end():]
    print("  removed the 'Mathematics' chip from the Physics topic filter")
else:
    print("  Physics topic filter has no 'Mathematics' chip — nothing to remove")

if 'href="/mathematics"' in s:
    print("  Physics hub already links to Mathematics — skipping")
else:
    m = re.search(r"Type a prompt or pick a topic below\.\r?\n[ \t]*</p>", s)
    if not m:
        notes.append("Physics hub: could not find the hero paragraph, so the 'Mathematics simulations' pill was not added.")
    else:
        pill = nl.join([
            "",
            '              <Link href="/mathematics"',
            '                className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-indigo-200 bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-700 hover:bg-indigo-100 transition">',
            "                \U0001F4D0 Mathematics simulations \u2192",
            "              </Link>",
        ])
        s = s[:m.end()] + pill + s[m.end():]
        print("  added the Mathematics pill to the Physics hub hero")

if s != orig:
    write(p, s)

# ── C. Home hero link (optional) ──────────────────────────────────────
p = "src/app/page.tsx"
s = read(p)
nl = "\r\n" if "\r\n" in s else "\n"
if 'href="/mathematics"' in s:
    print("  home page already links to Mathematics — skipping")
else:
    m = re.search(r"All simulations \u2192\r?\n[ \t]*</Link>", s)
    if not m:
        notes.append("Home page: could not find the 'All simulations' link, so the 'Mathematics' link was not added.")
    else:
        link = nl.join([
            "",
            '              <Link href="/mathematics" className="text-xs text-gray-400 hover:text-indigo-600 transition">',
            "                Mathematics \u2192",
            "              </Link>",
        ])
        s = s[:m.end()] + link + s[m.end():]
        write(p, s)
        print("  added the Mathematics link to the home hero")

for n in notes:
    print("  NOTE: " + n)
if problems:
    print("")
    for pr in problems:
        print("  ERROR: " + pr)
    sys.exit(1)
PYEOF

echo ""
echo "Done. New: 'Mathematics' nav tab, /mathematics, /mathematics/unit-circle, /embed/unit-circle."
echo "Rebuild to confirm:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
