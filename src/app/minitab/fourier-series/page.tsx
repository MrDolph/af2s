'use client';
import { useState, useRef, useCallback, useEffect } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { FourierSeriesGraph } from '@/components/simulation/FourierSeriesGraph';
import { TARGETS, peakOvershoot } from '@/lib/physics/fourierSeries';

const TEACHER_NOTES = [
  "Chapter 12 derives the coefficients aₙ, bₙ from orthogonality — this shows what those coefficients actually buy you. Each harmonic is a perfectly smooth sine or cosine; stacking enough of them reproduces a sharp corner or even a jump.",
  'Away from any discontinuity, the approximation converges beautifully as N grows. Right at a jump, the overshoot settles to a fixed ≈9% of the jump height — the Gibbs phenomenon — and stays there forever, however large N gets.',
  'Compare N=5 and N=60 on the square wave: the overshoot spike gets narrower, not shorter. More terms squeeze it, never eliminate it.',
  'The triangle wave has no jump discontinuity at all, so it has no Gibbs overshoot, and converges much faster (1/n² coefficients vs 1/n for the square wave and sawtooth).',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Write the first three nonzero terms of the square-wave series.', a: '(4/π)[sin(x) + (1/3)sin(3x) + (1/5)sin(5x)].' },
  { q: 'Why does the square-wave series only contain odd harmonics?', a: 'A square wave with this symmetry (odd function, period 2π, antisymmetric about the half-period) has bₙ=0 for even n by the orthogonality integral — only odd sine terms survive.' },
  { q: "Estimate the Gibbs overshoot percentage for the square wave at large N, using the widget.", a: 'Approximately 9% of the jump height (the jump here is 2, from −1 to +1), matching the theoretical Gibbs constant ≈8.95%.' },
  { q: 'Why does the triangle wave series converge faster than the square wave series?', a: 'The triangle-wave coefficients fall off as 1/n², while the square wave and sawtooth fall off only as 1/n — faster-decaying coefficients mean each additional term contributes less, so fewer terms are needed for a good approximation.' },
  { q: 'Write the first two nonzero terms of the sawtooth series.', a: '2[sin(x) − (1/2)sin(2x)].' },
];

export default function FourierSeriesPage() {
  const [targetIndex, setTargetIndex] = useState(0);
  const [n, setN] = useState(1);
  const [animating, setAnimating] = useState(false);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);

  const target = TARGETS[targetIndex];

  const toggleAnimate = useCallback(() => {
    if (animating) {
      if (intervalRef.current) clearInterval(intervalRef.current);
      setAnimating(false);
      return;
    }
    setAnimating(true);
    intervalRef.current = setInterval(() => {
      setN(prev => (prev >= 60 ? 1 : prev + 1));
    }, 180);
  }, [animating]);

  useEffect(() => () => { if (intervalRef.current) clearInterval(intervalRef.current); }, []);

  const overshoot = peakOvershoot(target, n);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapter 12</p>
            <h1 className="text-lg font-semibold text-gray-900">Fourier Series Builder</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap gap-1.5">
            {TARGETS.map((t, i) => (
              <button key={t.name} onClick={() => { setTargetIndex(i); setN(1); }}
                className={`text-xs px-3 py-2 rounded-lg border font-medium transition ${
                  targetIndex === i ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'
                }`}>{t.name}</button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <FourierSeriesGraph target={target} n={n} />
              </div>
              <div className="flex items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <input type="range" min={1} max={60} step={1} value={n}
                  onChange={e => setN(Number(e.target.value))} className="flex-1" style={{ accentColor: '#059669' }} />
                <span className="text-xs font-mono text-gray-500 w-16 text-right">N={n}</span>
                <button onClick={toggleAnimate}
                  className="text-xs px-3 py-2 rounded-lg border border-gray-200 bg-white font-medium text-gray-600 hover:border-emerald-300 transition">
                  {animating ? '⏸ Stop' : '▶ Animate'}
                </button>
              </div>
              <p className="text-[11px] font-mono text-gray-400 px-1">{target.formula}</p>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">Terms used</span>
                  <span className="text-xs font-semibold tabular-nums text-gray-700">N={n}</span>
                </div>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">Peak overshoot near jump</span>
                  <span className="text-xs font-semibold tabular-nums text-amber-600">{target.hasJump ? `${overshoot.toFixed(1)}%` : 'n/a'}</span>
                </div>
              </div>
              {target.hasJump && n > 5 && (
                <div className="rounded-2xl border border-amber-100 bg-amber-50 p-3">
                  <p className="text-[11px] text-amber-800 leading-relaxed">
                    Overshoot holds near 9% however large N gets — that&apos;s the Gibbs phenomenon.
                  </p>
                </div>
              )}
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES.map((note, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{note}
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
