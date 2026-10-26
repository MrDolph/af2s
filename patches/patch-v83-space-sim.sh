#!/bin/bash
# A-Factor STEM Studio — Physics: "Space" simulation (v83), first sim in the new "Space and time" topic
# Run inside af2s/ (the project ROOT):
#     bash patches/patch-v83-space-sim.sh
#
# ADDS   /simulations/space   Space: position, distance & displacement
#   - 1D line, 2D plane and 3D space (right-handed X, Y, Z axes with the three coloured coordinate planes)
#   - LOCATE A POINT: type, slide, drag or use the arrow keys; guide lines (2D) or the dashed box and red
#     x-y-z legs (3D); readouts (quadrant, signs, distance from O, distance from each coordinate plane,
#     feet of the perpendiculars); "Walk to the point" step-by-step / play (origin -> x -> y -> z)
#   - DISTANCE & DISPLACEMENT: journeys of 2-5 points; distance (path length) vs displacement (vector),
#     components, direction (1D sign; 2D angle theta, compass direction and bearing; 3D axis angles, azimuth,
#     elevation), a leg table and the distance formula written out with the numbers substituted; presets
#   - PRACTICE: "Place the point" and "Read the coordinates" with scoring and per-coordinate hints
#   - 3D: drag empty space to rotate, drag a point across the floor or up/down, Default/Top/Front/Side views
#   - Teacher notes and worked exercises (with answers) for each dimension; mobile friendly; embeddable
#   /embed/space             embeddable version (?dim=1d|2d|3d &act=locate|journey &pts=x,y,z;x,y,z)
# EDITS  src/app/simulations/page.tsx: adds the sim card and a "Space and time" topic filter (idempotent)
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -f src/app/simulations/page.tsx ]; then echo "ERROR: run from the project root (package.json + src/app/simulations/page.tsx)."; exit 1; fi
if ! command -v node >/dev/null 2>&1; then echo "ERROR: 'node' not found on PATH (needed to edit src/app/simulations/page.tsx)."; exit 1; fi
for f in src/hooks/useResponsiveCanvasSize.ts src/components/ui/EmbedButton.tsx; do
  if [ ! -f "$f" ]; then echo "ERROR: $f not found - this patch expects the existing simulation helpers."; exit 1; fi
done

echo "Applying Space simulation (v83)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/physics/space.ts << 'FILEEOF'
// Space sim: position, distance and displacement in 1D, 2D and 3D.
//
// Conventions (stated on the page too):
//  • Right-handed axes: X × Y = Z. In 2D, x points east and y points north.
//  • Distance is the scalar length of the PATH; displacement is the vector from the first
//    point to the last point. Distance ≥ |displacement|, with equality only for a straight run
//    that never reverses.

export type Dim = '1d' | '2d' | '3d';
export interface P3 { x: number; y: number; z: number }
export const P = (x = 0, y = 0, z = 0): P3 => ({ x, y, z });

export const sub = (a: P3, b: P3): P3 => P(a.x - b.x, a.y - b.y, a.z - b.z);
export const len = (a: P3) => Math.hypot(a.x, a.y, a.z);
export const RANGE: Record<Dim, number> = { '1d': 10, '2d': 10, '3d': 6 };
export const MAX_POINTS = 5;
export const LABELS = ['A', 'B', 'C', 'D', 'E'];

/** Trim to at most `d` decimals without trailing zeros (3.10 → "3.1"). */
export const fmt = (n: number, d = 2): string => {
  const v = Number(n.toFixed(d));
  return String(Object.is(v, -0) ? 0 : v).replace('-', '−');
};
const par = (n: number) => (n < 0 ? `(${fmt(n)})` : fmt(n));

/** Zero the coordinates a dimension doesn't use, so 1D/2D maths never picks up stray values. */
export const clampDim = (p: P3, dim: Dim): P3 => P(p.x, dim === '1d' ? 0 : p.y, dim === '3d' ? p.z : 0);

export const snapTo = (v: number, step: number) => (step > 0 ? Math.round(v / step) * step : Math.round(v * 10) / 10);
export const clampTo = (v: number, r: number) => Math.max(-r, Math.min(r, v));

export function coordText(p: P3, dim: Dim): string {
  if (dim === '1d') return `x = ${fmt(p.x)}`;
  if (dim === '2d') return `(${fmt(p.x)}, ${fmt(p.y)})`;
  return `(${fmt(p.x)}, ${fmt(p.y)}, ${fmt(p.z)})`;
}

// ── Journeys ────────────────────────────────────────────────────────────────
export interface Leg { from: P3; to: P3; delta: P3; length: number }

export interface Direction {
  /** One-line plain-English description. */
  text: string;
  /** 2D: angle from +x, counter-clockwise, in [0, 360). */
  theta?: number;
  /** 2D: compass bearing, clockwise from north (+y), in [0, 360). */
  bearing?: number;
  /** 2D: e.g. "36.9° north of east". */
  compass?: string;
  /** 3D: angles with the +x, +y, +z axes. */
  axisAngles?: { x: number; y: number; z: number };
  /** 3D: azimuth in the xy-plane from +x, and elevation above the xy-plane. */
  azimuth?: number;
  elevation?: number;
}

export interface JourneyResult {
  legs: Leg[];
  distance: number;
  displacement: P3;
  magnitude: number;
  direction: Direction;
  /** True when distance equals |displacement| (to rounding). */
  straight: boolean;
}

const deg = (r: number) => (r * 180) / Math.PI;
const EPS = 1e-9;

export function describeDirection(d: P3, dim: Dim): Direction {
  const m = len(d);
  if (m < EPS) return { text: 'Zero displacement — the end point is the start point.' };
  if (dim === '1d') return { text: d.x > 0 ? 'In the +x direction (to the right)' : 'In the −x direction (to the left)' };
  if (dim === '2d') {
    const theta = (deg(Math.atan2(d.y, d.x)) + 360) % 360;
    const bearing = (90 - theta + 360) % 360;
    const a = Math.abs(d.x) < EPS ? null : Math.abs(deg(Math.atan(d.y / d.x)));
    let compass: string;
    if (Math.abs(d.x) < EPS) compass = d.y > 0 ? 'due north' : 'due south';
    else if (Math.abs(d.y) < EPS) compass = d.x > 0 ? 'due east' : 'due west';
    else compass = `${fmt(a!, 1)}° ${d.y > 0 ? 'north' : 'south'} of ${d.x > 0 ? 'east' : 'west'}`;
    return { text: `${compass} (θ = ${fmt(theta, 1)}° from +x)`, theta, bearing, compass };
  }
  const ang = (c: number) => deg(Math.acos(Math.max(-1, Math.min(1, c / m))));
  const azimuth = (deg(Math.atan2(d.y, d.x)) + 360) % 360;
  const elevation = deg(Math.asin(d.z / m));
  return {
    text: `${fmt(Math.abs(elevation), 1)}° ${elevation >= 0 ? 'above' : 'below'} the xy-plane, azimuth ${fmt(azimuth, 1)}° from +x`,
    axisAngles: { x: ang(d.x), y: ang(d.y), z: ang(d.z) }, azimuth, elevation,
  };
}

export function analyseJourney(points: P3[], dim: Dim): JourneyResult {
  const pts = points.map(p => clampDim(p, dim));
  const legs: Leg[] = [];
  for (let i = 1; i < pts.length; i++) {
    const delta = sub(pts[i], pts[i - 1]);
    legs.push({ from: pts[i - 1], to: pts[i], delta, length: len(delta) });
  }
  const distance = legs.reduce((s, l) => s + l.length, 0);
  const displacement = pts.length ? sub(pts[pts.length - 1], pts[0]) : P();
  const magnitude = len(displacement);
  return { legs, distance, displacement, magnitude, direction: describeDirection(displacement, dim), straight: Math.abs(distance - magnitude) < 1e-7 };
}

/** The distance formula written out with the numbers substituted, for showing working. */
export function distanceWorking(a: P3, b: P3, dim: Dim): string {
  const d = sub(b, a), m = len(d);
  if (dim === '1d') return `d = |x₂ − x₁| = |${fmt(b.x)} − ${par(a.x)}| = ${fmt(m)}`;
  const t = (k: 'x' | 'y' | 'z') => `${par(d[k])}²`;
  const sym = dim === '2d' ? '√((x₂−x₁)² + (y₂−y₁)²)' : '√((x₂−x₁)² + (y₂−y₁)² + (z₂−z₁)²)';
  const nums = dim === '2d' ? `√(${t('x')} + ${t('y')})` : `√(${t('x')} + ${t('y')} + ${t('z')})`;
  return `d = ${sym} = ${nums} = ${fmt(m)}`;
}

export function quadrant(p: P3): string {
  if (Math.abs(p.x) < EPS || Math.abs(p.y) < EPS) return Math.abs(p.x) < EPS && Math.abs(p.y) < EPS ? 'the origin' : 'on an axis';
  return p.x > 0 ? (p.y > 0 ? 'quadrant I' : 'quadrant IV') : (p.y > 0 ? 'quadrant II' : 'quadrant III');
}
export function octant(p: P3): string {
  const s = (v: number) => (v > EPS ? '+' : v < -EPS ? '−' : '0');
  return `signs (x, y, z) = (${s(p.x)}, ${s(p.y)}, ${s(p.z)})`;
}

// ── Presets ─────────────────────────────────────────────────────────────────
export interface JourneyPreset { label: string; points: P3[]; note: string }
export const JOURNEY_PRESETS: Record<Dim, JourneyPreset[]> = {
  '1d': [
    { label: 'There and back', points: [P(2), P(9), P(4)], note: 'Distance 12, displacement +2: reversing makes distance bigger than |displacement|.' },
    { label: 'Straight run', points: [P(-3), P(6)], note: 'No reversal, so distance = |displacement| = 9.' },
    { label: 'Round trip', points: [P(1), P(7), P(1)], note: 'Back where it started: distance 12 but displacement 0.' },
  ],
  '2d': [
    { label: '3-4-5 triangle', points: [P(0, 0), P(3, 0), P(3, 4)], note: 'Walk 3 east then 4 north: distance 7, displacement 5.' },
    { label: 'Square loop', points: [P(1, 1), P(5, 1), P(5, 5), P(1, 5), P(1, 1)], note: 'Distance 16, displacement 0.' },
    { label: 'Shortcut', points: [P(-4, -2), P(5, 6)], note: 'A straight line: distance equals |displacement| = √145 ≈ 12.04.' },
  ],
  '3d': [
    { label: 'Walk the axes', points: [P(0, 0, 0), P(2, 0, 0), P(2, 3, 0), P(2, 3, 6)], note: 'Along x, then y, then up z: distance 11, displacement 7.' },
    { label: 'Space diagonal', points: [P(0, 0, 0), P(2, 3, 6)], note: 'The straight line: 7 units, since 2² + 3² + 6² = 7².' },
    { label: 'Down and across', points: [P(-2, 1, 4), P(3, -2, 1)], note: 'Δ = (5, −3, −3), so d = √43 ≈ 6.56.' },
  ],
};

// ── 3D camera ────────────────────────────────────────────────────────────────
export interface View { yaw: number; pitch: number }
export const DEFAULT_VIEW: View = { yaw: (30 * Math.PI) / 180, pitch: (22 * Math.PI) / 180 };
export const PITCH_MIN = (6 * Math.PI) / 180, PITCH_MAX = (85 * Math.PI) / 180;

/** Orthonormal camera basis: r = screen-right, u = screen-up, c = towards the camera. */
export function basis(v: View) {
  const ca = Math.cos(v.yaw), sa = Math.sin(v.yaw), ce = Math.cos(v.pitch), se = Math.sin(v.pitch);
  return { r: [-sa, ca, 0] as const, u: [-ca * se, -sa * se, ce] as const, c: [ce * ca, ce * sa, se] as const };
}
const dot = (p: P3, v: readonly number[]) => p.x * v[0] + p.y * v[1] + p.z * v[2];

export interface Cam { view: View; scale: number; cx: number; cy: number }
export function project(p: P3, cam: Cam) {
  const b = basis(cam.view);
  return { sx: cam.cx + cam.scale * dot(p, b.r), sy: cam.cy - cam.scale * dot(p, b.u), depth: dot(p, b.c) };
}
/** Screen point → (x, y) on the horizontal plane z = z0. Null if the view is edge-on. */
export function unprojectFloor(sx: number, sy: number, z0: number, cam: Cam): { x: number; y: number } | null {
  const b = basis(cam.view);
  const a = (sx - cam.cx) / cam.scale, c = (cam.cy - sy) / cam.scale - b.u[2] * z0;
  const det = b.r[0] * b.u[1] - b.r[1] * b.u[0];
  if (Math.abs(det) < 1e-6) return null;
  return { x: (a * b.u[1] - b.r[1] * c) / det, y: (b.r[0] * c - b.u[0] * a) / det };
}
/** Screen y → z for a point whose (x, y) is fixed (dragging straight up/down). */
export function unprojectHeight(sy: number, x: number, y: number, cam: Cam): number {
  const b = basis(cam.view);
  return ((cam.cy - sy) / cam.scale - b.u[0] * x - b.u[1] * y) / b.u[2];
}

// ── Practice ─────────────────────────────────────────────────────────────────
export function randomTarget(dim: Dim, rand: () => number = Math.random): P3 {
  const r = dim === '3d' ? 4 : 8;
  const pick = () => Math.round((rand() * 2 - 1) * r);
  for (let i = 0; i < 50; i++) {
    const p = clampDim(P(pick(), pick(), pick()), dim);
    const nonzero = [p.x, dim !== '1d' ? p.y : 1, dim === '3d' ? p.z : 1].every(v => v !== 0);
    if (nonzero) return p;
  }
  return clampDim(P(3, 2, 4), dim);
}

export function checkAnswer(target: P3, answer: P3, dim: Dim, tol = 0.01): { correct: boolean; hints: string[] } {
  const axes: ('x' | 'y' | 'z')[] = dim === '1d' ? ['x'] : dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  const hints: string[] = [];
  for (const k of axes) {
    const e = answer[k] - target[k];
    if (Math.abs(e) > tol) hints.push(`${k} is ${fmt(Math.abs(e))} too ${e > 0 ? 'high' : 'low'}`);
  }
  return { correct: hints.length === 0, hints };
}
FILEEOF

write_file src/components/simulation/SpaceCanvas.tsx << 'FILEEOF'
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
FILEEOF

write_file src/app/simulations/space/page.tsx << 'FILEEOF'
'use client';
import { useEffect, useRef, useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { SpaceCanvas, POINT_COLORS, type Activity } from '@/components/simulation/SpaceCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import {
  type Dim, type P3, type View, DEFAULT_VIEW, JOURNEY_PRESETS, LABELS, MAX_POINTS, P, RANGE, analyseJourney, checkAnswer, clampDim,
  clampTo, coordText, distanceWorking, fmt, len, octant, quadrant, randomTarget,
} from '@/lib/physics/space';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = { WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700', IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700', JUPEB: 'bg-purple-100 text-purple-700' };
const DIMS: { id: Dim; title: string; icon: string; sub: string }[] = [
  { id: '1d', title: '1D · Line', icon: '📏', sub: 'One number locates a point: x' },
  { id: '2d', title: '2D · Plane', icon: '🗺️', sub: 'Two numbers locate a point: (x, y)' },
  { id: '3d', title: '3D · Space', icon: '🧊', sub: 'Three numbers locate a point: (x, y, z)' },
];
const ACTS: { id: Activity; title: string; icon: string }[] = [
  { id: 'locate', title: 'Locate a point', icon: '📍' }, { id: 'journey', title: 'Distance & displacement', icon: '🧭' }, { id: 'practice', title: 'Practice', icon: '🎯' },
];
const VIEWS: { label: string; v: View }[] = [
  { label: 'Default', v: DEFAULT_VIEW }, { label: 'Top (xy)', v: { yaw: 0, pitch: (85 * Math.PI) / 180 } },
  { label: 'Front (xz)', v: { yaw: -Math.PI / 2, pitch: (6 * Math.PI) / 180 } }, { label: 'Side (yz)', v: { yaw: 0, pitch: (6 * Math.PI) / 180 } },
];

const NOTES: Record<Dim, string[]> = {
  '1d': [
    'Position is a signed number: its sign tells you the side of the origin, its size tells you how far.',
    'Always say where the origin is and which way is positive before you calculate anything.',
    'Distance is a scalar (path length, never negative). Displacement is a vector: Δx = x_final − x_initial, and its sign is its direction.',
    'Reversing direction adds to the distance but subtracts from the displacement. A round trip has displacement zero.',
  ],
  '2d': [
    'An ordered pair (x, y): x is read first (horizontal), then y (vertical). (3, 4) and (4, 3) are different points.',
    'The signs of x and y give the quadrant: I (+,+), II (−,+), III (−,−), IV (+,−).',
    'The distance between two points is Pythagoras on the differences: d = √(Δx² + Δy²). Δx and Δy are the legs of a right triangle.',
    'Direction: θ is measured counter-clockwise from +x, but exams often use a bearing (clockwise from north). Bearing = 90° − θ (add 360° if negative).',
  ],
  '3d': [
    'Three numbers locate a point in space: walk x along the X axis, then y parallel to Y, then z parallel to Z. The order does not matter.',
    'The axes are right-handed: point the fingers of your right hand along +X, curl them towards +Y, and your thumb points along +Z.',
    'A point’s distance from a coordinate plane is the absolute value of the one coordinate that plane does not contain: |z| from the xy-plane, |x| from the yz-plane, |y| from the xz-plane.',
    'The distance between two points extends Pythagoras to three terms: d = √(Δx² + Δy² + Δz²). Rotate the view to see the right triangles inside the box.',
  ],
};
const EXERCISES: Record<Dim, { q: string; a: string }[]> = {
  '1d': [
    { q: 'A runner starts at x = 2 m, runs to x = 9 m, then back to x = 4 m. Find the distance and the displacement.', a: 'Distance = 7 + 5 = 12 m. Displacement = 4 − 2 = +2 m (2 m in the +x direction).' },
    { q: 'A lift starts at +15 m (5th floor) and stops at −6 m (basement), with the upward direction positive. Find the distance and displacement.', a: 'Distance = 21 m. Displacement = −6 − 15 = −21 m, i.e. 21 m downward.' },
    { q: 'Can the distance travelled ever be less than the magnitude of the displacement?', a: 'No. Distance ≥ |displacement|, with equality only for motion in a straight line without reversing.' },
  ],
  '2d': [
    { q: 'A walks from (1, 2) to (4, 6). Find the distance and the direction of the displacement.', a: 'Δ = (3, 4), so d = √(9 + 16) = 5. Direction: tan⁻¹(4/3) = 53.1° north of east (θ = 53.1°, bearing 036.9°).' },
    { q: 'A student walks 3 m east, 4 m north, then 3 m west. Find the distance and the displacement.', a: 'Distance = 3 + 4 + 3 = 10 m. Displacement = (0, 4): 4 m due north.' },
    { q: 'Point P is at (−3, −4). Which quadrant is it in, how far is it from the origin, and what is the bearing of P from the origin?', a: 'Quadrant III. Distance = √(9 + 16) = 5. θ = 233.1° from +x, so the bearing is 90° − 233.1° + 360° = 216.9° (53.1° south of west).' },
  ],
  '3d': [
    { q: 'P is at (2, 3, 6). Find its distance from the origin, and from each coordinate plane.', a: 'OP = √(4 + 9 + 36) = 7. From the xy-plane: |z| = 6. From the yz-plane: |x| = 2. From the xz-plane: |y| = 3.' },
    { q: 'A = (1, −2, 0) and B = (3, 1, 6). Find the distance AB.', a: 'Δ = (2, 3, 6), so AB = √(4 + 9 + 36) = 7.' },
    { q: 'A drone flies from the origin 2 m along x, then 3 m along y, then 6 m up z. Find the distance flown and the displacement magnitude.', a: 'Distance = 2 + 3 + 6 = 11 m. Displacement = (2, 3, 6), magnitude √49 = 7 m.' },
  ],
};

const initialLocate: Record<Dim, P3> = { '1d': P(3), '2d': P(3, 4), '3d': P(3, 2, 4) };
const initialJourney = (): Record<Dim, P3[]> => ({ '1d': JOURNEY_PRESETS['1d'][0].points, '2d': JOURNEY_PRESETS['2d'][0].points, '3d': JOURNEY_PRESETS['3d'][0].points });

function NumField({ label, value, onCommit, min, max, color }: { label: string; value: number; onCommit: (v: number) => void; min: number; max: number; color: string }) {
  const [text, setText] = useState<string | null>(null);
  return (
    <label className="flex flex-1 items-center gap-1.5 text-xs">
      <span className="font-semibold" style={{ color }}>{label}</span>
      <input type="number" inputMode="decimal" step="any" min={min} max={max} aria-label={label}
        value={text ?? String(value)}
        onChange={e => { setText(e.target.value); const v = Number(e.target.value); if (e.target.value !== '' && e.target.value !== '-' && Number.isFinite(v)) onCommit(clampTo(v, max)); }}
        onBlur={() => setText(null)}
        className="h-8 w-full min-w-0 rounded-md border border-gray-200 bg-white px-2 text-sm tabular-nums" />
    </label>
  );
}

const Stat = ({ k, v, c = 'text-gray-900' }: { k: string; v: React.ReactNode; c?: string }) => (
  <div className="flex items-center justify-between gap-3 rounded-lg bg-gray-50 px-3 py-2"><span className="text-xs text-gray-500">{k}</span><span className={`text-right text-sm font-semibold tabular-nums ${c}`}>{v}</span></div>
);
const Toggle = ({ label, on, set }: { label: string; on: boolean; set: (v: boolean) => void }) => (
  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} />{label}</label>
);

function walkText(step: number, p: P3, dim: Dim): string {
  const dir = (v: number, axis: string) => `${fmt(Math.abs(v))} unit${Math.abs(v) === 1 ? '' : 's'} ${v >= 0 ? 'along +' : 'along −'}${axis}`;
  if (step === 0) return 'Start at the origin O, where every coordinate is 0. Press Step to walk to the point.';
  if (step === 1) return `Step 1 — move ${dir(p.x, 'X')} (x = ${fmt(p.x)}). You are now at (${fmt(p.x)}, 0${dim === '3d' ? ', 0' : ''}).`;
  if (step === 2) return dim === '2d' ? `Step 2 — from there move ${dir(p.y, 'Y')} (y = ${fmt(p.y)}), parallel to the y-axis. You have arrived at ${coordText(p, dim)}.` : `Step 2 — now move ${dir(p.y, 'Y')} (y = ${fmt(p.y)}), parallel to the Y axis. You are at (${fmt(p.x)}, ${fmt(p.y)}, 0), directly ${p.z >= 0 ? 'below' : 'above'} the point.`;
  return `Step 3 — finally move ${dir(p.z, 'Z')} (z = ${fmt(p.z)}), parallel to the Z axis. You have arrived at ${coordText(p, dim)}.`;
}

export default function SpacePage() {
  const [dim, setDim] = useState<Dim>('3d');
  const [act, setAct] = useState<Activity>('locate');
  const [locate, setLocate] = useState<Record<Dim, P3>>(initialLocate);
  const [journey, setJourney] = useState<Record<Dim, P3[]>>(initialJourney);
  const [sel, setSel] = useState(0);
  const [snap, setSnap] = useState(1);
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const [dragAxis, setDragAxis] = useState<'floor' | 'height'>('floor');
  const [planes, setPlanes] = useState(true); const [grid, setGrid] = useState(true); const [guides, setGuides] = useState(true); const [comps, setComps] = useState(true);
  const [walk, setWalk] = useState<number | undefined>(undefined);
  const [playing, setPlaying] = useState(false);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [curr, setCurr] = useState(['WAEC', 'IGCSE', 'SAT']);
  // practice
  const [pKind, setPKind] = useState<'place' | 'read'>('place');
  const [target, setTarget] = useState<P3 | null>(null);
  const [place, setPlace] = useState<Record<Dim, P3>>({ '1d': P(0), '2d': P(0, 0), '3d': P(0, 0, 0) });
  const [typed, setTyped] = useState({ x: '', y: '', z: '' });
  const [result, setResult] = useState<{ correct: boolean; hints: string[] } | null>(null);
  const [score, setScore] = useState({ right: 0, tries: 0 });

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 660, dim === '3d' ? 440 : 400, 900);
  // Narrow screens: a wide, short canvas would shrink the 2D/3D figures and clip the planes, so make them near-square.
  const compact = size.width < 560;
  const canvasH = compact ? Math.round(size.width * (dim === '1d' ? 0.62 : 1.0)) : size.height;
  const R = RANGE[dim];
  const readMode = act === 'practice' && pKind === 'read';

  // Auto-play for the guided walk: each tick is a timeout scheduled from the current step.
  useEffect(() => {
    if (!playing) return;
    const max = dim === '3d' ? 3 : 2, w = walk ?? 0;
    const id = setTimeout(() => { if (w >= max) setPlaying(false); else setWalk(w + 1); }, w >= max ? 0 : 1100);
    return () => clearTimeout(id);
  }, [playing, walk, dim]);

  const newChallenge = (kind = pKind, d = dim) => { setTarget(randomTarget(d)); setTyped({ x: '', y: '', z: '' }); setResult(null); setPlace(p => ({ ...p, [d]: P(0, 0, 0) })); setPKind(kind); };
  const changeDim = (d: Dim) => { setDim(d); setSel(0); setWalk(undefined); setPlaying(false); setResult(null); if (act === 'practice') newChallenge(pKind, d); };
  const changeAct = (a: Activity) => { setAct(a); setSel(0); setWalk(undefined); setPlaying(false); setResult(null); if (a === 'practice' && !target) newChallenge(pKind, dim); };

  const shown: P3[] = act === 'locate' ? [locate[dim]] : act === 'journey' ? journey[dim] : readMode ? [target ?? P()] : [place[dim]];
  const moveShown = (i: number, p: P3) => {
    if (act === 'locate') setLocate(s => ({ ...s, [dim]: p }));
    else if (act === 'journey') setJourney(s => ({ ...s, [dim]: s[dim].map((q, k) => (k === i ? p : q)) }));
    else if (!readMode) setPlace(s => ({ ...s, [dim]: p }));
    setWalk(undefined); setResult(null);
  };
  const J = analyseJourney(journey[dim], dim);
  const p = locate[dim];
  const first = journey[dim][0], last = journey[dim][journey[dim].length - 1];

  const check = () => {
    if (!target) return;
    const ans = pKind === 'place' ? clampDim(place[dim], dim) : clampDim(P(Number(typed.x), Number(typed.y || 0), Number(typed.z || 0)), dim);
    const bad = pKind === 'read' && [typed.x, dim !== '1d' ? typed.y : '0', dim === '3d' ? typed.z : '0'].some(v => v === '' || !Number.isFinite(Number(v)));
    if (bad) { setResult({ correct: false, hints: ['Fill in every coordinate first.'] }); return; }
    const r = checkAnswer(target, ans, dim, 0.01);
    setResult(r); setScore(s => ({ right: s.right + (r.correct ? 1 : 0), tries: s.tries + 1 }));
  };

  const dimMeta = DIMS.find(d => d.id === dim)!;
  const fields: ('x' | 'y' | 'z')[] = dim === '1d' ? ['x'] : dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  const axisColor = { x: '#dc2626', y: '#16a34a', z: '#2563eb' };
  const walkMax = dim === '3d' ? 3 : 2;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 py-4 sm:px-6">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div><p className="mb-0.5 text-xs text-gray-400">Space and time</p><h1 className="text-lg font-semibold text-gray-900">Space: position, distance &amp; displacement</h1></div>
              <div className="flex flex-wrap gap-1.5">
                {CURRICULA.map(c => <button key={c} onClick={() => setCurr(s => (s.includes(c) ? s.filter(x => x !== c) : [...s, c]))} className={`rounded-full border px-2.5 py-2 text-xs font-medium transition ${curr.includes(c) ? CC[c] + ' border-transparent' : 'border-gray-200 bg-white text-gray-400'}`}>{c}</button>)}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] space-y-4 px-4 py-4 sm:px-6">
          <div className="flex gap-1 overflow-x-auto rounded-xl bg-gray-100 p-1" role="tablist" aria-label="Number of dimensions">
            {DIMS.map(d => <button key={d.id} role="tab" aria-selected={dim === d.id} onClick={() => changeDim(d.id)} className={`flex shrink-0 items-center gap-1.5 rounded-lg px-3 py-2 text-xs font-medium transition ${dim === d.id ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}><span>{d.icon}</span>{d.title}</button>)}
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex gap-1 overflow-x-auto" role="tablist" aria-label="Activity">
              {ACTS.map(a => <button key={a.id} role="tab" aria-selected={act === a.id} onClick={() => changeAct(a.id)} className={`shrink-0 rounded-full border px-3 py-1.5 text-xs font-medium transition ${act === a.id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{a.icon} {a.title}</button>)}
            </div>
            <span className="text-xs text-gray-500">{dimMeta.sub}</span>
            {act === 'journey' && <span className="rounded-lg border border-gray-200 bg-white px-2.5 py-2 font-mono text-xs text-gray-700">{dim === '1d' ? 'Δx = x₂ − x₁' : dim === '2d' ? 'd = √(Δx² + Δy²)' : 'd = √(Δx² + Δy² + Δz²)'}</span>}
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_300px] xl:grid-cols-[1fr_300px_280px]">
            {/* Canvas + controls */}
            <div className="min-w-0 space-y-3">
              <div ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                <SpaceCanvas
                  dim={dim} activity={act} width={size.width} height={canvasH}
                  points={shown} labels={readMode ? ['P'] : act === 'practice' ? ['P'] : act === 'locate' ? ['P'] : LABELS}
                  selected={Math.min(sel, shown.length - 1)} onMove={moveShown} onSelect={setSel} snap={snap} view={view} onView={setView} dragAxis={dragAxis}
                  showPlanes={planes} showGrid={grid} showGuides={guides} showComponents={comps}
                  readOnly={readMode} hideCoords={readMode} walk={act === 'locate' && dim !== '1d' ? walk : undefined}
                />
              </div>

              <div className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5">
                <label className="flex items-center gap-1.5 text-xs text-gray-600">Snap
                  <select value={snap} onChange={e => setSnap(Number(e.target.value))} className="h-7 rounded-md border border-gray-200 bg-white px-1.5 text-xs">
                    <option value={1}>whole numbers</option><option value={0.5}>0.5</option><option value={0}>0.1 (free)</option>
                  </select>
                </label>
                {dim === '3d' && <>
                  <div className="flex items-center gap-1.5 text-xs text-gray-600">Drag point
                    <div className="flex overflow-hidden rounded-md border border-gray-200">
                      {(['floor', 'height'] as const).map(m => <button key={m} onClick={() => setDragAxis(m)} aria-pressed={dragAxis === m} className={`px-2 py-1 text-xs ${dragAxis === m ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600'}`}>{m === 'floor' ? 'across floor (x, y)' : 'up / down (z)'}</button>)}
                    </div>
                  </div>
                  <Toggle label="Planes" on={planes} set={setPlanes} />
                  <Toggle label="Floor grid" on={grid} set={setGrid} />
                </>}
                {dim === '2d' && <Toggle label="Grid" on={grid} set={setGrid} />}
                {act === 'locate' && <Toggle label={dim === '3d' ? 'Box & projection lines' : 'Guide lines'} on={guides} set={setGuides} />}
                {act === 'journey' && <><Toggle label="Components" on={comps} set={setComps} />{dim === '3d' && <Toggle label="Drop lines" on={guides} set={setGuides} />}</>}
                <div className="ml-auto"><EmbedButton path="/embed/space" title="Space — A-Factor STEM Studio" params={{ dim, act: act === 'journey' ? 'journey' : 'locate', pts: (act === 'journey' ? journey[dim] : [locate[dim]]).map(q => `${q.x},${q.y},${q.z}`).join(';') }} /></div>
              </div>
              {dim === '3d' && (
                <div className="flex flex-wrap items-center gap-1.5">
                  <span className="text-xs text-gray-500">View</span>
                  {VIEWS.map(v => <button key={v.label} onClick={() => setView(v.v)} className="rounded-md border border-gray-200 bg-white px-2.5 py-1 text-xs text-gray-600 hover:border-indigo-300 hover:text-indigo-700">{v.label}</button>)}
                  <span className="text-[11px] text-gray-400">Drag empty space to rotate · drag a point to move it · arrow keys and Page Up/Down also work</span>
                </div>
              )}
              {dim !== '3d' && <p className="text-[11px] text-gray-400">Drag a point to move it, or select it and use the arrow keys. Axes run from −{R} to +{R}.</p>}
            </div>

            {/* Parameters + readouts */}
            <div className="space-y-3">
              {act === 'locate' && (
                <>
                  <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Point P</p>
                    <div className="flex gap-2">{fields.map(k => <NumField key={k} label={k} value={p[k]} min={-R} max={R} color={axisColor[k]} onCommit={v => { setLocate(s => ({ ...s, [dim]: { ...s[dim], [k]: v } })); setWalk(undefined); }} />)}</div>
                    {fields.map(k => (
                      <input key={k} type="range" min={-R} max={R} step={snap || 0.1} value={p[k]} aria-label={`${k} slider`} onChange={e => { setLocate(s => ({ ...s, [dim]: { ...s[dim], [k]: Number(e.target.value) } })); setWalk(undefined); }} className="w-full" style={{ accentColor: axisColor[k] }} />
                    ))}
                  </div>
                  <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Where is it?</p>
                    <Stat k="Position" v={coordText(p, dim)} c="text-red-600" />
                    {dim === '1d' && <Stat k="Side of origin" v={p.x === 0 ? 'at O' : p.x > 0 ? 'right (+x)' : 'left (−x)'} />}
                    {dim === '1d' && <Stat k="Distance from O" v={`${fmt(Math.abs(p.x))}`} c="text-indigo-600" />}
                    {dim === '2d' && <><Stat k="Quadrant" v={quadrant(p)} /><Stat k="Distance from O" v={fmt(len(p))} c="text-indigo-600" /><Stat k="Foot on x-axis" v={`(${fmt(p.x)}, 0)`} /><Stat k="Foot on y-axis" v={`(0, ${fmt(p.y)})`} /></>}
                    {dim === '3d' && <><Stat k="Signs" v={octant(p).replace('signs (x, y, z) = ', '')} /><Stat k="Distance from O" v={fmt(len(p))} c="text-indigo-600" /><Stat k="From xy-plane (|z|)" v={fmt(Math.abs(p.z))} /><Stat k="From yz-plane (|x|)" v={fmt(Math.abs(p.x))} /><Stat k="From xz-plane (|y|)" v={fmt(Math.abs(p.y))} /><Stat k="Foot on xy-plane" v={`(${fmt(p.x)}, ${fmt(p.y)}, 0)`} /></>}
                  </div>
                  {dim !== '1d' && (
                    <div className="rounded-2xl border border-indigo-100 bg-indigo-50 p-4">
                      <p className="mb-2 text-xs font-medium uppercase tracking-wide text-indigo-400">Walk to the point</p>
                      <p className="mb-3 min-h-[3.5rem] text-xs leading-relaxed text-indigo-900" aria-live="polite">{walk === undefined ? 'Press Step to follow the route from the origin, one axis at a time.' : walkText(walk, p, dim)}</p>
                      <div className="flex flex-wrap gap-2">
                        <button onClick={() => { setPlaying(false); setWalk(w => (w === undefined ? 1 : w >= walkMax ? 0 : w + 1)); }} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{walk !== undefined && walk >= walkMax ? 'Restart' : 'Step ▸'}</button>
                        <button onClick={() => { setWalk(0); setPlaying(true); }} className="rounded-lg border border-indigo-200 bg-white px-3 py-1.5 text-xs font-medium text-indigo-700">Play</button>
                        <button onClick={() => { setPlaying(false); setWalk(undefined); }} className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs text-gray-600">Show all</button>
                      </div>
                    </div>
                  )}
                </>
              )}

              {act === 'journey' && (
                <>
                  <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Journey points</p><span className="text-[11px] text-gray-400">A → … → {LABELS[journey[dim].length - 1]}</span></div>
                    {journey[dim].map((q, i) => (
                      <div key={i} onClick={() => setSel(i)} className={`rounded-xl border p-2 ${sel === i ? 'border-indigo-300 bg-indigo-50/40' : 'border-gray-100'}`}>
                        <div className="mb-1.5 flex items-center justify-between"><span className="text-xs font-semibold" style={{ color: POINT_COLORS[i % 5] }}>{LABELS[i]}{i === 0 ? ' (start)' : i === journey[dim].length - 1 ? ' (end)' : ''}</span>
                          {journey[dim].length > 2 && <button onClick={e => { e.stopPropagation(); setJourney(s => ({ ...s, [dim]: s[dim].filter((_, k) => k !== i) })); setSel(0); }} className="text-[11px] text-gray-400 hover:text-red-600" aria-label={`Remove point ${LABELS[i]}`}>Remove</button>}</div>
                        <div className="flex gap-1.5">{fields.map(k => <NumField key={k} label={k} value={q[k]} min={-R} max={R} color={axisColor[k]} onCommit={v => setJourney(s => ({ ...s, [dim]: s[dim].map((pp, kk) => (kk === i ? { ...pp, [k]: v } : pp)) }))} />)}</div>
                      </div>
                    ))}
                    <div className="flex flex-wrap gap-2">
                      <button disabled={journey[dim].length >= MAX_POINTS} onClick={() => setJourney(s => { const l = s[dim][s[dim].length - 1]; return { ...s, [dim]: [...s[dim], clampDim(P(clampTo(l.x + 2, R), clampTo(l.y + 1, R), clampTo(l.z + 1, R)), dim)] }; })} className="rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">+ Add point</button>
                    </div>
                    <div className="flex flex-wrap gap-1.5">{JOURNEY_PRESETS[dim].map(pr => <button key={pr.label} onClick={() => { setJourney(s => ({ ...s, [dim]: pr.points })); setSel(0); }} title={pr.note} className="rounded-full border border-gray-200 bg-white px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{pr.label}</button>)}</div>
                  </div>

                  <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Results</p>
                    <Stat k="Distance (path length)" v={`${fmt(J.distance)}`} c="text-indigo-600" />
                    <Stat k="Displacement" v={dim === '1d' ? `${J.displacement.x >= 0 ? '+' : '−'}${fmt(Math.abs(J.displacement.x))}` : coordText(J.displacement, dim).replace('x = ', '')} c="text-rose-600" />
                    <Stat k="|Displacement|" v={fmt(J.magnitude)} c="text-rose-600" />
                    <div className="rounded-lg bg-rose-50 px-3 py-2 text-xs leading-relaxed text-rose-900"><span className="font-medium">Direction: </span>{J.direction.text}{J.direction.bearing !== undefined && <> · bearing {fmt(J.direction.bearing, 1)}°</>}{J.direction.axisAngles && <> · angles with x, y, z axes: {fmt(J.direction.axisAngles.x, 1)}°, {fmt(J.direction.axisAngles.y, 1)}°, {fmt(J.direction.axisAngles.z, 1)}°</>}</div>
                    <div className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${J.straight ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                      {J.straight ? 'Distance equals the magnitude of the displacement: the path is a straight line with no reversal.' : `The path is ${fmt(J.distance - J.magnitude)} longer than the straight-line displacement. Distance ≥ |displacement| always.`}
                    </div>
                  </div>

                  <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                    <p className="mb-2 text-xs font-medium uppercase tracking-wide text-gray-400">Working: {LABELS[0]} → {LABELS[journey[dim].length - 1]}</p>
                    <p className="font-mono text-[11px] leading-relaxed text-gray-700">{distanceWorking(first, last, dim)}</p>
                    <div className="mt-3 overflow-x-auto"><table className="w-full min-w-[220px] text-left text-xs">
                      <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 font-medium">Leg</th><th className="font-medium">Δ</th><th className="text-right font-medium">Length</th></tr></thead>
                      <tbody>{J.legs.map((l, i) => <tr key={i} className="border-t border-gray-100"><td className="py-1.5 font-semibold" style={{ color: POINT_COLORS[(i + 1) % 5] }}>{LABELS[i]}→{LABELS[i + 1]}</td><td className="tabular-nums text-gray-700">{dim === '1d' ? `${l.delta.x >= 0 ? '+' : '−'}${fmt(Math.abs(l.delta.x))}` : coordText(l.delta, dim)}</td><td className="text-right tabular-nums text-gray-900">{fmt(l.length)}</td></tr>)}
                        <tr className="border-t-2 border-gray-200 font-semibold"><td className="py-1.5">Total</td><td /><td className="text-right tabular-nums text-indigo-600">{fmt(J.distance)}</td></tr></tbody>
                    </table></div>
                  </div>
                </>
              )}

              {act === 'practice' && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Practice</p><span className="rounded-full bg-gray-100 px-2.5 py-1 text-[11px] font-medium text-gray-600">Score {score.right} / {score.tries}</span></div>
                  <div className="flex gap-1.5">
                    {([['place', 'Place the point'], ['read', 'Read the coordinates']] as const).map(([k, l]) => <button key={k} onClick={() => newChallenge(k)} aria-pressed={pKind === k} className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium ${pKind === k ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600'}`}>{l}</button>)}
                  </div>
                  {target && pKind === 'place' && <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-900">Move point P to <span className="font-semibold">{coordText(target, dim)}</span>, then press Check.</p>}
                  {target && pKind === 'read' && (
                    <div className="space-y-2">
                      <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm text-indigo-900">Read the coordinates of the red point P from the axes, then type them in.</p>
                      <div className="flex gap-2">{fields.map(k => <label key={k} className="flex flex-1 items-center gap-1.5 text-xs"><span className="font-semibold" style={{ color: axisColor[k] }}>{k}</span><input type="number" inputMode="decimal" value={typed[k]} aria-label={`Your ${k} value`} onChange={e => { setTyped(t => ({ ...t, [k]: e.target.value })); setResult(null); }} className="h-8 w-full min-w-0 rounded-md border border-gray-200 px-2 text-sm" /></label>)}</div>
                    </div>
                  )}
                  {pKind === 'place' && <p className="text-xs text-gray-500">P is now at <span className="font-medium text-gray-800">{coordText(place[dim], dim)}</span></p>}
                  <div className="flex gap-2">
                    <button onClick={check} disabled={!target} className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white enabled:hover:bg-indigo-700 disabled:opacity-40">Check</button>
                    <button onClick={() => newChallenge()} className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-xs text-gray-700 hover:border-indigo-300">New point</button>
                    {pKind === 'read' && <button onClick={() => setResult({ correct: false, hints: [`The answer is ${target ? coordText(target, dim) : ''}.`] })} className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">Reveal</button>}
                  </div>
                  {result && <p aria-live="polite" className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${result.correct ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>{result.correct ? '✓ Correct! That is exactly the point.' : result.hints.join(' · ')}</p>}
                  {pKind === 'read' && dim === '3d' && <p className="text-[11px] text-gray-400">Tip: rotate the view and switch to the Top, Front and Side views to read each coordinate against its axis.</p>}
                </div>
              )}
            </div>

            {/* Teacher notes + exercises */}
            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-amber-700">📋 Teacher notes</p>
                <ul className="space-y-2">{NOTES[dim].map((n, i) => <li key={i} className="flex gap-2 text-xs leading-relaxed text-amber-900"><span className="mt-0.5 shrink-0 text-amber-400">•</span>{n}</li>)}</ul>
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-500">✏️ Exercises</p>
                <div className="space-y-2">{EXERCISES[dim].map((ex, i) => (
                  <div key={i} className="overflow-hidden rounded-xl border border-gray-100">
                    <button onClick={() => setOpenEx(openEx === i ? null : i)} aria-expanded={openEx === i} className="flex w-full justify-between gap-2 px-3 py-2.5 text-left text-xs leading-relaxed text-gray-700 transition hover:bg-gray-50"><span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span><span className="shrink-0 text-sm text-gray-300">{openEx === i ? '▲' : '▼'}</span></button>
                    {openEx === i && <div className="border-t border-gray-100 bg-emerald-50 px-3 py-2.5 text-xs leading-relaxed text-emerald-800"><span className="font-medium">Answer: </span>{ex.a}</div>}
                  </div>))}</div>
              </div>
              <div className="rounded-2xl border border-gray-100 bg-white p-4"><p className="mb-2 text-xs text-gray-400">Curriculum</p><div className="flex flex-wrap gap-1.5">{CURRICULA.map(c => <span key={c} className={`rounded-full px-2 py-0.5 text-xs font-medium ${curr.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'}`}>{c}</span>)}</div></div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
FILEEOF

write_file src/app/embed/space/page.tsx << 'FILEEOF'
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
FILEEOF

# -- Register the sim on the simulations page (idempotent) --------------------
node - << 'NODEEOF'
const fs = require('fs');
const p = 'src/app/simulations/page.tsx';
let s = fs.readFileSync(p, 'utf8');
const nl = s.includes('\r\n') ? '\r\n' : '\n';
let changed = false;
if (!/slug:\s*'space'/.test(s)) {
  const m = s.match(/const SIMULATIONS\s*=\s*\[\r?\n/);
  if (!m) { console.error('ERROR: could not find "const SIMULATIONS = [" in simulations/page.tsx. Add the Space card by hand.'); process.exit(1); }
  const entry = [
    "  {", "    slug: 'space',", "    href: '/simulations/space',", "    title: 'Space: position, distance & displacement',",
    "    description: 'Locate points on a line, a plane and in 3D space, then measure distance and displacement. Walk-through, journeys and practice included.',",
    "    icon: '🧊',", "    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],", "    topic: 'Space and time',", "    status: 'live',", "  },"].join(nl) + nl;
  s = s.slice(0, m.index + m[0].length) + entry + s.slice(m.index + m[0].length);
  changed = true; console.log('  added the Space card to SIMULATIONS');
} else console.log('  Space card already registered');
if (!/'Space and time'/.test(s.split('const SIMULATIONS')[0] || '') && !/const TOPICS[^\n]*'Space and time'/.test(s)) {
  const t = s.match(/const TOPICS\s*=\s*\[\s*'All'\s*,/);
  if (t) { s = s.replace(t[0], t[0] + " 'Space and time',"); changed = true; console.log("  added the 'Space and time' topic filter"); }
  else console.log("  NOTE: could not find the TOPICS list; add 'Space and time' to it by hand to get a filter chip.");
} else console.log("  topic filter already includes 'Space and time'");
if (changed) fs.writeFileSync(p, s);
NODEEOF

echo ""
echo "Done. npm run dev, then open /simulations/space"
