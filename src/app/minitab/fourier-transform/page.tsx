'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { FourierTransformGraph } from '@/components/simulation/FourierTransformGraph';
import { PAIRS } from '@/lib/physics/fourierTransform';

const TEACHER_NOTES = [
  "Chapter 13 derives the shift, scaling, and derivative theorems algebraically — this shows what the scaling theorem actually looks like. Narrow f(x) and F(k) visibly spreads out; widen f(x) and F(k) narrows to a spike.",
  'You can never shrink both f(x) and F(k) at once — Δx·Δk stays roughly constant, the same mathematical statement behind Heisenberg\u2019s uncertainty principle, since quantum mechanics represents momentum-space wavefunctions as the Fourier transform of position-space ones.',
  'The rectangular pulse transforms to a sinc function — notice the oscillating "ringing" in F(k), a direct consequence of the sharp edges in f(x).',
  'The Gaussian is the one function whose transform has exactly the same shape as itself — this special property is why Gaussian wave packets are the natural building block in quantum mechanics.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'For a rectangular pulse of half-width a=2, find F(0).', a: 'F(0)=2a=4 (the limit of 2sin(ka)/k as k→0).' },
  { q: 'For a Gaussian with a=1, find F(0).', a: 'F(0)=a√(2π)=√(2π)≈2.507.' },
  { q: 'For a decaying exponential with a=1, find F(0).', a: 'F(0)=2a/(1+0)=2a=2.' },
  { q: 'Explain, using the widget, what happens to F(k) as the width parameter a of a Gaussian increases.', a: 'As a increases (f(x) gets wider), F(k) gets narrower — this is the scaling/uncertainty trade-off: F(k)=a√(2π)e^(−a²k²/2) has its width controlled by 1/a, inversely to f(x)\u2019s width, which is controlled by a.' },
  { q: 'Why does the rectangular pulse\u2019s transform oscillate (the sinc function) while the Gaussian\u2019s does not?', a: 'The rectangular pulse has sharp, discontinuous edges, which require high-frequency components to reproduce — these high frequencies interfere constructively and destructively as k varies, producing the sinc oscillation. The Gaussian is infinitely smooth with no sharp features, so its transform decays smoothly with no oscillation.' },
];

export default function FourierTransformPage() {
  const [pairIndex, setPairIndex] = useState(0);
  const [a, setA] = useState(1);

  const pair = PAIRS[pairIndex];

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapter 13</p>
            <h1 className="text-lg font-semibold text-gray-900">Fourier Transform Pairs</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex flex-wrap gap-1.5">
            {PAIRS.map((p, i) => (
              <button key={p.name} onClick={() => setPairIndex(i)}
                className={`text-xs px-3 py-2 rounded-lg border font-medium transition ${
                  pairIndex === i ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'
                }`}>{p.name}</button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <FourierTransformGraph pair={pair} a={a} />
              </div>
              <div className="flex items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <span className="text-xs text-gray-500 shrink-0">Width a</span>
                <input type="range" min={0.2} max={3} step={0.01} value={a}
                  onChange={e => setA(Number(e.target.value))} className="flex-1" style={{ accentColor: '#2563eb' }} />
                <span className="text-xs font-mono text-gray-500 w-14 text-right">{a.toFixed(2)}</span>
              </div>
              <p className="text-[11px] font-mono text-gray-400 px-1">{pair.formula}</p>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">Width parameter a</span>
                  <span className="text-xs font-semibold tabular-nums text-gray-700">{a.toFixed(2)}</span>
                </div>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">f(0)</span>
                  <span className="text-xs font-semibold tabular-nums text-blue-600">{pair.f(0.0001, a).toFixed(3)}</span>
                </div>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">F(0) = ∫f(x)dx</span>
                  <span className="text-xs font-semibold tabular-nums text-emerald-600">{pair.F(0.0001, a).toFixed(3)}</span>
                </div>
              </div>
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
