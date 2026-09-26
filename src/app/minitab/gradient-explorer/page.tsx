'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { GradientExplorerCanvas } from '@/components/simulation/GradientExplorerCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { FIELDS } from '@/lib/physics/gradientField';

const TEACHER_NOTES = [
  "D_â φ = ∇φ · â replaces Chapter 1's slow limit-definition calculation with a single dot product — find ∇φ once at a point, then any directional derivative there is just a dot product away.",
  "∇φ always points in the direction of steepest increase of φ, and its magnitude |∇φ| IS the steepest rate of increase.",
  "Drag the gold handle until it's perpendicular to the green gradient arrow — the readout drops to ≈0. That's exactly why level curves and ∇φ are always perpendicular: moving along a level curve means φ doesn't change at all.",
  "Drag the gold handle to point the opposite way from ∇φ and watch D_âφ hit its most negative value −|∇φ| — steepest decrease.",
  "Try the saddle field x²−y² at the origin: ∇φ=0 there (a stationary point), and every direction gives D_âφ=0 — the classic saddle-point signature.",
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'For φ=x²+y², find ∇φ at (1,1) and its magnitude.', a: '∇φ=(2x,2y)=(2,2) at (1,1). |∇φ|=√(4+4)=√8≈2.83.' },
  { q: 'Using the gradient from above, find D_âφ in direction â=(1/√2,1/√2).', a: 'D_âφ=∇φ·â=2(1/√2)+2(1/√2)=4/√2=2√2≈2.83 — matches |∇φ| exactly, since â is aligned with ∇φ here.' },
  { q: 'For φ=xy, find ∇φ at (2,3) and the direction of steepest ascent.', a: '∇φ=(y,x)=(3,2) at (2,3). Direction: (3,2)/|(3,2)|=(3,2)/√13≈(0.83,0.55).' },
  { q: 'At what points does ∇φ=0 for φ=x²−y²?', a: 'Only at the origin (0,0), where both 2x=0 and −2y=0 — the saddle point.' },
  { q: 'Explain why moving along a level curve always gives D_âφ=0.', a: 'A level curve is defined by φ=constant, so by definition φ does not change as you move along it — and D_âφ measures exactly that rate of change, so it must be zero in that direction.' },
];

export default function GradientExplorerPage() {
  const [fieldIndex, setFieldIndex] = useState(0);
  const [point, setPoint] = useState({ x: 1.3, y: 0.9 });
  const [angleDeg, setAngleDeg] = useState(45);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 480, 480, 520);

  const field = FIELDS[fieldIndex];
  const gx = field.gx(point.x, point.y), gy = field.gy(point.x, point.y);
  const gmag = Math.hypot(gx, gy);
  const rad = (angleDeg * Math.PI) / 180;
  const dirDeriv = gx * Math.cos(rad) + gy * Math.sin(rad);
  const phi = field.f(point.x, point.y);

  let interpretation = 'D_âφ = ∇φ·â = |∇φ|cosθ — rotate the handle and watch this hold exactly.';
  const cosAngle = gmag > 1e-6 ? dirDeriv / gmag : 0;
  if (gmag < 0.05) {
    interpretation = '∇φ ≈ 0 here — a stationary point. Every direction gives D_âφ ≈ 0.';
  } else if (Math.abs(cosAngle) > 0.97) {
    interpretation = cosAngle > 0
      ? 'â is aligned with ∇φ — steepest increase, D_âφ at its maximum |∇φ|.'
      : 'â points opposite to ∇φ — steepest decrease, D_âφ at its minimum −|∇φ|.';
  } else if (Math.abs(dirDeriv) < 0.05 * gmag) {
    interpretation = "â is perpendicular to ∇φ — you're moving along the level curve; φ barely changes.";
  }

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapters 1–2</p>
            <h1 className="text-lg font-semibold text-gray-900">Gradient &amp; Directional Derivative Explorer</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap gap-1.5">
            {FIELDS.map((f, i) => (
              <button key={f.name} onClick={() => setFieldIndex(i)}
                className={`text-xs px-3 py-2 rounded-lg border font-medium transition ${
                  fieldIndex === i ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'
                }`}>{f.name}</button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm flex justify-center">
                <GradientExplorerCanvas
                  fieldIndex={fieldIndex} point={point} angleDeg={angleDeg}
                  onPointChange={setPoint} onAngleChange={setAngleDeg}
                  width={canvasSize.width} height={canvasSize.height}
                />
              </div>
              <div className="rounded-2xl border border-emerald-100 bg-emerald-50 p-4">
                <p className="text-xs text-emerald-900 leading-relaxed">{interpretation}</p>
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                {[
                  { l: 'Point (x,y)', v: `(${point.x.toFixed(2)}, ${point.y.toFixed(2)})`, c: 'text-gray-700' },
                  { l: 'φ(x,y)', v: phi.toFixed(3), c: 'text-gray-700' },
                  { l: '∇φ', v: `(${gx.toFixed(2)}, ${gy.toFixed(2)})`, c: 'text-emerald-600' },
                  { l: '|∇φ|', v: gmag.toFixed(3), c: 'text-emerald-600' },
                  { l: 'â direction', v: `${angleDeg.toFixed(0)}°`, c: 'text-amber-600' },
                  { l: 'D_âφ = ∇φ·â', v: dirDeriv.toFixed(3), c: 'text-indigo-600' },
                ].map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
              </div>
              <p className="text-[11px] text-gray-400 px-1">Drag the blue point to move; drag the gold arrowhead to change direction â.</p>
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
              <ExerciseList />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}

function ExerciseList() {
  const [openEx, setOpenEx] = useState<number | null>(null);
  return (
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
  );
}
