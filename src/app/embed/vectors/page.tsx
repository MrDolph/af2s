'use client';
import { Suspense, useRef, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { VectorCanvas } from '@/components/simulation/VectorCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { type P3, type View, DEFAULT_VIEW, P, clampTo, fmt } from '@/lib/physics/space';
import { type VMode, add, angleBetween, compText, cross, dot, mag, minus, scale, sceneFor } from '@/lib/physics/vectors';

const MODES: VMode[] = ['components', 'add', 'scalar', 'dot', 'cross'];
// "x,y,z" with every value clamped, so a hand-edited URL cannot break the simulation.
const vec = (raw: string | null, dim: '2d' | '3d', fallback: P3): P3 => {
  if (!raw) return fallback;
  const [x, y, z] = raw.split(',').map(Number);
  const c = (n: number) => (Number.isFinite(n) ? clampTo(n, 40) : 0);
  return P(c(x), c(y), dim === '3d' ? c(z) : 0);
};

function VectorsEmbedInner() {
  const sp = useSearchParams();
  const dim: '2d' | '3d' = sp.get('dim') === '3d' ? '3d' : '2d';
  const m = sp.get('mode') as VMode | null;
  const mode: VMode = m && MODES.includes(m) ? m : 'add';
  const [A, setA] = useState<P3>(() => vec(sp.get('A'), dim, dim === '2d' ? P(3, 4) : P(3, 2, 1)));
  const [B, setB] = useState<P3>(() => vec(sp.get('B'), dim, dim === '2d' ? P(-1, 2) : P(1, 3, 2)));
  const k = Number.isFinite(Number(sp.get('k'))) ? clampTo(Number(sp.get('k')), 10) : 2;
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 640, dim === '3d' ? 420 : 400, 900);
  const h = size.width < 560 ? Math.round(size.width) : size.height;
  const scene = sceneFor(mode, dim, { A, B, C: P(), k, op: 'A+B', method: 'triangle', useC: false, showComponents: true, showUnit: false, showAngle: true });
  const onHandle = (id: 'A' | 'B' | 'C', at: P3) => {
    const hd = scene.handles.find(x => x.id === id); if (!hd) return;
    const v = scale(minus(at, hd.base), hd.mul ?? 1);
    if (id === 'A') setA(dim === '2d' ? P(v.x, v.y) : v); else if (id === 'B') setB(dim === '2d' ? P(v.x, v.y) : v);
  };
  const stat = (label: string, value: string) => <div className="rounded-lg bg-gray-50 px-3 py-2"><span className="text-gray-500">{label} </span><span className="font-semibold text-gray-900">{value}</span></div>;
  const ang = angleBetween(A, B);

  return (
    <div className="mx-auto max-w-3xl p-3">
      <div ref={boxRef} className="overflow-hidden rounded-xl border border-gray-200 p-1">
        <VectorCanvas dim={dim} width={size.width} height={h} scene={scene} snap={1} view={view} onView={setView} dragAxis="floor" showPlanes showGrid onHandle={onHandle}
          ariaLabel="Vector diagram. Drag the coloured dots at the vector tips." />
      </div>
      <div className="mt-2 grid gap-2 text-xs sm:grid-cols-2">
        {mode === 'components' && <>{stat('|A|', fmt(mag(A)))}{stat('A', compText(A, dim))}</>}
        {mode === 'add' && <>{stat('A + B', compText(add(A, B), dim))}{stat('|A + B|', fmt(mag(add(A, B))))}</>}
        {mode === 'scalar' && <>{stat(`${fmt(k)}A`, compText(scale(A, k), dim))}{stat(`|${fmt(k)}A|`, fmt(mag(scale(A, k))))}</>}
        {mode === 'dot' && <>{stat('A·B', fmt(dot(A, B)))}{stat('Angle', ang === null ? 'undefined' : `${fmt(ang, 1)}°`)}</>}
        {mode === 'cross' && <>{stat('A × B', compText(cross(A, B), '3d'))}{stat('|A × B|', fmt(mag(cross(A, B))))}</>}
      </div>
      <p className="mt-1.5 text-[10px] text-gray-400">{dim === '3d' ? 'Drag empty space to rotate. ' : ''}Drag a coloured dot to change a vector. A-Factor STEM Studio</p>
    </div>
  );
}

export default function VectorsEmbedPage() {
  return <Suspense fallback={<div className="p-6 text-sm text-gray-400">Loading…</div>}><VectorsEmbedInner /></Suspense>;
}
