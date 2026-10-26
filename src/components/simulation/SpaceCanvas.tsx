'use client';
import { useEffect, useRef } from 'react';
import {
  type Dim, type P3, type View, type Cam, RANGE, LABELS, P, analyseJourney, clampDim, clampTo, coordText, fmt, project, snapTo,
  unprojectFloor, unprojectHeight, PITCH_MAX, PITCH_MIN,
} from '@/lib/physics/space';

export type Activity = 'locate' | 'journey' | 'practice';
export const POINT_COLORS = ['#4f46e5', '#059669', '#d97706', '#e11d48', '#7c3aed'];

interface Props {
  dim: Dim;
  activity: Activity;
  width: number;
  height: number;
  points: P3[];
  labels?: string[];
  selected: number;
  onMove: (i: number, p: P3) => void;
  onSelect: (i: number) => void;
  snap: number;
  view: View;
  onView: (v: View) => void;
  dragAxis: 'floor' | 'height';
  showPlanes: boolean;
  showGrid: boolean;
  showGuides: boolean;
  showComponents: boolean;
  /** Practice "read the coordinates": the point can't be moved and its numbers are hidden. */
  readOnly?: boolean;
  hideCoords?: boolean;
  /** Locate activity: reveal the route to the point step by step (2D: 0–2, 3D: 0–3). Undefined shows everything. */
  walk?: number;
}

const RED = '#dc2626', GREEN = '#16a34a', BLUE = '#2563eb', ROSE = '#e11d48', INK = '#111827', GREY = '#6b7280';

// ── Geometry shared by drawing and pointer handling ─────────────────────────
function geometry(dim: Dim, w: number, h: number, view: View) {
  const range = RANGE[dim];
  if (dim === '1d') {
    const m = 34, s = (w - 2 * m) / (2 * range), y0 = h * 0.5;
    return { range, scale: s, to: (p: P3) => ({ sx: m + (p.x + range) * s, sy: y0, depth: 0 }), cam: null as Cam | null, x0: m, y0, cx: w / 2, cy: y0 };
  }
  if (dim === '2d') {
    const side = Math.min(w - 56, h - 40), s = side / (2 * range), cx = w / 2, cy = h / 2;
    return { range, scale: s, to: (p: P3) => ({ sx: cx + p.x * s, sy: cy - p.y * s, depth: 0 }), cam: null as Cam | null, x0: cx - side / 2, y0: cy, cx, cy };
  }
  const scale = (0.5 * Math.min(w, h)) / (range * 1.2), cam: Cam = { view, scale, cx: w * 0.5, cy: h * 0.52 };
  return { range, scale, to: (p: P3) => project(p, cam), cam, x0: 0, y0: 0, cx: cam.cx, cy: cam.cy };
}

export function SpaceCanvas(props: Props) {
  const { dim, activity, width, height, points, selected, snap, view, dragAxis, readOnly } = props;
  const ref = useRef<HTMLCanvasElement>(null);
  const drag = useRef<{ kind: 'point'; i: number } | { kind: 'view'; x: number; y: number; yaw: number; pitch: number } | null>(null);
  const labels = props.labels ?? LABELS;

  // ── Drawing ────────────────────────────────────────────────────────────────
  useEffect(() => {
    const canvas = ref.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = width * dpr; canvas.height = height * dpr;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = '#ffffff'; ctx.fillRect(0, 0, width, height);
    const G = geometry(dim, width, height, view);
    const pts = points.map(p => clampDim(p, dim));
    const colour = (i: number) => POINT_COLORS[i % POINT_COLORS.length];

    const text = (s: string, x: number, y: number, o: { color?: string; size?: number; bold?: boolean; italic?: boolean; align?: CanvasTextAlign; serif?: boolean } = {}) => {
      ctx.font = `${o.italic ? 'italic ' : ''}${o.bold ? '600 ' : ''}${o.size ?? 12}px ${o.serif ? 'Georgia, "Times New Roman", serif' : 'system-ui, sans-serif'}`;
      ctx.textAlign = o.align ?? 'center'; ctx.textBaseline = 'middle';
      ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineJoin = 'round'; ctx.strokeText(s, x, y);
      ctx.fillStyle = o.color ?? INK; ctx.fillText(s, x, y);
    };
    const line = (x1: number, y1: number, x2: number, y2: number, color: string, w = 1.5, dash: number[] = []) => {
      ctx.beginPath(); ctx.setLineDash(dash); ctx.strokeStyle = color; ctx.lineWidth = w; ctx.moveTo(x1, y1); ctx.lineTo(x2, y2); ctx.stroke(); ctx.setLineDash([]);
    };
    const head = (x1: number, y1: number, x2: number, y2: number, color: string, size = 9) => {
      const a = Math.atan2(y2 - y1, x2 - x1);
      ctx.beginPath(); ctx.fillStyle = color; ctx.moveTo(x2, y2);
      ctx.lineTo(x2 - size * Math.cos(a - 0.38), y2 - size * Math.sin(a - 0.38)); ctx.lineTo(x2 - size * Math.cos(a + 0.38), y2 - size * Math.sin(a + 0.38)); ctx.closePath(); ctx.fill();
    };
    const arrow = (x1: number, y1: number, x2: number, y2: number, color: string, w = 2, dash: number[] = [], hs = 9) => {
      const L = Math.hypot(x2 - x1, y2 - y1); if (L < 1) return;
      const k = Math.min(hs * 0.6, L / 2) / L;
      line(x1, y1, x2 - (x2 - x1) * k, y2 - (y2 - y1) * k, color, w, dash); head(x1, y1, x2, y2, color, hs);
    };
    const dot = (x: number, y: number, color: string, r = 7, ring = false) => {
      ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
      ctx.lineWidth = 2; ctx.strokeStyle = '#fff'; ctx.stroke();
      if (ring) { ctx.beginPath(); ctx.arc(x, y, r + 5, 0, Math.PI * 2); ctx.strokeStyle = color; ctx.lineWidth = 1.5; ctx.setLineDash([3, 3]); ctx.stroke(); ctx.setLineDash([]); }
    };
    const R = G.range;
    const lab = (i: number) => [{ dx: 10, dy: -14, al: 'left' as CanvasTextAlign }, { dx: 10, dy: 16, al: 'left' as CanvasTextAlign }, { dx: -10, dy: -14, al: 'right' as CanvasTextAlign }, { dx: -10, dy: 16, al: 'right' as CanvasTextAlign }, { dx: 10, dy: -30, al: 'left' as CanvasTextAlign }][i % 5];
    const J = analyseJourney(pts, dim);
    const showJourney = activity === 'journey' && pts.length >= 2;
    const hidden = !!props.hideCoords;
    const coords = (p: P3) => (hidden ? '?' : coordText(p, dim));

    // ───────────── 1D ─────────────
    if (dim === '1d') {
      const y0 = G.y0, s = G.scale, step = s >= 26 ? 1 : 2;
      line(18, y0, width - 18, y0, INK, 2); head(width - 40, y0, width - 18, y0, INK, 11); head(40, y0, 18, y0, INK, 11);
      text('x', width - 14, y0 - 16, { italic: true, serif: true, size: 16 });
      for (let v = -R; v <= R; v++) {
        const sx = G.to(P(v)).sx; const major = v % step === 0;
        line(sx, y0 - (major ? 6 : 3), sx, y0 + (major ? 6 : 3), INK, 1.2);
        if (major) text(v === 0 ? 'O' : fmt(v), sx, y0 + 20, { size: 11, color: v === 0 ? INK : GREY, bold: v === 0 });
      }
      text('+x →', width - 44, y0 + 38, { size: 10, color: GREY }); text('← −x', 44, y0 + 38, { size: 10, color: GREY });

      if (activity === 'journey' && showJourney) {
        J.legs.forEach((l, i) => {
          const a = G.to(l.from).sx, b = G.to(l.to).sx, up = i % 2 === 0 ? -1 : 1, hh = Math.min(70, 16 + Math.abs(b - a) * 0.22) * up, mx = (a + b) / 2;
          if (Math.abs(b - a) < 1) return;
          const dirx = Math.sign(b - a), a2 = a + dirx * 10, b2 = b - dirx * 10;
          ctx.beginPath(); ctx.strokeStyle = colour(i + 1); ctx.lineWidth = 2.5; ctx.moveTo(a2, y0); ctx.quadraticCurveTo(mx, y0 + hh * 2, b2, y0); ctx.stroke();
          head(mx, y0 + hh * 2, b2, y0, colour(i + 1), 10);
          text(`${l.delta.x >= 0 ? '+' : '−'}${fmt(Math.abs(l.delta.x))}`, mx, y0 + hh * 1.0 + (up < 0 ? -9 : 9), { color: colour(i + 1), bold: true });
        });
        if (J.magnitude > 1e-9) {
          const a = G.to(pts[0]).sx, b = G.to(pts[pts.length - 1]).sx, yy = height - 30;
          line(a, y0 + 4, a, yy, ROSE, 1, [3, 3]); line(b, y0 + 4, b, yy, ROSE, 1, [3, 3]);
          arrow(a, yy, b, yy, ROSE, 3, [], 11);
          text(`displacement Δx = ${J.displacement.x >= 0 ? '+' : '−'}${fmt(Math.abs(J.displacement.x))}`, (a + b) / 2, yy - 12, { color: ROSE, bold: true });
        }
      }
      if (activity !== 'journey' && pts[0]) {
        const sx = G.to(pts[0]).sx;
        if (props.showGuides && !hidden && Math.abs(pts[0].x) > 1e-9) {
          arrow(G.to(P(0)).sx, y0 - 34, sx, y0 - 34, RED, 2.5, [], 9);
          text(`x = ${fmt(pts[0].x)}  (${fmt(Math.abs(pts[0].x))} unit${Math.abs(pts[0].x) === 1 ? '' : 's'} ${pts[0].x > 0 ? 'right' : 'left'} of O)`, (G.to(P(0)).sx + sx) / 2, y0 - 52, { color: RED, bold: true });
          line(sx, y0 - 34, sx, y0, RED, 1, [3, 3]);
        }
      }
      pts.forEach((p, i) => {
        if (activity !== 'journey' && i > 0) return;
        const sx = G.to(p).sx; dot(sx, y0, activity === 'journey' ? colour(i) : RED, 8, i === selected && !readOnly);
        text(activity === 'journey' ? labels[i] : labels[0] ?? 'P', sx, y0 - 18, { color: activity === 'journey' ? colour(i) : RED, bold: true, size: 14 });
        if (activity === 'journey') text(coords(p), sx, y0 + 40 + (i % 2) * 14, { size: 11, color: colour(i) });
      });
      return;
    }

    // ───────────── 2D ─────────────
    if (dim === '2d') {
      const s = G.scale, cx = G.cx, cy = G.cy, side = 2 * R * s, L = cx - side / 2, T = cy - side / 2;
      if (props.showGrid && s >= 12) for (let v = -R; v <= R; v++) {
        const c = v % 5 === 0 ? '#d1d5db' : '#eceff3';
        line(cx + v * s, T, cx + v * s, T + side, c, v === 0 ? 0 : 1); line(L, cy - v * s, L + side, cy - v * s, c, v === 0 ? 0 : 1);
      }
      if (activity === 'locate' || activity === 'practice') {
        ['II', 'I', 'III', 'IV'].forEach((q, k) => text(q, k % 2 === 0 ? L + 26 : L + side - 26, k < 2 ? T + 20 : T + side - 20, { color: '#cbd5e1', size: 22, bold: true, serif: true }));
      }
      arrow(L - 8, cy, L + side + 12, cy, INK, 2, [], 11); arrow(cx, T + side + 8, cx, T - 12, INK, 2, [], 11);
      text('x', L + side + 12, cy - 14, { italic: true, serif: true, size: 16 }); text('y', cx + 14, T - 12, { italic: true, serif: true, size: 16 });
      const step = s >= 26 ? 1 : 2;
      for (let v = -R; v <= R; v += step) {
        if (v === 0) continue;
        line(cx + v * s, cy - 4, cx + v * s, cy + 4, INK, 1.2); text(fmt(v), cx + v * s, cy + 15, { size: 10, color: GREY });
        line(cx - 4, cy - v * s, cx + 4, cy - v * s, INK, 1.2); text(fmt(v), cx - 16, cy - v * s, { size: 10, color: GREY });
      }
      text('O', cx - 10, cy + 12, { bold: true, size: 12 });

      if (showJourney) {
        J.legs.forEach((l, i) => { const a = G.to(l.from), b = G.to(l.to); arrow(a.sx, a.sy, b.sx, b.sy, colour(i + 1), 3, [], 11); if (l.length > 1e-9) text(fmt(l.length, 2), (a.sx + b.sx) / 2 + 12, (a.sy + b.sy) / 2 - 10, { color: colour(i + 1), size: 11, bold: true }); });
        if (J.magnitude > 1e-9) {
          const a = G.to(pts[0]), b = G.to(pts[pts.length - 1]);
          if (props.showComponents && Math.abs(J.displacement.x) > 1e-9 && Math.abs(J.displacement.y) > 1e-9) {
            line(a.sx, a.sy, b.sx, a.sy, RED, 1.8, [6, 4]); line(b.sx, a.sy, b.sx, b.sy, GREEN, 1.8, [6, 4]);
            text(`Δx = ${fmt(J.displacement.x)}`, (a.sx + b.sx) / 2, a.sy + (b.sy < a.sy ? 14 : -14), { color: RED, size: 11, bold: true });
            text(`Δy = ${fmt(J.displacement.y)}`, b.sx + (b.sx >= a.sx ? 8 : -8), (a.sy + b.sy) / 2, { color: GREEN, size: 11, bold: true, align: b.sx >= a.sx ? 'left' : 'right' });
          }
          arrow(a.sx, a.sy, b.sx, b.sy, ROSE, 2.5, [8, 5], 11);
        }
      } else if (activity === 'locate' && pts[0] && props.walk !== undefined) {
        const p = pts[0], w = props.walk, a = G.to(P(p.x, 0)), b = G.to(p), o = G.to(P(0, 0));
        if (w >= 1) { line(o.sx, o.sy, a.sx, a.sy, RED, 3.5); text('x', (o.sx + a.sx) / 2, o.sy + (p.y >= 0 ? 26 : -24), { color: RED, italic: true, serif: true, size: 17 }); }
        if (w >= 2) { line(a.sx, a.sy, b.sx, b.sy, RED, 3.5); text('y', a.sx + (p.x >= 0 ? 14 : -14), (a.sy + b.sy) / 2, { color: RED, italic: true, serif: true, size: 17 }); }
        const cur = w >= 2 ? b : w === 1 ? a : o; dot(cur.sx, cur.sy, RED, w >= 2 ? 8 : 6);
        if (w >= 2) text(coords(p), cur.sx + 12, cur.sy - 14, { color: RED, bold: true, size: 12, align: 'left' });
        return;
      } else if (activity !== 'journey' && pts[0]) {
        const p = pts[0], q = G.to(p);
        if (props.showGuides && !hidden) {
          line(q.sx, q.sy, q.sx, cy, RED, 1.6, [5, 4]); line(q.sx, q.sy, cx, q.sy, RED, 1.6, [5, 4]);
          text(fmt(p.x), q.sx, cy + (p.y >= 0 ? 24 : -22), { color: RED, bold: true, size: 12 }); text(fmt(p.y), cx + (p.x >= 0 ? -26 : 26), q.sy, { color: RED, bold: true, size: 12 });
        } else if (props.showGuides) { line(q.sx, q.sy, q.sx, cy, RED, 1.2, [3, 5]); line(q.sx, q.sy, cx, q.sy, RED, 1.2, [3, 5]); }
      }
      pts.forEach((p, i) => {
        if (activity !== 'journey' && i > 0) return;
        const q = G.to(p), c = activity === 'journey' ? colour(i) : RED;
        dot(q.sx, q.sy, c, 8, i === selected && !readOnly);
        if (activity === 'journey') { const o = lab(i); text(`${labels[i]} ${coords(p)}`, q.sx + o.dx, q.sy + o.dy, { color: c, bold: true, size: 12, align: o.al }); }
        else text(coords(p), q.sx + (q.sx > width - 90 ? -10 : 12), q.sy - 14, { color: c, bold: true, size: 12, align: q.sx > width - 90 ? 'right' : 'left' });
      });
      return;
    }

    // ───────────── 3D ─────────────
    const to = G.to;
    const poly = (corners: P3[], fill: string, stroke: string) => {
      ctx.beginPath(); corners.forEach((c, k) => { const q = to(c); if (k) ctx.lineTo(q.sx, q.sy); else ctx.moveTo(q.sx, q.sy); }); ctx.closePath();
      ctx.fillStyle = fill; ctx.fill(); ctx.lineWidth = 0.8; ctx.strokeStyle = stroke; ctx.stroke();
    };
    if (props.showPlanes) {
      const planes = [
        { c: [P(-R, -R, 0), P(R, -R, 0), P(R, R, 0), P(-R, R, 0)], f: 'rgba(251,191,36,0.30)', s: 'rgba(180,120,20,0.5)', m: P(0, 0, 0) },
        { c: [P(0, -R, -R), P(0, R, -R), P(0, R, R), P(0, -R, R)], f: 'rgba(34,211,238,0.28)', s: 'rgba(8,120,150,0.5)', m: P(0, 0, 0) },
        { c: [P(-R, 0, -R), P(R, 0, -R), P(R, 0, R), P(-R, 0, R)], f: 'rgba(74,222,128,0.30)', s: 'rgba(22,120,60,0.5)', m: P(0, 0, 0) },
      ];
      planes.forEach(pl => poly(pl.c, pl.f, pl.s));
    }
    if (props.showGrid && props.showPlanes) for (let v = -R; v <= R; v++) {
      const a = to(P(v, -R, 0)), b = to(P(v, R, 0)), c = to(P(-R, v, 0)), d = to(P(R, v, 0));
      line(a.sx, a.sy, b.sx, b.sy, 'rgba(120,80,10,0.22)', 0.8); line(c.sx, c.sy, d.sx, d.sy, 'rgba(120,80,10,0.22)', 0.8);
    }
    // axes
    const O = to(P(0, 0, 0));
    const axes: { end: P3; name: string; off: [number, number] }[] = [
      { end: P(R + 0.9, 0, 0), name: 'X', off: [-12, 10] }, { end: P(0, R + 0.9, 0), name: 'Y', off: [12, 8] }, { end: P(0, 0, R + 0.9), name: 'Z', off: [14, -2] },
    ];
    axes.forEach(a => { const e = to(a.end); arrow(O.sx, O.sy, e.sx, e.sy, INK, 2.2, [], 11); text(a.name, e.sx + a.off[0], e.sy + a.off[1], { italic: true, serif: true, size: 19 }); });
    const negs: P3[] = [P(-R, 0, 0), P(0, -R, 0), P(0, 0, -R)]; negs.forEach(n => { const e = to(n); line(O.sx, O.sy, e.sx, e.sy, INK, 1.4); });
    const tickStep = RANGE['3d'] >= 6 ? 1 : 1;
    for (let v = -R; v <= R; v += tickStep) {
      if (v === 0 || (G.scale < 26 && v % 2 !== 0)) continue;
      const tx = to(P(v, 0, 0)), ty = to(P(0, v, 0)), tz = to(P(0, 0, v));
      text(fmt(v), tx.sx - 9, tx.sy + 9, { size: 10, color: GREY }); text(fmt(v), ty.sx + 2, ty.sy + 12, { size: 10, color: GREY }); text(fmt(v), tz.sx - 12, tz.sy, { size: 10, color: GREY });
    }
    text('O', O.sx - 10, O.sy + 12, { italic: true, serif: true, size: 15 });

    const dropLines = (p: P3, color: string) => { const a = to(p), b = to(P(p.x, p.y, 0)); line(a.sx, a.sy, b.sx, b.sy, color, 1, [2, 4]); };

    const walking = props.walk !== undefined && activity === 'locate';
    if (activity !== 'journey' && pts[0] && walking) {
      const p = pts[0], w = props.walk!;
      const legs3 = [P(p.x, 0, 0), P(p.x, p.y, 0), p];
      let from = O;
      legs3.slice(0, w).forEach((e, k) => { const q = to(e); line(from.sx, from.sy, q.sx, q.sy, RED, 3.5); text(['x', 'y', 'z'][k], (from.sx + q.sx) / 2 + (k === 2 ? 12 : -2), (from.sy + q.sy) / 2 + (k === 2 ? 0 : 14), { color: RED, italic: true, serif: true, size: 18 }); from = q; });
      dot(from.sx, from.sy, RED, w >= 3 ? 8 : 6);
      if (w >= 3) text(hidden ? '(?, ?, ?)' : coordText(p, '3d'), from.sx + 4, from.sy - 22, { color: RED, size: 17, serif: true });
    } else if (activity !== 'journey' && pts[0]) {
      const p = pts[0];
      if (props.showGuides) {
        const V = (a: number, b: number, c: number) => P(a ? p.x : 0, b ? p.y : 0, c ? p.z : 0);
        for (let i = 0; i < 8; i++) for (let k = 0; k < 3; k++) if (!(i & (1 << k))) {
          const a = V(i & 1, (i >> 1) & 1, (i >> 2) & 1), b = V((i | (1 << k)) & 1, ((i | (1 << k)) >> 1) & 1, ((i | (1 << k)) >> 2) & 1);
          const qa = to(a), qb = to(b); line(qa.sx, qa.sy, qb.sx, qb.sy, '#6d28d9', 1.4, [6, 4]);
        }
        const p1 = to(P(p.x, 0, 0)), p2 = to(P(p.x, p.y, 0)), p3 = to(p);
        line(O.sx, O.sy, p1.sx, p1.sy, RED, 3); line(p1.sx, p1.sy, p2.sx, p2.sy, RED, 3); line(p2.sx, p2.sy, p3.sx, p3.sy, RED, 3);
        if (!hidden) {
          text('x', (O.sx + p1.sx) / 2 + (p.x >= 0 ? 0 : 0) - 8, (O.sy + p1.sy) / 2 + 12, { color: RED, italic: true, serif: true, size: 18 });
          text('y', (p1.sx + p2.sx) / 2, (p1.sy + p2.sy) / 2 + 14, { color: RED, italic: true, serif: true, size: 18 });
          text('z', (p2.sx + p3.sx) / 2 + 12, (p2.sy + p3.sy) / 2, { color: RED, italic: true, serif: true, size: 18 });
        }
      }
      const q = to(p); dot(q.sx, q.sy, RED, 8, !readOnly);
      text(hidden ? '(?, ?, ?)' : coordText(p, '3d'), q.sx + 4, q.sy - 22, { color: RED, size: 17, serif: true });
    }

    if (activity === 'journey') {
      pts.forEach(p => { if (props.showGuides) dropLines(p, 'rgba(100,100,120,0.55)'); });
      if (showJourney) {
        if (props.showComponents && J.magnitude > 1e-9) {
          const s0 = pts[0], d = J.displacement, a = to(s0), b = to(P(s0.x + d.x, s0.y, s0.z)), c = to(P(s0.x + d.x, s0.y + d.y, s0.z)), e = to(P(s0.x + d.x, s0.y + d.y, s0.z + d.z));
          line(a.sx, a.sy, b.sx, b.sy, RED, 1.8, [6, 4]); line(b.sx, b.sy, c.sx, c.sy, GREEN, 1.8, [6, 4]); line(c.sx, c.sy, e.sx, e.sy, BLUE, 1.8, [6, 4]);
          text(`Δx=${fmt(d.x)}`, (a.sx + b.sx) / 2, (a.sy + b.sy) / 2 + 12, { color: RED, size: 11, bold: true });
          text(`Δy=${fmt(d.y)}`, (b.sx + c.sx) / 2 + 4, (b.sy + c.sy) / 2 + 12, { color: GREEN, size: 11, bold: true });
          text(`Δz=${fmt(d.z)}`, (c.sx + e.sx) / 2 + 22, (c.sy + e.sy) / 2, { color: BLUE, size: 11, bold: true });
        }
        J.legs.forEach((l, i) => { const a = to(l.from), b = to(l.to); arrow(a.sx, a.sy, b.sx, b.sy, colour(i + 1), 3.2, [], 11); });
        if (J.magnitude > 1e-9) { const a = to(pts[0]), b = to(pts[pts.length - 1]); arrow(a.sx, a.sy, b.sx, b.sy, ROSE, 2.6, [8, 5], 11); }
      }
      [...pts.map((p, i) => ({ p, i }))].sort((u, v) => to(u.p).depth - to(v.p).depth).forEach(({ p, i }) => {
        const q = to(p); dot(q.sx, q.sy, colour(i), 8, i === selected && !readOnly);
        const o = lab(i); text(`${labels[i]} ${coords(p)}`, q.sx + o.dx, q.sy + o.dy, { color: colour(i), bold: true, size: 12, align: o.al });
      });
    }
  }, [dim, activity, width, height, points, selected, view, props.showPlanes, props.showGrid, props.showGuides, props.showComponents, props.hideCoords, props.walk, readOnly, labels]);

  // ── Pointer handling ─────────────────────────────────────────────────────
  const local = (e: React.PointerEvent) => { const r = ref.current!.getBoundingClientRect(); return { x: ((e.clientX - r.left) / r.width) * width, y: ((e.clientY - r.top) / r.height) * height }; };
  const visible = activity === 'journey' ? points.length : 1;

  const down = (e: React.PointerEvent) => {
    const m = local(e), G = geometry(dim, width, height, view);
    let best = -1, bd = 22;
    for (let i = 0; i < visible; i++) { const q = G.to(clampDim(points[i], dim)); const d = Math.hypot(q.sx - m.x, q.sy - m.y); if (d < bd) { bd = d; best = i; } }
    ref.current!.setPointerCapture(e.pointerId);
    if (best >= 0 && !readOnly) { drag.current = { kind: 'point', i: best }; props.onSelect(best); }
    else if (dim === '3d') drag.current = { kind: 'view', x: e.clientX, y: e.clientY, yaw: view.yaw, pitch: view.pitch };
  };
  const move = (e: React.PointerEvent) => {
    const d = drag.current; if (!d) return;
    if (d.kind === 'view') {
      props.onView({ yaw: d.yaw - (e.clientX - d.x) * 0.01, pitch: Math.max(PITCH_MIN, Math.min(PITCH_MAX, d.pitch + (e.clientY - d.y) * 0.008)) });
      return;
    }
    const m = local(e), G = geometry(dim, width, height, view), r = G.range, cur = clampDim(points[d.i], dim);
    const q = (v: number) => clampTo(snapTo(v, snap), r);
    let next = cur;
    if (dim === '1d') next = P(q((m.x - G.x0) / G.scale - r), 0, 0);
    else if (dim === '2d') next = P(q((m.x - G.cx) / G.scale), q((G.cy - m.y) / G.scale), 0);
    else if (dragAxis === 'floor') { const f = unprojectFloor(m.x, m.y, cur.z, G.cam!); if (f) next = P(q(f.x), q(f.y), cur.z); }
    else next = P(cur.x, cur.y, q(unprojectHeight(m.y, cur.x, cur.y, G.cam!)));
    if (next.x !== cur.x || next.y !== cur.y || next.z !== cur.z) props.onMove(d.i, next);
  };
  const up = () => { drag.current = null; };

  const key = (e: React.KeyboardEvent) => {
    if (readOnly) return;
    const i = Math.min(selected, visible - 1), p = clampDim(points[i], dim), step = snap > 0 ? snap : 0.5, r = RANGE[dim];
    const d: Record<string, [number, number, number]> = { ArrowRight: [step, 0, 0], ArrowLeft: [-step, 0, 0], ArrowUp: [0, step, 0], ArrowDown: [0, -step, 0], PageUp: [0, 0, step], PageDown: [0, 0, -step] };
    const v = d[e.key]; if (!v) return;
    if ((dim === '1d' && (v[1] || v[2])) || (dim === '2d' && v[2])) return;
    e.preventDefault();
    props.onMove(i, P(clampTo(snapTo(p.x + v[0], snap), r), clampTo(snapTo(p.y + v[1], snap), r), clampTo(snapTo(p.z + v[2], snap), r)));
  };

  return (
    <canvas
      ref={ref} width={width} height={height} tabIndex={0}
      style={{ width, height, touchAction: 'none', cursor: readOnly ? 'default' : 'grab', display: 'block', maxWidth: '100%' }}
      onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up} onKeyDown={key}
      role="img"
      aria-label={`${dim.toUpperCase()} coordinate space. ${readOnly ? 'A point is shown for you to read its coordinates.' : 'Drag the points, or select one and use the arrow keys' + (dim === '3d' ? ' and Page Up / Page Down for height' : '') + ' to move it.'}${dim === '3d' ? ' Drag empty space to rotate the view.' : ''}`}
    />
  );
}
