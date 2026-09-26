'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { GammaGraph } from '@/components/simulation/GammaGraph';
import { gamma } from '@/lib/physics/gammaFunction';

const TEACHER_NOTES = [
  'Γ(x+1)=xΓ(x), derived by integration by parts, explains everything on this graph: run it forward and Γ(n+1)=n! at every positive integer (green dots); run it backward and it forces Γ(x) to blow up at x=0,−1,−2,…',
  'Try dragging x from 1 to 6 and watch Γ(x+1) computed two ways — directly, and via x·Γ(x) — always match exactly.',
  'Γ(½)=√π is the one value that does NOT come from the recurrence — Chapter 8 derives it from the Gaussian integral instead. Every other half-integer value follows from it by the recurrence.',
  'Toggle "Show negative branches" and drag just past x=0 or x=−1 — the value shoots toward ±∞, the poles predicted by the recurrence relation.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Find Γ(5) using Γ(n+1)=n!.', a: 'Γ(5)=4!=24.' },
  { q: 'Find Γ(7) using the recurrence Γ(x+1)=xΓ(x), starting from Γ(6)=120.', a: 'Γ(7)=6×Γ(6)=6×120=720=6!.' },
  { q: 'Find Γ(3/2) using Γ(1/2)=√π and the recurrence.', a: 'Γ(3/2)=Γ(1/2+1)=(1/2)Γ(1/2)=√π/2≈0.8862.' },
  { q: 'Explain, without calculating, why Γ(x) must be undefined at x=−3.', a: 'Rearranging the recurrence gives Γ(x)=Γ(x+1)/x, which blows up whenever the denominator hits an integer where Γ is finite and nonzero above it — chaining this down from Γ(1)=1 forces a pole at every non-positive integer, including x=−3.' },
  { q: 'Find Γ(5/2) using Γ(3/2) from the previous question.', a: 'Γ(5/2)=(3/2)Γ(3/2)=(3/2)(√π/2)=3√π/4≈1.3293.' },
];

export default function GammaExplorerPage() {
  const [x, setX] = useState(1.5);
  const [showNegative, setShowNegative] = useState(true);

  const gx = gamma(x);
  const isNearPole = Math.abs(x - Math.round(x)) < 0.01 && x <= 0;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapter 8</p>
            <h1 className="text-lg font-semibold text-gray-900">Gamma Function Explorer</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <GammaGraph x={x} showNegative={showNegative} />
              </div>
              <div className="flex flex-wrap items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <span className="text-xs text-gray-500 shrink-0">Evaluate at x</span>
                <input type="range" min={showNegative ? -4.5 : 0.05} max={6} step={0.01} value={x}
                  onChange={e => setX(Number(e.target.value))} className="flex-1" style={{ accentColor: '#10b981' }} />
                <span className="text-xs font-mono text-gray-500 w-14 text-right">{x.toFixed(2)}</span>
              </div>
              <label className="flex items-center gap-2 text-xs text-gray-600 px-1 cursor-pointer">
                <input type="checkbox" checked={showNegative} onChange={e => setShowNegative(e.target.checked)} className="accent-indigo-600" />
                Show negative-x branches
              </label>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                {[
                  { l: 'x', v: x.toFixed(2), c: 'text-gray-700' },
                  { l: 'Γ(x)', v: isNearPole ? '±∞ (pole)' : isFinite(gx) ? gx.toFixed(4) : '±∞', c: 'text-indigo-600' },
                  { l: 'Γ(x+1) = x·Γ(x)', v: isFinite(gx) ? (x * gx).toFixed(4) : '—', c: 'text-emerald-600' },
                  { l: 'Γ(x+1) direct', v: isFinite(gamma(x + 1)) ? gamma(x + 1).toFixed(4) : '—', c: 'text-emerald-600' },
                ].map(r => (
                  <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">{r.l}</span>
                    <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                  </div>
                ))}
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
