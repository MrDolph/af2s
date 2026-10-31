'use client';
import { useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { LegendreBesselGraph } from '@/components/simulation/LegendreBesselGraph';
import { legendreOrthogonality, besselJ } from '@/lib/physics/legendreBessel';

const TEACHER_NOTES = [
  'Chapter 9 proves ∫₋₁¹PₘPₙdx=0 for m≠n and =2/(2n+1) for m=n. Pick any two orders below and the panel computes that integral directly by numerical quadrature — you should see essentially zero off the diagonal and an exact match to 2/(2n+1) on it.',
  "Chapter 10's recurrence Jₙ₋₁(x)+Jₙ₊₁(x)=(2n/x)Jₙ(x) links three different Bessel orders at the same point. Drag x and watch both sides — computed completely independently via the integral definition of Jₙ — stay equal.",
  'Bessel functions oscillate with slowly decreasing amplitude, unlike Legendre polynomials which are confined to [−1,1] — this reflects the very different boundary conditions each equation is solved under.',
  'Legendre polynomials with even n are even functions, odd n are odd functions — visible directly in the P₀…P₆ overlay.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'State the value of Pₙ(1) for every n.', a: 'Pₙ(1)=1 for every n — visible in the graph as all curves passing through (1,1).' },
  { q: 'Using the three-term recurrence (n+1)Pₙ₊₁=(2n+1)xPₙ−nPₙ₋₁ with P₀=1, P₁=x, find P₂(x).', a: '2P₂=3xP₁−1×P₀=3x²−1 → P₂(x)=(3x²−1)/2.' },
  { q: 'What is ∫₋₁¹[P₃(x)]²dx, according to the normalisation formula?', a: '2/(2n+1) with n=3: 2/7≈0.2857.' },
  { q: 'State the value of Jₙ(0) for n=0 and for n≥1.', a: 'J₀(0)=1; Jₙ(0)=0 for every n≥1 — visible in the graph as only J₀ starting at height 1.' },
  { q: 'Using the recurrence, express J₃(x) in terms of J₂(x) and J₄(x) rearranged.', a: 'From J₂+J₄=(6/x)J₃ is not directly this form — instead use Jₙ₋₁+Jₙ₊₁=(2n/x)Jₙ with n=3: J₂(x)+J₄(x)=(6/x)J₃(x), so J₃(x)=[J₂(x)+J₄(x)]·x/6.' },
];

export default function LegendreBesselPage() {
  const [mode, setMode] = useState<'legendre' | 'bessel'>('legendre');
  const [shown, setShown] = useState<number[]>([0, 1, 2, 3]);
  const [m, setM] = useState(2);
  const [n, setN] = useState(3);
  const [besN, setBesN] = useState(2);
  const [besX, setBesX] = useState(5);

  const toggle = (i: number) => setShown(prev => prev.includes(i) ? prev.filter(v => v !== i) : [...prev, i]);

  const orthIntegral = legendreOrthogonality(m, n);
  const expected = m === n ? 2 / (2 * n + 1) : 0;

  const Jn = besselJ(besN, besX), Jm1 = besselJ(besN - 1, besX), Jp1 = besselJ(besN + 1, besX);
  const lhs = Jm1 + Jp1, rhs = (2 * besN / besX) * Jn;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapters 9–10</p>
            <h1 className="text-lg font-semibold text-gray-900">Legendre &amp; Bessel Explorer</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1.5">
            <button onClick={() => setMode('legendre')}
              className={`text-xs px-4 py-2 rounded-lg border font-medium transition ${mode === 'legendre' ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200'}`}>Legendre Pₙ(x)</button>
            <button onClick={() => setMode('bessel')}
              className={`text-xs px-4 py-2 rounded-lg border font-medium transition ${mode === 'bessel' ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200'}`}>Bessel Jₙ(x)</button>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">
            <div className="space-y-3 min-w-0">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <LegendreBesselGraph mode={mode} shown={shown} />
              </div>
              <div className="flex flex-wrap gap-1.5 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                {Array.from({ length: 7 }, (_, i) => i).map(i => (
                  <label key={i} className="flex items-center gap-1.5 text-xs px-2.5 py-1.5 rounded-lg border border-gray-100 cursor-pointer hover:border-indigo-200">
                    <input type="checkbox" checked={shown.includes(i)} onChange={() => toggle(i)} className="accent-indigo-600" />
                    {mode === 'legendre' ? 'P' : 'J'}{i}
                  </label>
                ))}
              </div>
            </div>

            <div className="space-y-3">
              {mode === 'legendre' ? (
                <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-3">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Orthogonality check</p>
                  <div className="flex gap-2 items-center">
                    <span className="text-xs text-gray-500">m=</span>
                    <select value={m} onChange={e => setM(Number(e.target.value))} className="rounded-lg border border-gray-300 bg-white px-2 py-1 text-xs text-gray-900">
                      {Array.from({ length: 7 }, (_, i) => i).map(i => <option key={i} value={i}>{i}</option>)}
                    </select>
                    <span className="text-xs text-gray-500">n=</span>
                    <select value={n} onChange={e => setN(Number(e.target.value))} className="rounded-lg border border-gray-300 bg-white px-2 py-1 text-xs text-gray-900">
                      {Array.from({ length: 7 }, (_, i) => i).map(i => <option key={i} value={i}>{i}</option>)}
                    </select>
                  </div>
                  <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">∫₋₁¹PₘPₙdx</span>
                    <span className="text-xs font-semibold tabular-nums text-indigo-600">{orthIntegral.toFixed(5)}</span>
                  </div>
                  <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">Expected (theory)</span>
                    <span className="text-xs font-semibold tabular-nums text-emerald-600">{expected.toFixed(5)}</span>
                  </div>
                </div>
              ) : (
                <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-3">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Recurrence check</p>
                  <div className="flex gap-2 items-center">
                    <span className="text-xs text-gray-500">n=</span>
                    <select value={besN} onChange={e => setBesN(Number(e.target.value))} className="rounded-lg border border-gray-300 bg-white px-2 py-1 text-xs text-gray-900">
                      {[1, 2, 3, 4, 5].map(i => <option key={i} value={i}>{i}</option>)}
                    </select>
                  </div>
                  <input type="range" min={0.5} max={14.5} step={0.1} value={besX} onChange={e => setBesX(Number(e.target.value))} className="w-full" style={{ accentColor: '#059669' }} />
                  <p className="text-xs text-gray-500 text-right">x={besX.toFixed(2)}</p>
                  <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">J_(n-1)+J_(n+1)</span>
                    <span className="text-xs font-semibold tabular-nums text-indigo-600">{lhs.toFixed(5)}</span>
                  </div>
                  <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                    <span className="text-xs text-gray-500">(2n/x)·Jₙ</span>
                    <span className="text-xs font-semibold tabular-nums text-emerald-600">{rhs.toFixed(5)}</span>
                  </div>
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
