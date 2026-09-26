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
