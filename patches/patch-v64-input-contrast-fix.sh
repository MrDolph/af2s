#!/bin/bash
# A-Factor STEM Studio — fix invisible/faint text in minitab input fields
# Run inside af2s/ folder: bash patches/patch-v64-input-contrast-fix.sh
#
# Root cause: src/app/globals.css sets the page's text colour to near-white
# (#ededed) automatically whenever the visitor's OS/browser is in dark mode
# (a @media (prefers-color-scheme: dark) rule on the :root --foreground
# variable, inherited by <body>). None of the minitab text/number inputs or
# <select> dropdowns set their own explicit text/background colour, so on a
# dark-mode system they silently inherited near-white text sitting on a
# white input box — exactly the "faint, barely visible" text reported.
#
# This patch adds explicit bg-white + text-gray-900 (and, for the passcode
# field, placeholder-gray-400) to every affected field, so they render
# correctly regardless of the visitor's system theme:
#   - /minitab/login             — the passcode field
#   - /minitab/eigenvector-explorer — the 4 matrix-entry number fields
#   - /minitab/legendre-bessel     — the m/n and Bessel-order dropdowns
#   - /minitab/hermite-laguerre-delta — the test-function dropdown
#
# Verified with a full `npm run build` (zero TypeScript errors, all routes
# generated) against your actual project before delivery.

set -e
echo "Applying input-contrast fix..."

mkdir -p src/app/minitab/login
mkdir -p src/app/minitab/eigenvector-explorer
mkdir -p src/app/minitab/legendre-bessel
mkdir -p src/app/minitab/hermite-laguerre-delta

echo "  fixing src/app/minitab/login/page.tsx"
cat > src/app/minitab/login/page.tsx << 'FILEEOF'
'use client';
import { Suspense, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { AppHeader } from '@/components/layout/AppHeader';

function LoginForm() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [passcode, setPasscode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const res = await fetch('/api/minitab-auth', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ passcode }),
      });
      const data = await res.json();
      if (!res.ok) {
        setError(data.error ?? 'Incorrect passcode.');
        return;
      }
      const next = searchParams.get('next') ?? '/minitab';
      router.push(next);
      router.refresh();
    } catch {
      setError('Something went wrong — check your connection and try again.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="w-full max-w-sm rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
      <p className="text-xs text-gray-400 mb-1">PHY 403 · Mathematical Methods for Physics I</p>
      <h1 className="text-lg font-semibold text-gray-900 mb-1">Student access</h1>
      <p className="text-xs text-gray-500 mb-5">
        This area is for enrolled students only. Enter the passcode your lecturer shared with you.
      </p>
      <form onSubmit={submit} className="space-y-3">
        <input
          type="password"
          value={passcode}
          onChange={e => setPasscode(e.target.value)}
          placeholder="Passcode"
          autoFocus
          className="w-full rounded-lg border border-gray-300 bg-white px-3 py-2.5 text-sm text-gray-900 placeholder-gray-400 outline-none focus:border-indigo-400"
        />
        {error && <p className="text-xs text-rose-600">{error}</p>}
        <button
          type="submit"
          disabled={loading || !passcode}
          className="w-full rounded-lg bg-indigo-600 px-4 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-50"
        >
          {loading ? 'Checking…' : 'Enter'}
        </button>
      </form>
    </div>
  );
}

export default function MinitabLoginPage() {
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50 flex items-center justify-center px-4">
        {/* useSearchParams() (inside LoginForm) requires a Suspense boundary
            in the App Router, or static export/prerendering fails the build. */}
        <Suspense fallback={<div className="text-sm text-gray-400">Loading…</div>}>
          <LoginForm />
        </Suspense>
      </main>
    </>
  );
}
FILEEOF

echo "  fixing src/app/minitab/eigenvector-explorer/page.tsx"
cat > src/app/minitab/eigenvector-explorer/page.tsx << 'FILEEOF'
'use client';
import { useState, useRef, useEffect, useCallback } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { EigenvectorCanvas } from '@/components/simulation/EigenvectorCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { PRESETS, eigen, type Matrix2x2 } from '@/lib/physics/eigen';

const TEACHER_NOTES = [
  'An eigenvector v satisfies Av=λv — A doesn\u2019t change its direction, only stretches or shrinks it by λ. Every other direction gets rotated as well as scaled.',
  'For the symmetric preset, watch the gold and purple eigenvector lines stay exactly perpendicular throughout the animation — this is the orthogonality result Chapter 6 proves for real symmetric matrices.',
  'For the pure rotation preset, there are NO real eigenvectors — every direction genuinely turns, which is exactly what "no fixed direction" means for a rotation.',
  'Vibrations and normal modes, quantum energy eigenstates (Hψ=Eψ), principal stresses in engineering, and stability of dynamical systems are all literally this same equation, Av=λv, applied to a physical operator instead of a 2×2 matrix.',
  'Diagonalization (P⁻¹AP=D) is why this matters computationally: once you know the eigenvectors, Aⁿ becomes trivial — PDⁿP⁻¹ instead of n matrix multiplications.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'Find the eigenvalues of A=[3,0;0,5].', a: 'Diagonal matrix — eigenvalues are just the diagonal entries: λ=3, λ=5.' },
  { q: 'Find the eigenvalues of A=[4,1;2,3] (characteristic equation).', a: 'det(A−λI)=(4−λ)(3−λ)−2=λ²−7λ+10=(λ−5)(λ−2)=0 → λ=5, λ=2.' },
  { q: 'For A=[2,1;1,2] (symmetric), verify the eigenvectors (1,1) and (1,−1) are orthogonal.', a: '(1,1)·(1,−1)=1−1=0 — orthogonal, as guaranteed for a symmetric matrix.' },
  { q: 'For A=[4,1;2,3], verify trace and determinant match the sum/product of eigenvalues (λ=5,2).', a: 'trace=4+3=7=5+2 ✓. det=4×3−1×2=10=5×2 ✓.' },
  { q: 'Why does a pure rotation matrix have no real eigenvectors?', a: 'A rotation changes the direction of every single vector in the plane (except for the trivial zero vector) — there is no nonzero direction it leaves unchanged, which is exactly what having a real eigenvector would require.' },
];

export default function EigenvectorExplorerPage() {
  const [presetIndex, setPresetIndex] = useState(1);
  const [matrix, setMatrix] = useState<Matrix2x2>(PRESETS[1].m);
  const [t, setT] = useState(1);
  const [animating, setAnimating] = useState(false);
  const animRef = useRef<number>(0);
  const startRef = useRef<number>(0);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 460, 460, 500);

  const applyPreset = (i: number) => { setPresetIndex(i); setMatrix(PRESETS[i].m); };
  const updateField = (key: keyof Matrix2x2) => (v: number) => {
    setPresetIndex(-1);
    setMatrix(prev => ({ ...prev, [key]: v }));
  };

  const toggleAnimate = useCallback(() => {
    if (animating) { cancelAnimationFrame(animRef.current); setAnimating(false); return; }
    setAnimating(true);
    startRef.current = performance.now();
    const step = (now: number) => {
      const elapsed = (now - startRef.current) / 1400;
      const phase = elapsed % 2;
      setT(phase <= 1 ? phase : 2 - phase);
      animRef.current = requestAnimationFrame(step);
    };
    animRef.current = requestAnimationFrame(step);
  }, [animating]);

  useEffect(() => () => cancelAnimationFrame(animRef.current), []);

  const eig = eigen(matrix);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapter 6</p>
            <h1 className="text-lg font-semibold text-gray-900">Eigenvector Explorer</h1>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="grid grid-cols-1 lg:grid-cols-[1fr_260px] xl:grid-cols-[1fr_260px_300px] gap-4">

            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm flex justify-center">
                <EigenvectorCanvas matrix={matrix} t={t} width={canvasSize.width} height={canvasSize.height} />
              </div>
              <div className="flex items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <input type="range" min={0} max={1} step={0.01} value={t}
                  onChange={e => setT(Number(e.target.value))} className="flex-1" style={{ accentColor: '#10b981' }} />
                <span className="text-xs font-mono text-gray-500 w-16 text-right">t={t.toFixed(2)}</span>
                <button onClick={toggleAnimate}
                  className="text-xs px-3 py-2 rounded-lg border border-gray-200 bg-white font-medium text-gray-600 hover:border-emerald-300 transition">
                  {animating ? '⏸ Stop' : '▶ Animate'}
                </button>
              </div>
              <div className="rounded-2xl border border-gray-100 bg-white p-4 grid grid-cols-2 gap-2">
                {(['a', 'b', 'c', 'd'] as const).map(k => (
                  <div key={k} className="space-y-1">
                    <span className="text-xs text-gray-400">{k}</span>
                    <input type="number" step={0.1} value={matrix[k]}
                      onChange={e => updateField(k)(Number(e.target.value))}
                      className="w-full rounded-lg border border-gray-300 bg-white px-2 py-1.5 text-sm font-mono text-gray-900" />
                  </div>
                ))}
              </div>
              <div className="flex flex-wrap gap-1.5">
                {PRESETS.map((p, i) => (
                  <button key={p.name} onClick={() => applyPreset(i)}
                    className={`text-xs px-3 py-2 rounded-lg border font-medium transition ${
                      presetIndex === i ? 'bg-indigo-600 text-white border-indigo-600' : 'bg-white text-gray-600 border-gray-200 hover:border-indigo-300'
                    }`}>{p.name}</button>
                ))}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">trace(A)</span>
                  <span className="text-xs font-semibold tabular-nums text-gray-700">{eig.trace.toFixed(2)}</span>
                </div>
                <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
                  <span className="text-xs text-gray-500">det(A)</span>
                  <span className="text-xs font-semibold tabular-nums text-gray-700">{eig.det.toFixed(2)}</span>
                </div>
                {eig.complex ? (
                  <p className="text-xs text-rose-600 leading-relaxed px-1 pt-1">
                    Complex eigenvalues — no real eigenvector exists. Every direction rotates.
                  </p>
                ) : (
                  <>
                    <div className="flex justify-between items-center rounded-lg bg-amber-50 px-3 py-2">
                      <span className="text-xs text-amber-700">λ₁ (gold)</span>
                      <span className="text-xs font-semibold tabular-nums text-amber-700">{eig.l1?.toFixed(3)}</span>
                    </div>
                    <div className="flex justify-between items-center rounded-lg bg-purple-50 px-3 py-2">
                      <span className="text-xs text-purple-700">λ₂ (purple)</span>
                      <span className="text-xs font-semibold tabular-nums text-purple-700">{eig.l2?.toFixed(3)}</span>
                    </div>
                  </>
                )}
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
FILEEOF

echo "  fixing src/app/minitab/legendre-bessel/page.tsx"
cat > src/app/minitab/legendre-bessel/page.tsx << 'FILEEOF'
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
FILEEOF

echo "  fixing src/app/minitab/hermite-laguerre-delta/page.tsx"
cat > src/app/minitab/hermite-laguerre-delta/page.tsx << 'FILEEOF'
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
FILEEOF

echo ""
echo "Done. Rebuild to confirm:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
