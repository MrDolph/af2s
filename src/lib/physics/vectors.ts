// Vector sim: operations, worked-out explanations, scene geometry and practice problems.
//
// Everything the page shows (numbers, working, directions) comes from here, so it can be tested
// against hand calculations. Vectors are P3 values; in 2D the z component is always 0.
// Conventions: right-handed axes (X × Y = Z); angles are measured counter-clockwise from +x.

import { type Dim, type P3, P, clampDim, describeDirection, fmt, len } from './space';

export type VMode = 'components' | 'add' | 'scalar' | 'dot' | 'cross' | 'practice';
export type Context = 'generic' | 'force' | 'displacement' | 'velocity';

export const CONTEXTS: Record<Context, { label: string; unit: string; resultant: string; noun: string }> = {
  generic: { label: 'Plain vectors', unit: '', resultant: 'Resultant', noun: 'vector' },
  force: { label: 'Forces', unit: 'N', resultant: 'Net force', noun: 'force' },
  displacement: { label: 'Displacements', unit: 'm', resultant: 'Net displacement', noun: 'displacement' },
  velocity: { label: 'Velocities', unit: 'm/s', resultant: 'Resultant velocity', noun: 'velocity' },
};
export const withUnit = (text: string, ctx: Context) => (CONTEXTS[ctx].unit ? `${text} ${CONTEXTS[ctx].unit}` : text);

// ── Operations ───────────────────────────────────────────────────────────────
const EPS = 1e-9;
export const add = (a: P3, b: P3): P3 => P(a.x + b.x, a.y + b.y, a.z + b.z);
export const minus = (a: P3, b: P3): P3 => P(a.x - b.x, a.y - b.y, a.z - b.z);
export const scale = (a: P3, k: number): P3 => P(a.x * k, a.y * k, a.z * k);
export const dot = (a: P3, b: P3) => a.x * b.x + a.y * b.y + a.z * b.z;
export const cross = (a: P3, b: P3): P3 => P(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
export const mag = len;
export const isZero = (a: P3) => len(a) < EPS;
export const unit = (a: P3): P3 | null => (isZero(a) ? null : scale(a, 1 / len(a)));
export const neg = (a: P3) => scale(a, -1);
export const sum = (list: P3[]) => list.reduce((s, v) => add(s, v), P());

/** Angle between two vectors in degrees, or null if either is the zero vector. */
export function angleBetween(a: P3, b: P3): number | null {
  if (isZero(a) || isZero(b)) return null;
  return (Math.acos(Math.max(-1, Math.min(1, dot(a, b) / (len(a) * len(b))))) * 180) / Math.PI;
}
/** Scalar projection of a onto b (the signed length of a's shadow along b). */
export const projScalar = (a: P3, b: P3): number | null => (isZero(b) ? null : dot(a, b) / len(b));
export const projVector = (a: P3, b: P3): P3 | null => (isZero(b) ? null : scale(b, dot(a, b) / dot(b, b)));
export const nearlyZero = (x: number, tol = 1e-9) => Math.abs(x) < tol;

/** Polar form (2D): magnitude and angle from +x in [0, 360). */
export const toPolar = (v: P3) => ({ r: len(v), theta: ((Math.atan2(v.y, v.x) * 180) / Math.PI + 360) % 360 });
export const fromPolar = (r: number, thetaDeg: number): P3 => P(r * Math.cos((thetaDeg * Math.PI) / 180), r * Math.sin((thetaDeg * Math.PI) / 180), 0);

// ── Formatting ───────────────────────────────────────────────────────────────
export const compText = (v: P3, dim: Dim, d = 2) => (dim === '2d' ? `(${fmt(v.x, d)}, ${fmt(v.y, d)})` : `(${fmt(v.x, d)}, ${fmt(v.y, d)}, ${fmt(v.z, d)})`);
const sgn = (n: number, d = 2) => (n < 0 ? `(${fmt(n, d)})` : fmt(n, d));
const term = (n: number, sym: string, first: boolean, d = 2) => {
  if (nearlyZero(n, 5e-3)) return '';
  const a = Math.abs(n), body = a === 1 ? sym : `${fmt(a, d)}${sym}`;
  return first ? `${n < 0 ? '−' : ''}${body}` : ` ${n < 0 ? '−' : '+'} ${body}`;
};
/** Unit-vector form, e.g. "3i + 4j" or "i − 2j + 6k". */
export function ijk(v: P3, dim: Dim, d = 2): string {
  const parts = [term(v.x, 'i', true, d)];
  parts.push(term(v.y, 'j', !parts[0], d)); if (dim === '3d') parts.push(term(v.z, 'k', !parts.join(''), d));
  const s = parts.join('');
  return s || '0';
}

// ── Worked explanations (plain strings, shown as "working") ──────────────────
const axes = (dim: Dim): ('x' | 'y' | 'z')[] => (dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z']);

export function workMagnitude(v: P3, dim: Dim, name = 'A'): string {
  const parts = axes(dim).map(k => `${sgn(v[k])}²`).join(' + ');
  return `|${name}| = √(${parts}) = ${fmt(len(v))}`;
}
export function workComponentsFromPolar(r: number, thetaDeg: number): string[] {
  const v = fromPolar(r, thetaDeg);
  return [`Ax = |A| cosθ = ${fmt(r)} × cos ${fmt(thetaDeg, 1)}° = ${fmt(v.x)}`, `Ay = |A| sinθ = ${fmt(r)} × sin ${fmt(thetaDeg, 1)}° = ${fmt(v.y)}`];
}
export function workDirection(v: P3): string {
  if (isZero(v)) return 'The zero vector has no direction.';
  const t = toPolar(v).theta;
  if (nearlyZero(v.x)) return `Ax = 0, so the vector points along the y-axis: θ = ${fmt(t, 1)}°.`;
  const base = (Math.atan(Math.abs(v.y) / Math.abs(v.x)) * 180) / Math.PI;
  const quad = v.x > 0 && v.y >= 0 ? 'quadrant I' : v.x < 0 && v.y >= 0 ? 'quadrant II' : v.x < 0 ? 'quadrant III' : 'quadrant IV';
  return `Reference angle α = tan⁻¹(|Ay| / |Ax|) = tan⁻¹(${fmt(Math.abs(v.y))} / ${fmt(Math.abs(v.x))}) = ${fmt(base, 1)}°. The vector is in ${quad}, so θ = ${fmt(t, 1)}° from +x.`;
}
export function workAdd(a: P3, b: P3, dim: Dim, op: '+' | '−' = '+', na = 'A', nb = 'B', nr = 'R'): string[] {
  const out: string[] = [];
  for (const k of axes(dim)) {
    out.push(`${nr}${k} = ${na}${k} ${op} ${nb}${k} = ${sgn(a[k])} ${op} ${sgn(b[k])} = ${fmt(op === '+' ? a[k] + b[k] : a[k] - b[k])}`);
  }
  return out;
}
export function workScalar(a: P3, k: number, dim: Dim): string[] {
  return axes(dim).map(c => `(kA)${c} = k × A${c} = ${sgn(k)} × ${sgn(a[c])} = ${fmt(k * a[c])}`);
}
export function workDot(a: P3, b: P3, dim: Dim): string[] {
  const parts = axes(dim).map(k => `(${fmt(a[k])})(${fmt(b[k])})`).join(' + ');
  const lines = [`A·B = AxBx + AyBy${dim === '3d' ? ' + AzBz' : ''} = ${parts} = ${fmt(dot(a, b))}`];
  const ang = angleBetween(a, b);
  if (ang === null) lines.push('The angle is undefined because one vector is the zero vector.');
  else lines.push(`cosθ = A·B / (|A||B|) = ${fmt(dot(a, b))} / (${fmt(len(a))} × ${fmt(len(b))}) = ${fmt(dot(a, b) / (len(a) * len(b)), 3)}, so θ = ${fmt(ang, 1)}°`);
  return lines;
}
export function workCross(a: P3, b: P3): string[] {
  const c = cross(a, b);
  return [
    `(A×B)x = AyBz − AzBy = (${fmt(a.y)})(${fmt(b.z)}) − (${fmt(a.z)})(${fmt(b.y)}) = ${fmt(c.x)}`,
    `(A×B)y = AzBx − AxBz = (${fmt(a.z)})(${fmt(b.x)}) − (${fmt(a.x)})(${fmt(b.z)}) = ${fmt(c.y)}`,
    `(A×B)z = AxBy − AyBx = (${fmt(a.x)})(${fmt(b.y)}) − (${fmt(a.y)})(${fmt(b.x)}) = ${fmt(c.z)}`,
  ];
}

// ── Scene geometry (what to draw), kept separate from the canvas ─────────────
export interface Arrow { from: P3; to: P3; color: string; width?: number; dash?: number[]; label?: string; labelAt?: number; faint?: boolean }
export interface Poly { pts: P3[]; fill: string; stroke?: string }
export interface Arc { at: P3; a: P3; b: P3; r: number; color: string; label?: string }
export interface Handle { id: 'A' | 'B' | 'C'; at: P3; /** the vector value is `(at − base) × mul` */ base: P3; mul?: number; color: string }
export interface Mark { at: P3; text: string; color: string; size?: number }
export interface Scene { arrows: Arrow[]; polys: Poly[]; arcs: Arc[]; handles: Handle[]; marks: Mark[] }

export const COL = { A: '#4f46e5', B: '#059669', C: '#d97706', R: '#e11d48', helper: '#9ca3af', x: '#dc2626', y: '#16a34a', z: '#2563eb', proj: '#0891b2', cross: '#7c3aed' };
const O = P();

export type Method = 'triangle' | 'parallelogram' | 'both';
export type Op = 'A+B' | 'A−B' | 'B−A';

export interface VState { A: P3; B: P3; C: P3; k: number; op: Op; method: Method; useC: boolean; showComponents: boolean; showUnit: boolean; showAngle: boolean }

export function sceneFor(mode: VMode, dim: Dim, s: VState, ctx: Context = 'generic'): Scene {
  const sc: Scene = { arrows: [], polys: [], arcs: [], handles: [], marks: [] };
  const A = clampDim(s.A, dim), B = clampDim(s.B, dim), C = clampDim(s.C, dim);
  const u = CONTEXTS[ctx].unit;
  const tag = (name: string, v: P3) => `${name}${u ? ` (${fmt(len(v), 1)} ${u})` : ''}`;

  if (mode === 'components') {
    sc.arrows.push({ from: O, to: A, color: COL.A, width: 3.4, label: tag('A', A), labelAt: 0.55 });
    sc.handles.push({ id: 'A', at: A, base: O, color: COL.A });
    if (s.showComponents) {
      const px = P(A.x, 0, 0), pxy = P(A.x, A.y, 0);
      sc.arrows.push({ from: O, to: px, color: COL.x, dash: [6, 4], width: 2, label: `Ax = ${fmt(A.x)}`, labelAt: 0.5 });
      sc.arrows.push({ from: px, to: pxy, color: COL.y, dash: [6, 4], width: 2, label: `Ay = ${fmt(A.y)}`, labelAt: 0.5 });
      if (dim === '3d') sc.arrows.push({ from: pxy, to: A, color: COL.z, dash: [6, 4], width: 2, label: `Az = ${fmt(A.z)}`, labelAt: 0.5 });
    }
    if (s.showUnit && !isZero(A)) sc.arrows.push({ from: O, to: unit(A)!, color: COL.cross, width: 3, label: 'Â', labelAt: 1 });
    if (dim === '2d' && s.showAngle && !isZero(A)) sc.arcs.push({ at: O, a: P(1, 0, 0), b: A, r: 1.2, color: COL.R, label: `θ = ${fmt(toPolar(A).theta, 1)}°` });
  }

  if (mode === 'add') {
    const sign: 1 | -1 = s.op === 'A+B' ? 1 : -1;
    const first = s.op === 'B−A' ? B : A, second = s.op === 'B−A' ? A : B;
    const nf = s.op === 'B−A' ? 'B' : 'A', ns = s.op === 'B−A' ? 'A' : 'B';
    const term2 = scale(second, sign);
    const R = add(first, term2);
    const tri = s.method !== 'parallelogram', par = s.method !== 'triangle';
    // The vectors you can drag, shown from the origin unless the triangle method re-draws the second tip-to-tail.
    sc.arrows.push({ from: O, to: first, color: nf === 'A' ? COL.A : COL.B, width: 3.2, label: tag(nf, first), labelAt: 0.5 });
    if (tri) {
      if (sign === -1) {
        sc.arrows.push({ from: O, to: second, color: ns === 'A' ? COL.A : COL.B, width: 2, dash: [3, 4], faint: true, label: tag(ns, second), labelAt: 0.5 });
        sc.arrows.push({ from: first, to: R, color: ns === 'A' ? COL.A : COL.B, width: 3.2, label: `−${ns}`, labelAt: 0.5 });
      } else sc.arrows.push({ from: first, to: R, color: ns === 'A' ? COL.A : COL.B, width: 3.2, label: tag(ns, second), labelAt: 0.5 });
    }
    if (par && !tri) {
      sc.arrows.push({ from: O, to: term2, color: ns === 'A' ? COL.A : COL.B, width: 3.2, label: sign === -1 ? `−${ns}` : tag(ns, second), labelAt: 0.5 });
    }
    if (par) {
      sc.polys.push({ pts: [O, first, R, term2], fill: 'rgba(79,70,229,0.08)' });
      sc.arrows.push({ from: first, to: R, color: COL.helper, dash: [5, 4], width: 1.5 });
      sc.arrows.push({ from: term2, to: R, color: COL.helper, dash: [5, 4], width: 1.5 });
      if (sign === -1 && !tri) sc.arrows.push({ from: O, to: second, color: ns === 'A' ? COL.A : COL.B, width: 2, dash: [3, 4], faint: true });
    }
    sc.arrows.push({ from: O, to: R, color: COL.R, width: 3.8, label: `R${u ? ` (${fmt(len(R), 1)} ${u})` : ''}`, labelAt: 0.6 });
    if (sign === -1) sc.arrows.push({ from: second, to: first, color: COL.helper, dash: [2, 4], width: 1.6, label: `${nf} − ${ns}` });
    // Handles. The first vector is dragged by its tip. The second is dragged by the tip you can see:
    // tip-to-tail (triangle) → the resultant's tip, measured from the first vector's tip; otherwise from the origin.
    const aIsFirst = nf === 'A';
    sc.handles.push({ id: aIsFirst ? 'A' : 'B', at: first, base: O, color: aIsFirst ? COL.A : COL.B });
    sc.handles.push({ id: aIsFirst ? 'B' : 'A', at: tri ? R : term2, base: tri ? first : O, mul: sign, color: aIsFirst ? COL.B : COL.A });
    if (s.useC) {
      const R3 = add(R, C);
      sc.arrows.push({ from: R, to: R3, color: COL.C, width: 3.2, label: tag('C', C), labelAt: 0.5 });
      sc.arrows.push({ from: O, to: R3, color: COL.R, width: 3.8, label: 'R (A+B+C)', labelAt: 0.7 });
      sc.handles.push({ id: 'C', at: R3, base: R, color: COL.C });
    }
    if (s.showAngle && !isZero(A) && !isZero(B)) sc.arcs.push({ at: O, a: A, b: B, r: Math.min(len(A), len(B)) * 0.3 + 0.4, color: COL.helper, label: `${fmt(angleBetween(A, B) ?? 0, 1)}°` });
  }

  if (mode === 'scalar') {
    const kA = scale(A, s.k);
    sc.arrows.push({ from: O, to: A, color: COL.A, width: 3, faint: true, label: tag('A', A), labelAt: 0.5 });
    if (!isZero(kA)) sc.arrows.push({ from: O, to: kA, color: COL.R, width: 4, label: `${fmt(s.k)}A`, labelAt: 1 });
    sc.handles.push({ id: 'A', at: A, base: O, color: COL.A });
    if (s.showUnit && !isZero(A)) sc.arrows.push({ from: O, to: unit(A)!, color: COL.cross, width: 3, label: 'Â', labelAt: 1 });
  }

  if (mode === 'dot') {
    const pv = projVector(A, B);
    // The projection is drawn first, as a wide translucent band under the vectors, so B stays visible on top of it.
    if (pv && !isZero(A)) {
      sc.arrows.push({ from: O, to: pv, color: COL.proj, width: 9, faint: true, label: 'proj', labelAt: 0.4 });
      sc.arrows.push({ from: A, to: pv, color: COL.helper, dash: [5, 4], width: 1.6 });
    }
    sc.arrows.push({ from: O, to: A, color: COL.A, width: 3.2, label: tag('A', A), labelAt: 0.8 });
    sc.arrows.push({ from: O, to: B, color: COL.B, width: 3.2, label: tag('B', B), labelAt: 0.8 });
    sc.handles.push({ id: 'A', at: A, base: O, color: COL.A }, { id: 'B', at: B, base: O, color: COL.B });
    if (s.showAngle && angleBetween(A, B) !== null) sc.arcs.push({ at: O, a: A, b: B, r: Math.min(len(A), len(B)) * 0.28 + 0.4, color: COL.R, label: `θ = ${fmt(angleBetween(A, B)!, 1)}°` });
  }

  if (mode === 'cross') {
    const X = cross(A, B);
    sc.polys.push({ pts: [O, A, add(A, B), B], fill: 'rgba(124,58,237,0.14)', stroke: 'rgba(124,58,237,0.5)' });
    sc.arrows.push({ from: O, to: A, color: COL.A, width: 3.2, label: tag('A', A), labelAt: 0.6 });
    sc.arrows.push({ from: O, to: B, color: COL.B, width: 3.2, label: tag('B', B), labelAt: 0.6 });
    sc.handles.push({ id: 'A', at: A, base: O, color: COL.A }, { id: 'B', at: B, base: O, color: COL.B });
    if (dim === '3d' && !isZero(X)) {
      // |A × B| can be far larger than A and B (it is an area). Draw it no longer than the longer input so the
      // diagram stays readable, and say so on the label; the true size is in the results panel.
      const cap = Math.max(len(A), len(B), 1) * 1.15, scaled = len(X) > cap;
      sc.arrows.push({ from: O, to: scaled ? scale(unit(X)!, cap) : X, color: COL.cross, width: 4, label: scaled ? 'A × B (direction only)' : 'A × B', labelAt: 0.85 });
    }
    if (s.showAngle && angleBetween(A, B) !== null) sc.arcs.push({ at: O, a: A, b: B, r: Math.min(len(A), len(B)) * 0.28 + 0.4, color: COL.R, label: `θ = ${fmt(angleBetween(A, B)!, 1)}°` });
  }
  return sc;
}

/** Every point the scene touches, so the canvas can choose a sensible scale. */
export function scenePoints(sc: Scene): P3[] {
  return [...sc.arrows.flatMap(a => [a.from, a.to]), ...sc.polys.flatMap(p => p.pts), ...sc.handles.map(h => h.at)];
}

// ── Practice ─────────────────────────────────────────────────────────────────
export type PracticeKind = 'resultant' | 'difference' | 'magnitude' | 'direction' | 'scalar' | 'dot' | 'angle' | 'cross' | 'projection';
export interface Problem { kind: PracticeKind; dim: Dim; A: P3; B: P3; k: number; prompt: string; inputs: string[]; answer: number[]; tol: number; unit?: string; explain: string }

const ri = (rand: () => number, lo: number, hi: number) => Math.round(lo + rand() * (hi - lo));
const TRIPLES: [number, number, number][] = [[3, 4, 5], [5, 12, 13], [8, 6, 10], [6, 8, 10]];

export const PRACTICE_KINDS: Record<'2d' | '3d', PracticeKind[]> = {
  '2d': ['resultant', 'difference', 'magnitude', 'direction', 'scalar', 'dot', 'angle', 'projection'],
  '3d': ['resultant', 'difference', 'magnitude', 'scalar', 'dot', 'cross'],
};

export function makeProblem(kind: PracticeKind, dim: Dim, rand: () => number = Math.random): Problem {
  const nz = (lo: number, hi: number) => { let v = 0; while (v === 0) v = ri(rand, lo, hi); return v; };
  const rv = (): P3 => clampDim(P(nz(-6, 6), nz(-6, 6), dim === '3d' ? nz(-4, 4) : 0), dim);
  const names = dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  let A = rv();
  const B = rv(), k = nz(-3, 3);
  const base = { dim, A, B, k };
  if (kind === 'resultant' || kind === 'difference') {
    const R = kind === 'resultant' ? add(A, B) : minus(A, B);
    return { ...base, kind, prompt: `Given A = ${compText(A, dim, 0)} and B = ${compText(B, dim, 0)}, find ${kind === 'resultant' ? 'A + B' : 'A − B'} (give each component).`, inputs: names.map(n => `${n} component`), answer: names.map(n => R[n as 'x' | 'y' | 'z']), tol: 0.01, explain: workAdd(A, B, dim, kind === 'resultant' ? '+' : '−').join('; ') };
  }
  if (kind === 'magnitude') {
    if (dim === '2d') { const t = TRIPLES[ri(rand, 0, TRIPLES.length - 1)]; A = P(rand() < 0.5 ? -t[0] : t[0], rand() < 0.5 ? -t[1] : t[1], 0); }
    return { ...base, A, kind, prompt: `Find the magnitude |A| of A = ${compText(A, dim, 0)}${dim === '3d' ? ' (2 decimal places)' : ''}.`, inputs: ['|A|'], answer: [len(A)], tol: 0.011, explain: workMagnitude(A, dim) };
  }
  if (kind === 'direction') {
    const t = toPolar(A).theta;
    return { ...base, kind, prompt: `Find the direction θ of A = ${compText(A, dim, 0)}, measured counter-clockwise from +x (degrees, 1 decimal place).`, inputs: ['θ (°)'], answer: [t], tol: 0.15, explain: workDirection(A) };
  }
  if (kind === 'scalar') {
    const R = scale(A, k);
    return { ...base, kind, prompt: `Given A = ${compText(A, dim, 0)} and k = ${k}, find kA.`, inputs: names.map(n => `${n} component`), answer: names.map(n => R[n as 'x' | 'y' | 'z']), tol: 0.01, explain: workScalar(A, k, dim).join('; ') };
  }
  if (kind === 'dot') return { ...base, kind, prompt: `Find A·B for A = ${compText(A, dim, 0)} and B = ${compText(B, dim, 0)}.`, inputs: ['A·B'], answer: [dot(A, B)], tol: 0.01, explain: workDot(A, B, dim)[0] };
  if (kind === 'angle') {
    const ang = angleBetween(A, B) ?? 0;
    return { ...base, kind, prompt: `Find the angle between A = ${compText(A, dim, 0)} and B = ${compText(B, dim, 0)} (degrees, 1 decimal place).`, inputs: ['θ (°)'], answer: [ang], tol: 0.15, explain: workDot(A, B, dim).join('; ') };
  }
  if (kind === 'projection') {
    const pr = projScalar(A, B) ?? 0;
    return { ...base, kind, prompt: `Find the scalar projection of A = ${compText(A, dim, 0)} onto B = ${compText(B, dim, 0)} (2 decimal places).`, inputs: ['A·B̂'], answer: [pr], tol: 0.011, explain: `A·B / |B| = ${fmt(dot(A, B))} / ${fmt(len(B))} = ${fmt(pr)}` };
  }
  // cross (3D)
  const X = cross(A, B);
  return { ...base, kind: 'cross', prompt: `Find A × B for A = ${compText(A, dim, 0)} and B = ${compText(B, dim, 0)}.`, inputs: names.map(n => `${n} component`), answer: names.map(n => X[n as 'x' | 'y' | 'z']), tol: 0.01, explain: workCross(A, B).join('; ') };
}

/** A random problem of the chosen kind ('mixed' picks any kind that exists for the dimension). */
export function randomProblem(kind: PracticeKind | 'mixed', dim: '2d' | '3d', rand: () => number = Math.random): Problem {
  const pool = PRACTICE_KINDS[dim];
  const chosen = kind === 'mixed' || !pool.includes(kind) ? pool[Math.floor(rand() * pool.length)] : kind;
  return makeProblem(chosen, dim, rand);
}

export function checkProblem(p: Problem, given: number[]): { correct: boolean; wrong: number[] } {
  const wrong: number[] = [];
  p.answer.forEach((a, i) => { if (!Number.isFinite(given[i]) || Math.abs(given[i] - a) > p.tol) wrong.push(i); });
  return { correct: wrong.length === 0, wrong };
}
export const describeResultant = (v: P3, dim: Dim) => describeDirection(v, dim);
