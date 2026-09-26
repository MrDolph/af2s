'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { HermiteLaguerreGraph, DiracDeltaGraph } from '@/components/simulation/HermiteLaguerreDeltaGraph';
import { deltaIntegrals, testFn } from '@/lib/physics/hermiteLaguerreDelta';

const TEACHER_NOTES = [
  'Hermite polynomials, weighted by e⁻ˣ², are exactly the spatial part of the quantum harmonic oscillator\u2019s energy eigenstates — Hₙ(x)e⁻ˣ²/² is (up to normalisation) the n-th excited-state wavefunction.',
  'Laguerre polynomials, weighted by e⁻ˣ, are exactly the radial part of the hydrogen atom\u2019s wavefunctions — different n give different electron shells.',
  'Chapter 11 defines δ(x) by two properties — zero everywhere except x=0, total area 1 — rather than by a formula, because no ordinary function has both at once.',
  'Drag ε down toward zero on the delta tab: the pulse gets taller and narrower, the area stays exactly 1 the whole time, and ∫f(x)δ_ε(x)dx converges to f(0) — the sifting property, made concrete.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Using H₀=1, H₁=2x and the recurrence Hₙ₊₁=2xHₙ−2nHₙ₋₁, find H₂(x).', a: 'H₂=2xH₁−2(1)H₀=2x(2x)−2=4x²−2.' },
  { q: 'Using L₀=1, L₁=1−x and the recurrence, find L₂(1).', a: '(n+1)Lₙ₊₁=(2n+1−x)Lₙ−nLₙ₋₁ with n=1,x=1: 2L₂=(3−1)(0)−1(1)=−1 → L₂(1)=−0.5.' },
  { q: 'State the two defining properties of the Dirac delta function δ(x).', a: 'δ(x)=0 for all x≠0, and ∫₋∞^∞δ(x)dx=1 (all the "mass" concentrated at a single point).' },
  { q: 'State the sifting property of δ(x).', a: '∫f(x)δ(x−a)dx=f(a) for any well-behaved f — the delta function "picks out" the value of f at the point where the delta spike sits.' },
  { q: 'Why can no ordinary function satisfy both defining properties of δ(x) exactly?', a: 'A function that is zero everywhere except a single point has zero area under any reasonable (Riemann) integral, no matter how "tall" it is at that one point — so no ordinary function can have zero width AND nonzero total area. δ(x) is instead defined as the limit of a family of functions (like the narrowing Gaussian shown here), not as a function itself.' },
];

const FN_OPTIONS = [
  { value: 'quad', label: 'f(x) = x² · 0.15 + 1' },
  { value: 'sin', label: 'f(x) = sin(x) · 0.8 + 2' },
  { value: 'cube', label: 'f(x) = cubic' },
];

export default function HermiteLaguerreDeltaPage() {
  const [mode, setMode] = useState<'hermite' | 'laguerre' | 'delta'>('hermite');
  const [shownH, setShownH] = useState([0, 1, 2, 3]);
  const [shownL, setShownL] = useState([0, 1, 2, 3]);
  const [epsExp, setEpsExp] = useState(0);
  const [fname, setFname] = useState('quad');

  const toggle = (arr: number[], set: (v: number[]) => void) => (i: number) =>
    set(arr.includes(i) ? arr.filter(v => v !== i) : [...arr, i]);

  const eps = Math.pow(10, epsExp);
  const { area, sift } = mode === 'delta' ? deltaIntegrals(eps, fname) : { area: 0, sift: 0 };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapter 11</p>
            <h1 className="text-lg font-semibold text-gray-900">Hermite, Laguerre &amp; the Dirac Delta</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1.5 flex-wrap">
            {(['hermite', 'laguerre', 'delta'] as const).map(m => (
              <button key={m} onClick={() => setMode(m)}
                className={`text-xs px-4 py-2 rounded-lg border font-medium capitalize transition ${mode === m ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200'}`}>
                {m === 'delta' ? 'Dirac delta' : m}
              </button>
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                {mode === 'hermite' && <HermiteLaguerreGraph mode="hermite" shown={shownH} />}
                {mode === 'laguerre' && <HermiteLaguerreGraph mode="laguerre" shown={shownL} />}
                {mode === 'delta' && <DiracDeltaGraph eps={eps} fname={fname} />}
              </div>

              {mode === 'hermite' && (
                <div className="flex flex-wrap gap-1.5 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                  {Array.from({ length: 7 }, (_, i) => i).map(i => (
                    <label key={i} className="flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-lg border border-gray-100 cursor-pointer">
                      <input type="checkbox" checked={shownH.includes(i)} onChange={() => toggle(shownH, setShownH)(i)} className="accent-indigo-600" />H{i}
                    </label>
                  ))}
                </div>
              )}
              {mode === 'laguerre' && (
                <div className="flex flex-wrap gap-1.5 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                  {Array.from({ length: 6 }, (_, i) => i).map(i => (
                    <label key={i} className="flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-lg border border-gray-100 cursor-pointer">
                      <input type="checkbox" checked={shownL.includes(i)} onChange={() => toggle(shownL, setShownL)(i)} className="accent-indigo-600" />L{i}
                    </label>
                  ))}
                </div>
              )}
              {mode === 'delta' && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                  <div className="flex items-center gap-3">
                    <span className="text-xs text-gray-500 shrink-0">Narrow the pulse (ε)</span>
                    <input type="range" min={-2} max={0.3} step={0.02} value={epsExp} onChange={e => setEpsExp(Number(e.target.value))} className="flex-1" style={{ accentColor: '#2563eb' }} />
                    <span className="text-xs font-mono text-gray-500 w-16 text-right">{eps.toFixed(3)}</span>
                  </div>
                  <select value={fname} onChange={e => setFname(e.target.value)} className="w-full rounded-lg border border-gray-300 bg-white px-2 py-1.5 text-xs text-gray-900">
                    {FN_OPTIONS.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
                  </select>
                </div>
              )}
            </div>

            <div className="space-y-3">
              {mode === 'delta' && (
                <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                  {[
                    { l: 'Total area ∫δ_ε dx', v: area.toFixed(4), c: 'text-indigo-600' },
                    { l: '∫f(x)δ_ε(x)dx', v: sift.toFixed(4), c: 'text-emerald-600' },
                    { l: 'f(0) (target)', v: testFn(fname, 0).toFixed(4), c: 'text-gray-700' },
                  ].map(r => (
                    <div key={r.l} className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                      <span className="text-xs text-gray-500">{r.l}</span>
                      <span className={`text-xs font-semibold tabular-nums ${r.c}`}>{r.v}</span>
                    </div>
                  ))}
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
