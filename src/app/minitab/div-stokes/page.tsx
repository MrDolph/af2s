'use client';
import { useState, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { DivStokesCanvas } from '@/components/simulation/DivStokesCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { FIELDS, boundaryIntegrals, areaIntegrals } from '@/lib/physics/divStokes';

const TEACHER_NOTES = [
  "Chapter 3's divergence theorem and Chapter 4's Stokes'/Green's theorem both say the same kind of thing: a boundary measurement equals an interior sum.",
  'Flux (F·n̂ around the edge) always equals ∬(∇·F)dA (divergence summed over the disk) — move or resize the disk and both numbers stay locked together.',
  'Circulation (F·dl around the edge) always equals ∬(∇×F)_z dA (curl summed over the disk) — same guarantee, independently verified here by direct numerical integration.',
  'Try the "Rotation" field: circulation is large and flux is exactly zero — a pure rotation has no divergence anywhere.',
  'Try the "Source" field: flux is large and circulation is exactly zero — pure radial outflow has no curl anywhere.',
];

const EXERCISES: { q: string; a: string }[] = [
  { q: 'For F=(x,y), find ∇·F.', a: '∇·F=∂x/∂x+∂y/∂y=1+1=2 (constant everywhere — matches the "Source" field always showing the same flux-per-area).' },
  { q: 'For F=(−y,x), find ∇×F (the z-component).', a: '(∇×F)_z=∂x/∂x−∂(−y)/∂y=1−(−1)=2 (constant — matches "Rotation" always showing the same circulation-per-area).' },
  { q: "Explain why the disk's flux and ∬∇·F dA must always agree, using the 'tiling with tiny boxes' argument.", a: 'Tiling the disk with a fine grid, each tiny box contributes flux (∇·F)×(its area); at every shared internal edge, outflow from one box exactly equals inflow to its neighbour, so those contributions cancel. Only the outer boundary survives — which is exactly the flux integral.' },
  { q: 'For the "Mixed" field F=(x−y,x+y), find both ∇·F and (∇×F)_z.', a: '∇·F=1+1=2. (∇×F)_z=1−(−1)=2. Both are nonzero and equal here, matching what the live readout shows for this preset.' },
  { q: 'Why does moving the disk to a different location not change the flux or circulation for the fields shown here?', a: 'All five preset fields have divergence and curl that are either constant or depend simply on position in a way that, combined with symmetric disk placement, gives the same total when integrated over any disk of the same radius — try it and check against the readout.' },
];

export default function DivStokesPage() {
  const [fieldIndex, setFieldIndex] = useState(0);
  const [disk, setDisk] = useState({ cx: 0.5, cy: 0.3, r: 1.1 });

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 480, 480, 520);

  const field = FIELDS[fieldIndex];
  const { circulation, flux } = boundaryIntegrals(field, disk.cx, disk.cy, disk.r);
  const { divIntegral, curlIntegral } = areaIntegrals(field, disk.cx, disk.cy, disk.r);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <p className="text-xs text-gray-400 mb-0.5">PHY 403 — Chapters 3–4</p>
            <h1 className="text-lg font-semibold text-gray-900">Divergence &amp; Stokes&apos; Theorem Visualizer</h1>
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
                <DivStokesCanvas fieldIndex={fieldIndex} disk={disk} onDiskChange={setDisk} width={canvasSize.width} height={canvasSize.height} />
              </div>
              <div className="flex items-center gap-3 rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <span className="text-xs text-gray-500 shrink-0">Disk radius r</span>
                <input type="range" min={0.4} max={2.2} step={0.05} value={disk.r}
                  onChange={e => setDisk(d => ({ ...d, r: Number(e.target.value) }))}
                  className="flex-1" style={{ accentColor: '#2563eb' }} />
                <span className="text-xs font-mono text-gray-500 w-14 text-right">{disk.r.toFixed(2)}</span>
              </div>
              <p className="text-[11px] text-gray-400 px-1">Drag the disk directly on the canvas to move it.</p>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
                <p className="text-xs font-medium uppercase tracking-wide text-gray-400 mb-2">Live readout</p>
                {[
                  { l: 'Flux ∮F·n̂dl', v: flux.toFixed(3), c: 'text-blue-600' },
                  { l: '∬(∇·F)dA', v: divIntegral.toFixed(3), c: 'text-blue-600' },
                  { l: 'Circulation ∮F·dl', v: circulation.toFixed(3), c: 'text-emerald-600' },
                  { l: '∬(∇×F)_z dA', v: curlIntegral.toFixed(3), c: 'text-emerald-600' },
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
