'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { Site } from '@/lib/chemistry/perovskite';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

export interface ViewerAtom { site: Site; pos: [number, number, number] }

export interface SiteStyle { label: string; color: string; radius: number /* in cell units */ }

interface Props {
  atoms: ViewerAtom[];
  /** Edge length of the drawn block, in the same units as `pos` (the supercell count). */
  extent: number;
  styles: Partial<Record<Site, SiteStyle>>;
  /** B–X distance in `pos` units; bonds are drawn between B/B2 and X atoms at this distance. */
  bondDist: number;
  showBonds: boolean;
  showCell: boolean;
  showA: boolean;
}

type V3 = [number, number, number];
const VIEWS: Record<string, { yaw: number; pitch: number }> = {
  Isometric: { yaw: 0.6, pitch: 0.5 },
  Front: { yaw: 0, pitch: 0 },
  Top: { yaw: 0, pitch: Math.PI / 2 - 0.001 },
};

export function CrystalViewer({ atoms, extent, styles, bondDist, showBonds, showCell, showA }: Props) {
  const boxRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { width, height } = useResponsiveCanvasSize(boxRef, 640, 440, 900);
  const rot = useRef({ yaw: 0.6, pitch: 0.5 });
  const drag = useRef<{ x: number; y: number } | null>(null);
  const [zoom, setZoom] = useState(1);
  const [auto, setAuto] = useState(false);
  const [tick, setTick] = useState(0); // forces a redraw after pointer moves

  const bonds = useMemo(() => {
    const out: [number, number][] = [];
    const eps = 1e-3;
    atoms.forEach((b, i) => {
      if (b.site !== 'B' && b.site !== 'B2') return;
      atoms.forEach((x, j) => {
        if (x.site !== 'X') return;
        const d = Math.hypot(b.pos[0] - x.pos[0], b.pos[1] - x.pos[1], b.pos[2] - x.pos[2]);
        if (Math.abs(d - bondDist) < eps) out.push([i, j]);
      });
    });
    return out;
  }, [atoms, bondDist]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    let raf = 0;
    let last = performance.now();

    const draw = (now: number) => {
      const dt = (now - last) / 1000;
      last = now;
      if (auto && !drag.current) rot.current.yaw += dt * 0.5;

      const dpr = window.devicePixelRatio || 1;
      canvas.width = width * dpr; canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(0, 0, width, height);

      const { yaw, pitch } = rot.current;
      const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
      const c = extent / 2;
      const scale = (Math.min(width, height) / (extent * 1.9)) * zoom;
      const project = (p: V3) => {
        const x = p[0] - c, y = p[1] - c, z = p[2] - c;
        const x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
        const y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp;
        const persp = 1 / (1 - z2 * 0.08 / extent);
        return { sx: width / 2 + x1 * scale * persp, sy: height / 2 - y2 * scale * persp, depth: z2, persp };
      };

      if (showCell) {
        ctx.strokeStyle = 'rgba(148,163,184,0.55)'; ctx.lineWidth = 1;
        const e = extent;
        const corners: V3[] = [[0, 0, 0], [e, 0, 0], [e, e, 0], [0, e, 0], [0, 0, e], [e, 0, e], [e, e, e], [0, e, e]];
        const edges = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
        ctx.beginPath();
        for (const [a, b] of edges) {
          const pa = project(corners[a]), pb = project(corners[b]);
          ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy);
        }
        ctx.stroke();
      }

      if (showBonds) {
        ctx.strokeStyle = 'rgba(165,180,252,0.45)'; ctx.lineWidth = 1.2;
        ctx.beginPath();
        for (const [i, j] of bonds) {
          const pa = project(atoms[i].pos), pb = project(atoms[j].pos);
          ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy);
        }
        ctx.stroke();
      }

      const drawn = atoms
        .filter(a => showA || a.site !== 'A')
        .map(a => ({ a, p: project(a.pos) }))
        .sort((u, v) => u.p.depth - v.p.depth);

      for (const { a, p } of drawn) {
        const st = styles[a.site];
        if (!st) continue;
        const r = Math.max(3, st.radius * scale * p.persp * 0.55);
        const grad = ctx.createRadialGradient(p.sx - r * 0.3, p.sy - r * 0.3, r * 0.1, p.sx, p.sy, r);
        grad.addColorStop(0, '#ffffff55'); grad.addColorStop(0.25, st.color); grad.addColorStop(1, st.color);
        ctx.fillStyle = grad;
        ctx.beginPath(); ctx.arc(p.sx, p.sy, r, 0, Math.PI * 2); ctx.fill();
        if (r > 9) {
          ctx.fillStyle = '#0f172a'; ctx.font = `600 ${Math.min(14, r * 0.85)}px system-ui, sans-serif`;
          ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
          ctx.fillText(st.label, p.sx, p.sy + 0.5);
        }
      }

      if (auto) raf = requestAnimationFrame(draw);
    };

    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [atoms, extent, styles, bonds, showBonds, showCell, showA, width, height, zoom, auto, tick]);

  const onDown = (e: React.PointerEvent) => { drag.current = { x: e.clientX, y: e.clientY }; (e.target as Element).setPointerCapture(e.pointerId); };
  const onMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    const dx = e.clientX - drag.current.x, dy = e.clientY - drag.current.y;
    drag.current = { x: e.clientX, y: e.clientY };
    rot.current.yaw += dx * 0.01;
    rot.current.pitch = Math.max(-Math.PI / 2 + 0.001, Math.min(Math.PI / 2 - 0.001, rot.current.pitch + dy * 0.01));
    setTick(t => t + 1);
  };
  const onUp = () => { drag.current = null; };
  const setView = (name: string) => { rot.current = { ...VIEWS[name] }; setTick(t => t + 1); };

  const legend = (['A', 'B', 'B2', 'X'] as Site[]).filter(s => styles[s]);

  return (
    <div>
      <div ref={boxRef} className="overflow-hidden rounded-xl">
        <canvas
          ref={canvasRef}
          width={width} height={height}
          style={{ width, height, touchAction: 'pan-y', cursor: 'grab' }}
          onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
          role="img" aria-label="Rotatable 3D view of the proposed crystal model. Drag to rotate."
        />
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        {Object.keys(VIEWS).map(v => (
          <button key={v} type="button" onClick={() => setView(v)} className="rounded-md border border-gray-200 bg-white px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300 hover:text-indigo-700">{v}</button>
        ))}
        <button type="button" onClick={() => setAuto(a => !a)} className={`rounded-md border px-2.5 py-1 text-[11px] ${auto ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{auto ? 'Stop spin' : 'Spin'}</button>
        <label className="ml-auto flex items-center gap-2 text-[11px] text-gray-500">
          Zoom
          <input type="range" min={0.6} max={2} step={0.05} value={zoom} onChange={e => setZoom(Number(e.target.value))} className="w-24" />
        </label>
      </div>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1">
        {legend.map(s => (
          <span key={s} className="flex items-center gap-1.5 text-[11px] text-gray-600">
            <span className="inline-block h-3 w-3 rounded-full" style={{ background: styles[s]!.color }} />
            {s === 'B2' ? 'B′' : s}-site: {styles[s]!.label}
          </span>
        ))}
        <span className="text-[11px] text-gray-400">Drag to rotate · sizes ∝ Shannon radii</span>
      </div>
    </div>
  );
}
