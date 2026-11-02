'use client';
import { Suspense, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { SpaceCanvas } from '@/components/simulation/SpaceCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { type Dim, type P3, type View, DEFAULT_VIEW, LABELS, P, RANGE, analyseJourney, clampDim, clampTo, coordText, fmt, len } from '@/lib/physics/space';

// Parses "x,y,z;x,y,z" and clamps every value so a hand-edited URL can't break the simulation.
function parsePoints(raw: string | null, dim: Dim): P3[] {
  const r = RANGE[dim];
  const pts = (raw ?? '').split(';').slice(0, 5).map(t => { const [x, y, z] = t.split(',').map(Number); return clampDim(P(clampTo(Number.isFinite(x) ? x : 0, r), clampTo(Number.isFinite(y) ? y : 0, r), clampTo(Number.isFinite(z) ? z : 0, r)), dim); });
  return pts.length ? pts : [P(3, 2, 4)].map(p => clampDim(p, dim));
}

function SpaceEmbedInner() {
  const sp = useSearchParams();
  const dim: Dim = sp.get('dim') === '1d' ? '1d' : sp.get('dim') === '2d' ? '2d' : '3d';
  const act = sp.get('act') === 'journey' ? 'journey' : 'locate';
  const [pts, setPts] = useState<P3[]>(() => { const p = parsePoints(sp.get('pts'), dim); return act === 'journey' && p.length < 2 ? [P(0, 0, 0), ...p] : p; });
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const [sel, setSel] = useState(0);
  const J = analyseJourney(pts, dim);
  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 640, dim === '3d' ? 420 : 380, 900);
  const width = size.width, height = width < 560 ? Math.round(width * (dim === '1d' ? 0.62 : 1.0)) : size.height;

  return (
    <div className="mx-auto max-w-3xl p-3">
      <div ref={boxRef} className="overflow-hidden rounded-xl border border-gray-200 p-1">
        <SpaceCanvas dim={dim} activity={act} width={width} height={height} points={act === 'journey' ? pts : [pts[0]]} labels={act === 'journey' ? LABELS : ['P']}
          selected={sel} onMove={(i, p) => setPts(s => s.map((q, k) => (k === i ? p : q)))} onSelect={setSel} snap={1} view={view} onView={setView} dragAxis="floor"
          showPlanes showGrid showGuides showComponents />
      </div>
      <div className="mt-2 grid gap-2 text-xs sm:grid-cols-2">
        {act === 'locate' ? (
          <>
            <div className="rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">Position </span><span className="font-semibold text-red-600">{coordText(pts[0], dim)}</span></div>
            <div className="rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">Distance from O </span><span className="font-semibold text-indigo-600">{fmt(len(pts[0]))}</span></div>
          </>
        ) : (
          <>
            <div className="rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">Distance </span><span className="font-semibold text-indigo-600">{fmt(J.distance)}</span></div>
            <div className="rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">|Displacement| </span><span className="font-semibold text-rose-600">{fmt(J.magnitude)}</span></div>
          </>
        )}
      </div>
      <p className="mt-1.5 text-[10px] text-gray-400">{dim === '3d' ? 'Drag empty space to rotate. ' : ''}Drag a point to move it. A-Factor STEM Studio</p>
    </div>
  );
}

export default function SpaceEmbedPage() {
  return <Suspense fallback={<div className="p-6 text-sm text-gray-400">Loading…</div>}><SpaceEmbedInner /></Suspense>;
}
