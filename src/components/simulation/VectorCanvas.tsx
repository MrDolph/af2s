'use client';
import { useEffect, useRef, useState } from 'react';
import { type P3, type View, P, PITCH_MAX, PITCH_MIN, clampTo, project, snapTo, unprojectFloor, unprojectHeight, type Cam } from '@/lib/physics/space';
import { type Handle, type Scene, scenePoints } from '@/lib/physics/vectors';

interface Props {
  dim: '2d' | '3d';
  width: number;
  height: number;
  scene: Scene;
  snap: number;
  view: View;
  onView: (v: View) => void;
  dragAxis: 'floor' | 'height';
  showPlanes: boolean;
  showGrid: boolean;
  readOnly?: boolean;
  /** Asks the page to move a handle to a new tip position (already snapped and clamped). */
  onHandle: (id: Handle['id'], at: P3) => void;
  ariaLabel: string;
}

const INK = '#111827', GREY = '#6b7280';
const NICE = [5, 6, 8, 10, 12, 15, 20, 25, 30, 40, 50, 60, 80, 100];
const niceRange = (m: number) => NICE.find(n => n >= m) ?? Math.ceil(m / 10) * 10;
const niceStep = (range: number, max: number) => [1, 2, 5, 10, 20, 50].find(s => range / s <= max) ?? 100;

export function VectorCanvas(props: Props) {
  const { dim, width, height, scene, snap, view, dragAxis, readOnly } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  // While a handle is being dragged the scale is held fixed, otherwise the axes would rescale under the pointer.
  const [frozen, setFrozen] = useState<number | null>(null);
  const selected = useRef<Handle['id'] | null>(null);
  const drag = useRef<{ kind: 'handle'; id: Handle['id'] } | { kind: 'view'; x: number; y: number; yaw: number; pitch: number } | null>(null);

  const pts = scenePoints(scene);
  const maxAbs = Math.max(0, ...pts.map(p => Math.max(Math.abs(p.x), Math.abs(p.y), dim === '3d' ? Math.abs(p.z) : 0)));
  const autoRange = niceRange(Math.max(5, maxAbs * (dim === '3d' ? 1.08 : 1.2)));
  const range = frozen ?? autoRange;

  const geometry = (rg: number) => {
    if (dim === '2d') {
      const side = Math.min(width - 56, height - 40), s = side / (2 * rg), cx = width / 2, cy = height / 2;
      return { to: (p: P3) => ({ sx: cx + p.x * s, sy: cy - p.y * s, depth: 0 }), scale: s, cx, cy, cam: null as Cam | null };
    }
    const scale = (0.5 * Math.min(width, height)) / (rg * 1.15), cam: Cam = { view, scale, cx: width * 0.5, cy: height * 0.52 };
    return { to: (p: P3) => project(p, cam), scale, cx: cam.cx, cy: cam.cy, cam };
  };

  useEffect(() => {
    const canvas = ref.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr; canvas.height = height * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, width, height);
    const G = geometry(range), to = G.to;

    const text = (s: string, x: number, y: number, o: { color?: string; size?: number; bold?: boolean; italic?: boolean; align?: CanvasTextAlign; serif?: boolean } = {}) => {
      ctx.font = `${o.italic ? 'italic ' : ''}${o.bold ? '600 ' : ''}${o.size ?? 12}px ${o.serif ? 'Georgia, serif' : 'system-ui, sans-serif'}`;
      ctx.textAlign = o.align ?? 'center'; ctx.textBaseline = 'middle'; ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(255,255,255,0.92)'; ctx.lineJoin = 'round'; ctx.strokeText(s, x, y);
      ctx.fillStyle = o.color ?? INK; ctx.fillText(s, x, y);
    };
    const line = (x1: number, y1: number, x2: number, y2: number, color: string, w = 1.5, dash: number[] = []) => { ctx.beginPath(); ctx.setLineDash(dash); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); ctx.setLineDash([]); };
    const head = (x1: number, y1: number, x2: number, y2: number, color: string, size: number) => {
      const a = Math.atan2(y2 - y1, x2 - x1); ctx.beginPath(); ctx.fillStyle = color; ctx.moveTo(x2, y2);
      ctx.lineTo(x2 - size * Math.cos(a - 0.4), y2 - size * Math.sin(a - 0.4)); ctx.lineTo(x2 - size * Math.cos(a + 0.4), y2 - size * Math.sin(a + 0.4)); ctx.closePath(); ctx.fill();
    };
    const arrow = (x1: number, y1: number, x2: number, y2: number, color: string, w: number, dash: number[], hs: number) => {
      const L = Math.hypot(x2 - x1, y2 - y1); if (L < 2) return;
      const k = Math.min(hs * 0.65, L / 2) / L; line(x1, y1, x2 - (x2 - x1) * k, y2 - (y2 - y1) * k, color, w, dash); if (!dash.length || L > 14) head(x1, y1, x2, y2, color, Math.min(hs, L * 0.6));
    };

    // ── axes / grid ──
    const step = niceStep(range, dim === '2d' ? 8 : 6);
    if (dim === '2d') {
      const s = G.scale, cx = G.cx, cy = G.cy, side = 2 * range * s, L = cx - side / 2, T = cy - side / 2;
      if (props.showGrid) for (let v = -range; v <= range; v += step) { line(cx + v * s, T, cx + v * s, T + side, v === 0 ? 'transparent' : '#eceff3', 1); line(L, cy - v * s, L + side, cy - v * s, v === 0 ? 'transparent' : '#eceff3', 1); }
      scene.polys.forEach(p => { ctx.beginPath(); p.pts.forEach((q, i) => { const t = to(q); if (i) ctx.lineTo(t.sx, t.sy); else ctx.moveTo(t.sx, t.sy); }); ctx.closePath(); ctx.fillStyle = p.fill; ctx.fill(); if (p.stroke) { ctx.strokeStyle = p.stroke; ctx.lineWidth = 1; ctx.stroke(); } });
      arrow(L - 6, cy, L + side + 10, cy, INK, 2, [], 11); arrow(cx, T + side + 6, cx, T - 10, INK, 2, [], 11);
      text('x', L + side + 12, cy - 13, { italic: true, serif: true, size: 16 }); text('y', cx + 13, T - 10, { italic: true, serif: true, size: 16 });
      for (let v = -range; v <= range; v += step) { if (v === 0) continue; line(cx + v * s, cy - 4, cx + v * s, cy + 4, INK, 1.2); text(String(v).replace('-', '−'), cx + v * s, cy + 15, { size: 10, color: GREY }); line(cx - 4, cy - v * s, cx + 4, cy - v * s, INK, 1.2); text(String(v).replace('-', '−'), cx - 15, cy - v * s, { size: 10, color: GREY }); }
      text('O', cx - 10, cy + 12, { bold: true });
    } else {
      const O = to(P());
      if (props.showPlanes) {
        const R = range, poly = (cs: P3[], f: string, st: string) => { ctx.beginPath(); cs.forEach((c, i) => { const q = to(c); if (i) ctx.lineTo(q.sx, q.sy); else ctx.moveTo(q.sx, q.sy); }); ctx.closePath(); ctx.fillStyle = f; ctx.fill(); ctx.lineWidth = 0.8; ctx.strokeStyle = st; ctx.stroke(); };
        poly([P(-R, -R, 0), P(R, -R, 0), P(R, R, 0), P(-R, R, 0)], 'rgba(251,191,36,0.22)', 'rgba(180,120,20,0.45)');
        if (props.showGrid) for (let v = -R; v <= R; v += step) { const a = to(P(v, -R, 0)), b = to(P(v, R, 0)), c = to(P(-R, v, 0)), d = to(P(R, v, 0)); line(a.sx, a.sy, b.sx, b.sy, 'rgba(120,80,10,0.2)', 0.8); line(c.sx, c.sy, d.sx, d.sy, 'rgba(120,80,10,0.2)', 0.8); }
      }
      scene.polys.forEach(p => { ctx.beginPath(); p.pts.forEach((q, i) => { const t = to(q); if (i) ctx.lineTo(t.sx, t.sy); else ctx.moveTo(t.sx, t.sy); }); ctx.closePath(); ctx.fillStyle = p.fill; ctx.fill(); if (p.stroke) { ctx.strokeStyle = p.stroke; ctx.lineWidth = 1; ctx.stroke(); } });
      const ax: [P3, string][] = [[P(range + range * 0.12, 0, 0), 'X'], [P(0, range + range * 0.12, 0), 'Y'], [P(0, 0, range + range * 0.12), 'Z']];
      ax.forEach(([e, n]) => { const q = to(e); arrow(O.sx, O.sy, q.sx, q.sy, INK, 2, [], 10); text(n, q.sx + (n === 'X' ? -10 : 12), q.sy + (n === 'Z' ? -2 : 9), { italic: true, serif: true, size: 17 }); });
      ([P(-range, 0, 0), P(0, -range, 0), P(0, 0, -range)]).forEach(n => { const q = to(n); line(O.sx, O.sy, q.sx, q.sy, INK, 1.2); });
      if (G.scale * step >= 18) for (let v = -range; v <= range; v += step) { if (v === 0) continue; const tx = to(P(v, 0, 0)), ty = to(P(0, v, 0)), tz = to(P(0, 0, v)); text(String(v).replace('-', '−'), tx.sx - 8, tx.sy + 9, { size: 9, color: GREY }); text(String(v).replace('-', '−'), ty.sx + 2, ty.sy + 11, { size: 9, color: GREY }); text(String(v).replace('-', '−'), tz.sx - 11, tz.sy, { size: 9, color: GREY }); }
      text('O', O.sx - 9, O.sy + 11, { italic: true, serif: true, size: 14 });
    }

    // ── arcs ──
    scene.arcs.forEach(a => {
      const nrm = (v: P3) => { const l = Math.hypot(v.x, v.y, v.z) || 1; return P(v.x / l, v.y / l, v.z / l); };
      const u = nrm(a.a), v = nrm(a.b), ang = Math.acos(Math.max(-1, Math.min(1, u.x * v.x + u.y * v.y + u.z * v.z)));
      if (ang < 0.02) return;
      let w = v; if (Math.abs(ang - Math.PI) < 0.02) w = nrm(P(-u.y, u.x, 0.0001));
      const sa = Math.sin(ang);
      const at = (t: number) => { const k1 = Math.sin((1 - t) * ang) / sa, k2 = Math.sin(t * ang) / sa; const src = Math.abs(ang - Math.PI) < 0.02 ? w : v; return P(a.at.x + (u.x * k1 + src.x * k2) * a.r, a.at.y + (u.y * k1 + src.y * k2) * a.r, a.at.z + (u.z * k1 + src.z * k2) * a.r); };
      ctx.beginPath(); for (let i = 0; i <= 24; i++) { const q = to(at(i / 24)); if (i) ctx.lineTo(q.sx, q.sy); else ctx.moveTo(q.sx, q.sy); } ctx.strokeStyle = a.color; ctx.lineWidth = 2; ctx.stroke();
      if (a.label) { const m = at(0.5), c0 = to(a.at), q = to(m); const dx = q.sx - c0.sx, dy = q.sy - c0.sy, d = Math.hypot(dx, dy) || 1; text(a.label, q.sx + (dx / d) * 34, q.sy + (dy / d) * 20, { color: a.color, bold: true, size: 12 }); }
    });

    // ── arrows ──
    scene.arrows.forEach(a => {
      const p = to(a.from), q = to(a.to);
      ctx.globalAlpha = a.faint ? 0.55 : 1;
      arrow(p.sx, p.sy, q.sx, q.sy, a.color, a.width ?? 2.5, a.dash ?? [], 11);
      ctx.globalAlpha = 1;
    });
    scene.arrows.forEach(a => {
      if (!a.label) return;
      const p = to(a.from), q = to(a.to), t = a.labelAt ?? 0.5, mx = p.sx + (q.sx - p.sx) * t, my = p.sy + (q.sy - p.sy) * t;
      const dx = q.sx - p.sx, dy = q.sy - p.sy, d = Math.hypot(dx, dy) || 1; let nx = -dy / d, ny = dx / d; if (ny > 0) { nx = -nx; ny = -ny; }
      text(a.label, mx + nx * 13, my + ny * 13, { color: a.color, bold: true, size: 12 });
    });
    scene.marks.forEach(m => { const q = to(m.at); text(m.text, q.sx, q.sy, { color: m.color, size: m.size ?? 12, bold: true }); });

    // ── handles ──
    scene.handles.forEach(h => {
      const q = to(h.at);
      if (!readOnly) { ctx.beginPath(); ctx.arc(q.sx, q.sy, 15, 0, Math.PI * 2); ctx.fillStyle = h.color + '22'; ctx.fill(); }
      ctx.beginPath(); ctx.arc(q.sx, q.sy, 7, 0, Math.PI * 2); ctx.fillStyle = h.color; ctx.fill(); ctx.lineWidth = 2; ctx.strokeStyle = '#fff'; ctx.stroke();
      if (selected.current === h.id && !readOnly) { ctx.beginPath(); ctx.arc(q.sx, q.sy, 12, 0, Math.PI * 2); ctx.setLineDash([3, 3]); ctx.strokeStyle = h.color; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]); }
    });
  // The scene is rebuilt on every render, so the drawing re-runs whenever the page re-renders.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [scene, dim, width, height, view, range, props.showPlanes, props.showGrid, readOnly]);

  // ── pointer handling ──
  const local = (e: React.PointerEvent) => { const r = ref.current!.getBoundingClientRect(); return { x: ((e.clientX - r.left) / r.width) * width, y: ((e.clientY - r.top) / r.height) * height }; };
  const down = (e: React.PointerEvent) => {
    const m = local(e), G = geometry(range);
    let best: Handle | null = null, bd = 26;
    for (const h of scene.handles) { const q = G.to(h.at); const d = Math.hypot(q.sx - m.x, q.sy - m.y); if (d < bd) { bd = d; best = h; } }
    ref.current!.setPointerCapture(e.pointerId);
    if (best && !readOnly) { setFrozen(autoRange); selected.current = best.id; drag.current = { kind: 'handle', id: best.id }; }
    else if (dim === '3d') drag.current = { kind: 'view', x: e.clientX, y: e.clientY, yaw: view.yaw, pitch: view.pitch };
  };
  const move = (e: React.PointerEvent) => {
    const d = drag.current; if (!d) return;
    if (d.kind === 'view') { props.onView({ yaw: d.yaw - (e.clientX - d.x) * 0.01, pitch: Math.max(PITCH_MIN, Math.min(PITCH_MAX, d.pitch + (e.clientY - d.y) * 0.008)) }); return; }
    const m = local(e), rg = frozen ?? range, G = geometry(rg), h = scene.handles.find(x => x.id === d.id); if (!h) return;
    const q = (v: number) => clampTo(snapTo(v, snap), rg);
    let next = h.at;
    if (dim === '2d') next = P(q((m.x - G.cx) / G.scale), q((G.cy - m.y) / G.scale), 0);
    else if (dragAxis === 'floor') { const f = unprojectFloor(m.x, m.y, h.at.z, G.cam!); if (f) next = P(q(f.x), q(f.y), h.at.z); }
    else next = P(h.at.x, h.at.y, q(unprojectHeight(m.y, h.at.x, h.at.y, G.cam!)));
    if (next.x !== h.at.x || next.y !== h.at.y || next.z !== h.at.z) props.onHandle(d.id, next);
  };
  const up = () => { drag.current = null; setFrozen(null); };

  const key = (e: React.KeyboardEvent) => {
    if (readOnly) return;
    const h = scene.handles.find(x => x.id === selected.current) ?? scene.handles[0]; if (!h) return;
    const st = snap > 0 ? snap : 0.5;
    const dlt: Record<string, [number, number, number]> = { ArrowRight: [st, 0, 0], ArrowLeft: [-st, 0, 0], ArrowUp: [0, st, 0], ArrowDown: [0, -st, 0], PageUp: [0, 0, st], PageDown: [0, 0, -st] };
    const v = dlt[e.key]; if (!v || (dim === '2d' && v[2])) return;
    e.preventDefault(); selected.current = h.id;
    props.onHandle(h.id, P(snapTo(h.at.x + v[0], snap), snapTo(h.at.y + v[1], snap), dim === '3d' ? snapTo(h.at.z + v[2], snap) : 0));
  };

  return (
    <canvas ref={ref} width={width} height={height} tabIndex={0}
      style={{ width, height, touchAction: 'none', cursor: readOnly ? 'default' : 'grab', display: 'block', maxWidth: '100%' }}
      onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up} onKeyDown={key}
      role="img" aria-label={props.ariaLabel} />
  );
}
