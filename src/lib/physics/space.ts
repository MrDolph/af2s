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
