#!/bin/bash
# A-Factor STEM Studio — Physics: "Vectors" simulation (v86), in the "Space and time" topic next to the Space sim
# Run inside af2s/ (the project ROOT), AFTER patch-v83-space-sim.sh (it reuses that sim's 3D camera and helpers):
#     bash patches/patch-v86-vectors-sim.sh
#
# ADDS   /simulations/vectors   Vectors: components, addition & products   (2D and 3D)
#   - COMPONENTS: drag a vector's tip or type it (components, or magnitude + angle in 2D); components drawn as a right
#     triangle (3D: a box); magnitude, direction (angle, compass, bearing; 3D axis angles), unit vector and i-j-k form
#   - ADD & SUBTRACT: A + B, A - B, B - A by the tip-to-tail triangle, the parallelogram, or both; an optional third
#     vector C (polygon rule) with a "Balance with C" button that shows equilibrium; commutativity check
#   - SCALAR MULTIPLE: kA with a slider (reversal for k < 0, zero vector at k = 0), parallel vectors, unit vector
#   - DOT PRODUCT: A.B, angle, scalar and vector projection (drawn as a band under B), perpendicular test, work example
#   - CROSS PRODUCT: A x B with the parallelogram area, right-hand rule, perpendicularity check (3D); in 2D it points along z
#   - PRACTICE: random problems (resultant, difference, magnitude, direction, scalar multiple, dot, angle, projection,
#     cross) in 2D and 3D, checked with a sensible rounding tolerance, with Reveal and worked steps and a score
#   - "Working" panel with the exact calculation for the numbers on screen; "Think of the vectors as" forces (N),
#     displacements (m) or velocities (m/s) to link the maths to physics
#   - Teacher notes and worked exercises (with answers) for every mode; mobile friendly; /embed/vectors
# EDITS  src/app/simulations/page.tsx: adds the sim card to the "Space and time" topic (idempotent, line endings kept)
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -f src/app/simulations/page.tsx ]; then echo "ERROR: run from the project root (package.json + src/app/simulations/page.tsx)."; exit 1; fi
if [ ! -f src/lib/physics/space.ts ]; then echo "ERROR: src/lib/physics/space.ts not found - apply patch-v83-space-sim.sh first (the Vectors sim reuses it)."; exit 1; fi
for f in src/hooks/useResponsiveCanvasSize.ts src/components/ui/EmbedButton.tsx; do
  if [ ! -f "$f" ]; then echo "ERROR: $f not found - this patch expects the existing simulation helpers."; exit 1; fi
done
if ! command -v node >/dev/null 2>&1; then echo "ERROR: 'node' not found on PATH."; exit 1; fi

echo "Applying Vectors simulation (v86)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/physics/vectors.ts << 'FILEEOF'
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
FILEEOF

write_file src/components/simulation/VectorCanvas.tsx << 'FILEEOF'
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
FILEEOF

write_file src/app/simulations/vectors/page.tsx << 'FILEEOF'
'use client';
import { useRef, useState } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { VectorCanvas } from '@/components/simulation/VectorCanvas';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { type P3, type View, DEFAULT_VIEW, P, clampTo, describeDirection, fmt } from '@/lib/physics/space';
import {
  type Context, type Method, type Op, type PracticeKind, type Problem, type Scene, type VMode, type VState, CONTEXTS, COL, PRACTICE_KINDS,
  add, angleBetween, checkProblem, compText, cross, dot, fromPolar, ijk, isZero, mag, minus, neg, projScalar, projVector, scale, sceneFor, sum, toPolar,
  randomProblem, unit, withUnit, workAdd, workComponentsFromPolar, workCross, workDirection, workDot, workMagnitude, workScalar,
} from '@/lib/physics/vectors';

type D = '2d' | '3d';
const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = { WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700', IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700', JUPEB: 'bg-purple-100 text-purple-700' };
const MODES: { id: VMode; title: string }[] = [
  { id: 'components', title: 'Components' }, { id: 'add', title: 'Add & subtract' }, { id: 'scalar', title: 'Scalar multiple' },
  { id: 'dot', title: 'Dot product' }, { id: 'cross', title: 'Cross product' }, { id: 'practice', title: '🎯 Practice' },
];
const KIND_LABEL: Record<PracticeKind, string> = { resultant: 'A + B', difference: 'A − B', magnitude: 'Magnitude', direction: 'Direction', scalar: 'Scalar multiple', dot: 'Dot product', angle: 'Angle between', cross: 'Cross product', projection: 'Projection' };

const NOTES: Record<VMode, string[]> = {
  components: [
    'A vector has a magnitude (size) and a direction. Its components are its shadows on the axes: Ax = |A| cos θ and Ay = |A| sin θ.',
    'From components back to the vector: |A| = √(Ax² + Ay² [+ Az²]). The direction is θ = tan⁻¹(Ay/Ax), but always check the quadrant from the signs of Ax and Ay.',
    'The unit vector Â = A/|A| has magnitude 1 and carries only the direction, so A = |A| Â. The unit vectors along the axes are i, j and k.',
    'A free vector is defined by magnitude and direction only: it is the same vector wherever you draw it.',
  ],
  add: [
    'Triangle (tip-to-tail): draw B starting at the tip of A. The resultant goes from the tail of A to the tip of B. Parallelogram: draw both from the same point; the resultant is the diagonal from that point.',
    'In components: R = (Ax + Bx, Ay + By). Subtraction is addition of the reverse: A − B = A + (−B), and A − B is the vector from the tip of B to the tip of A.',
    'Order does not matter (A + B = B + A) and neither does grouping. If vectors drawn tip-to-tail close into a polygon, the resultant is zero: for forces, that means equilibrium.',
    '|A + B| is never more than |A| + |B|; they are equal only when A and B point the same way.',
  ],
  scalar: [
    'Multiplying by a scalar k multiplies every component: kA = (kAx, kAy). The magnitude becomes |k||A|.',
    'If k > 0 the direction is unchanged; if k < 0 the vector reverses; if k = 0 you get the zero vector.',
    'Two vectors are parallel exactly when one is a scalar multiple of the other. The unit vector is (1/|A|)A.',
    'Distributive laws: k(A + B) = kA + kB and (k + m)A = kA + mA.',
  ],
  dot: [
    'The dot (scalar) product A·B = AxBx + AyBy [+ AzBz] = |A||B| cos θ is a number, not a vector.',
    'Its sign tells you about the angle: positive means acute, zero means perpendicular, negative means obtuse. A·B = 0 is the test for perpendicular vectors.',
    'The component of A along B is A·B/|B| (the scalar projection). Physics uses: work W = F·d and power P = F·v.',
    'A·B = B·A, and A·A = |A|².',
  ],
  cross: [
    'The cross (vector) product A × B is a vector perpendicular to both A and B. Its magnitude |A||B| sin θ equals the area of the parallelogram they span.',
    'Direction: right-hand rule. Point your fingers along A, curl them towards B, and your thumb gives A × B.',
    'It is not commutative: B × A = −(A × B). Parallel vectors have a zero cross product.',
    'Used for torque τ = r × F, the magnetic force F = q v × B and angular momentum L = r × p.',
  ],
  practice: [
    'Work out the answer on paper first, then type it in. Use the "working" shown after Reveal to find where a step went wrong.',
    'Check signs: most mistakes in vector problems are sign errors in negative components.',
    'Magnitudes and angles are marked correct within a small rounding tolerance (0.01 for lengths, 0.15° for angles).',
  ],
};
const EXERCISES: Record<VMode, { q: string; a: string }[]> = {
  components: [
    { q: 'A force of 50 N acts at 36.9° above the +x axis. Find its components.', a: 'Fx = 50 cos 36.9° ≈ 40 N and Fy = 50 sin 36.9° ≈ 30 N.' },
    { q: 'A = (−6, 8). Find |A| and its direction measured from +x.', a: '|A| = √(36 + 64) = 10. The reference angle is tan⁻¹(8/6) = 53.1°, and A is in quadrant II, so θ = 180° − 53.1° = 126.9°.' },
    { q: 'A vector has |A| = 13 and Ax = 5, pointing upwards (Ay > 0). Find Ay and the unit vector Â.', a: 'Ay = √(13² − 5²) = 12. Â = (5/13, 12/13) = (0.385, 0.923).' },
  ],
  add: [
    { q: 'A = (3, 4) and B = (−1, 2). Find A + B, its magnitude and direction, and A − B.', a: 'A + B = (2, 6), |A + B| = √40 ≈ 6.32, θ = tan⁻¹(6/2) = 71.6°. A − B = (4, 2).' },
    { q: 'A student walks 5 m east then 12 m north. Find the distance walked and the displacement.', a: 'Distance = 17 m. Displacement = (5, 12): magnitude 13 m at tan⁻¹(12/5) = 67.4° north of east.' },
    { q: 'Forces F₁ = (3, 4) N and F₂ = (−5, 1) N act on a body in equilibrium together with F₃. Find F₃.', a: 'F₁ + F₂ + F₃ = 0, so F₃ = −(F₁ + F₂) = −(−2, 5) = (2, −5) N.' },
  ],
  scalar: [
    { q: 'A = (2, −3). Find 3A, −A and 0.5A.', a: '3A = (6, −9); −A = (−2, 3); 0.5A = (1, −1.5).' },
    { q: 'Is (6, −9) parallel to (2, −3)?', a: 'Yes: (6, −9) = 3 × (2, −3), so they are parallel and point the same way.' },
    { q: 'Find the unit vector in the direction of (3, 4), and a vector of magnitude 10 in that direction.', a: 'Unit vector = (3/5, 4/5) = (0.6, 0.8). A vector of magnitude 10 is 10 × (0.6, 0.8) = (6, 8).' },
  ],
  dot: [
    { q: 'A = (2, 3) and B = (4, −1). Find A·B and the angle between them.', a: 'A·B = 8 − 3 = 5. |A| = √13, |B| = √17, so cos θ = 5/√221 = 0.336 and θ = 70.3°.' },
    { q: 'A force F = (10, 0) N moves a body through d = (3, 4) m. Find the work done.', a: 'W = F·d = (10)(3) + (0)(4) = 30 J.' },
    { q: 'For which value of k are (3, 4) and (k, 6) perpendicular?', a: 'Perpendicular means the dot product is 0: 3k + 24 = 0, so k = −8.' },
  ],
  cross: [
    { q: 'A = (1, 2, 3) and B = (4, 5, 6). Find A × B and its magnitude.', a: 'A × B = (2·6 − 3·5, 3·4 − 1·6, 1·5 − 2·4) = (−3, 6, −3). Magnitude = √(9 + 36 + 9) = √54 ≈ 7.35.' },
    { q: 'A wrench arm r = (2, 0, 0) m has a force F = (0, 3, 0) N applied. Find the torque r × F.', a: 'τ = (0·0 − 0·3, 0·0 − 2·0, 2·3 − 0·0) = (0, 0, 6) N·m: magnitude 6 N·m, along +z.' },
    { q: 'Find the area of the parallelogram with sides (3, 0) and (1, 2).', a: 'Area = |Ax By − Ay Bx| = |3·2 − 0·1| = 6.' },
  ],
  practice: [
    { q: 'Tip: unsure how to start? Return to the mode for that operation, set the same vectors, and compare your working with the steps shown.', a: 'Each mode shows the working for exactly the numbers on screen.' },
  ],
};

const DEFAULTS: Record<D, { A: P3; B: P3; C: P3 }> = {
  '2d': { A: P(3, 4), B: P(-1, 2), C: P(-2, -5) },
  '3d': { A: P(3, 2, 1), B: P(1, 3, 2), C: P(-2, 1, -1) },
};

function NumField({ label, value, onCommit, min, max, color, step }: { label: string; value: number; onCommit: (v: number) => void; min: number; max: number; color?: string; step?: string }) {
  const [text, setText] = useState<string | null>(null);
  return (
    <label className="flex min-w-0 flex-1 items-center gap-1.5 text-xs">
      <span className="font-semibold" style={{ color }}>{label}</span>
      <input type="number" inputMode="decimal" step={step ?? 'any'} min={min} max={max} aria-label={label} value={text ?? String(Number(value.toFixed(2)))}
        onChange={e => { setText(e.target.value); const v = Number(e.target.value); if (e.target.value !== '' && e.target.value !== '-' && Number.isFinite(v)) onCommit(clampTo(v, max)); }}
        onBlur={() => setText(null)} className="h-8 w-full min-w-0 rounded-md border border-gray-200 bg-white px-2 text-sm tabular-nums" />
    </label>
  );
}
const Stat = ({ k, v, c = 'text-gray-900' }: { k: string; v: React.ReactNode; c?: string }) => (
  <div className="flex items-center justify-between gap-3 rounded-lg bg-gray-50 px-3 py-2"><span className="text-xs text-gray-500">{k}</span><span className={`text-right text-sm font-semibold tabular-nums ${c}`}>{v}</span></div>
);
const Toggle = ({ label, on, set }: { label: string; on: boolean; set: (v: boolean) => void }) => (
  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={on} onChange={e => set(e.target.checked)} />{label}</label>
);
const Seg = <T extends string>({ value, options, set, label }: { value: T; options: { id: T; label: string }[]; set: (v: T) => void; label: string }) => (
  <div className="flex overflow-hidden rounded-md border border-gray-200" role="group" aria-label={label}>
    {options.map(o => <button key={o.id} type="button" aria-pressed={value === o.id} onClick={() => set(o.id)} className={`px-2.5 py-1.5 text-xs ${value === o.id ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}>{o.label}</button>)}
  </div>
);

export default function VectorsPage() {
  const [dim, setDim] = useState<D>('2d');
  const [mode, setMode] = useState<VMode>('components');
  const [ctx, setCtx] = useState<Context>('generic');
  const [vecs, setVecs] = useState(DEFAULTS);
  const [k, setK] = useState(2);
  const [op, setOp] = useState<Op>('A+B');
  const [method, setMethod] = useState<Method>('triangle');
  const [useC, setUseC] = useState(false);
  const [showComponents, setShowComponents] = useState(true);
  const [showUnit, setShowUnit] = useState(false);
  const [showAngle, setShowAngle] = useState(true);
  const [snap, setSnap] = useState(1);
  const [view, setView] = useState<View>(DEFAULT_VIEW);
  const [dragAxis, setDragAxis] = useState<'floor' | 'height'>('floor');
  const [planes, setPlanes] = useState(true); const [grid, setGrid] = useState(true);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [curr, setCurr] = useState(['WAEC', 'IGCSE', 'SAT']);
  // practice
  const [kind, setKind] = useState<PracticeKind | 'mixed'>('mixed');
  const [problem, setProblem] = useState<Problem | null>(null);
  const [typed, setTyped] = useState<string[]>(['', '', '']);
  const [result, setResult] = useState<{ correct: boolean; wrong: number[]; revealed?: boolean } | null>(null);
  const [score, setScore] = useState({ right: 0, tries: 0 });

  const boxRef = useRef<HTMLDivElement>(null);
  const size = useResponsiveCanvasSize(boxRef, 660, dim === '3d' ? 500 : 520, 900);
  const compact = size.width < 560;
  const canvasH = compact ? Math.round(size.width * 1.0) : size.height;

  const { A, B, C } = vecs[dim];
  const state: VState = { A, B, C, k, op, method, useC, showComponents, showUnit, showAngle };
  const practicing = mode === 'practice';

  const newProblem = (kk: PracticeKind | 'mixed' = kind, d: D = dim) => { setProblem(randomProblem(kk, d)); setTyped(['', '', '']); setResult(null); };
  const changeMode = (m: VMode) => { setMode(m); setResult(null); if (m === 'practice' && !problem) newProblem(kind, dim); };
  const changeDim = (d: D) => { setDim(d); setResult(null); if (practicing) newProblem(kind, d); };

  const practiceScene = (p: Problem): Scene => {
    const sc: Scene = { arrows: [{ from: P(), to: p.A, color: COL.A, width: 3.2, label: 'A', labelAt: 0.55 }], polys: [], arcs: [], handles: [], marks: [] };
    if (!['magnitude', 'direction', 'scalar'].includes(p.kind)) sc.arrows.push({ from: P(), to: p.B, color: COL.B, width: 3.2, label: 'B', labelAt: 0.55 });
    return sc;
  };
  const scene: Scene = practicing ? (problem ? practiceScene(problem) : { arrows: [], polys: [], arcs: [], handles: [], marks: [] }) : sceneFor(mode, dim, state, ctx);

  const setVec = (id: 'A' | 'B' | 'C', v: P3) => setVecs(s => ({ ...s, [dim]: { ...s[dim], [id]: dim === '2d' ? P(v.x, v.y, 0) : v } }));
  const onHandle = (id: 'A' | 'B' | 'C', at: P3) => {
    const h = scene.handles.find(x => x.id === id); if (!h) return;
    setVec(id, scale(minus(at, h.base), h.mul ?? 1));
  };

  // derived values
  const R = op === 'B−A' ? minus(B, A) : op === 'A−B' ? minus(A, B) : add(A, B);
  const Rtot = useC ? add(R, C) : R;
  const kA = scale(A, k);
  const ang = angleBetween(A, B);
  const X = cross(A, B);
  const dirText = (v: P3) => describeDirection(v, dim);
  const active: ('A' | 'B' | 'C')[] = mode === 'components' || mode === 'scalar' ? ['A'] : mode === 'add' ? (useC ? ['A', 'B', 'C'] : ['A', 'B']) : mode === 'dot' || mode === 'cross' ? ['A', 'B'] : [];
  const col = { A: COL.A, B: COL.B, C: COL.C };
  const comp: ('x' | 'y' | 'z')[] = dim === '2d' ? ['x', 'y'] : ['x', 'y', 'z'];
  const rg = 12;

  const check = () => {
    if (!problem) return;
    const given = problem.answer.map((_, i) => (typed[i].trim() === '' ? NaN : Number(typed[i])));
    if (given.some(g => !Number.isFinite(g))) { setResult({ correct: false, wrong: [], revealed: false }); return; }
    const r = checkProblem(problem, given); setResult(r); setScore(s => ({ right: s.right + (r.correct ? 1 : 0), tries: s.tries + 1 }));
  };

  const working: string[] = [];
  if (!practicing) {
    if (mode === 'components') {
      working.push(workMagnitude(A, dim));
      if (dim === '2d') working.push(workDirection(A)); else { const dd = dirText(A); working.push(`Direction: ${dd.text}`); }
      if (dim === '2d' && !isZero(A)) { const p = toPolar(A); workComponentsFromPolar(p.r, p.theta).forEach(l => working.push(l)); }
    }
    if (mode === 'add') {
      const first = op === 'B−A' ? B : A, second = op === 'B−A' ? A : B, n1 = op === 'B−A' ? 'B' : 'A', n2 = op === 'B−A' ? 'A' : 'B';
      workAdd(first, second, dim, op === 'A+B' ? '+' : '−', n1, n2, 'R').forEach(l => working.push(l));
      working.push(workMagnitude(R, dim, 'R'));
      if (dim === '2d') working.push(workDirection(R));
      if (useC) { workAdd(R, C, dim, '+', 'R', 'C', 'R′').forEach(l => working.push(l)); }
    }
    if (mode === 'scalar') { workScalar(A, k, dim).forEach(l => working.push(l)); working.push(`|kA| = |k||A| = ${fmt(Math.abs(k))} × ${fmt(mag(A))} = ${fmt(mag(kA))}`); }
    if (mode === 'dot') workDot(A, B, dim).forEach(l => working.push(l));
    if (mode === 'cross') { if (dim === '3d') workCross(A, B).forEach(l => working.push(l)); else working.push(`(A×B)z = AxBy − AyBx = (${fmt(A.x)})(${fmt(B.y)}) − (${fmt(A.y)})(${fmt(B.x)}) = ${fmt(X.z)}`); working.push(`|A×B| = ${fmt(mag(X))}`); }
  }

  const unitA = unit(A);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 py-4 sm:px-6">
            <div className="flex flex-col justify-between gap-3 sm:flex-row sm:items-center">
              <div><p className="mb-0.5 text-xs text-gray-400">Space and time</p><h1 className="text-lg font-semibold text-gray-900">Vectors: components, addition &amp; products</h1></div>
              <div className="flex flex-wrap gap-1.5">{CURRICULA.map(c => <button key={c} onClick={() => setCurr(s => (s.includes(c) ? s.filter(x => x !== c) : [...s, c]))} className={`rounded-full border px-2.5 py-2 text-xs font-medium transition ${curr.includes(c) ? CC[c] + ' border-transparent' : 'border-gray-200 bg-white text-gray-400'}`}>{c}</button>)}</div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] space-y-4 px-4 py-4 sm:px-6">
          <div className="flex flex-wrap items-center gap-3">
            <div className="flex gap-1 rounded-xl bg-gray-100 p-1" role="tablist" aria-label="Dimensions">
              {(['2d', '3d'] as D[]).map(d => <button key={d} role="tab" aria-selected={dim === d} onClick={() => changeDim(d)} className={`rounded-lg px-4 py-2 text-xs font-medium transition ${dim === d ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}>{d === '2d' ? '2D · Plane' : '3D · Space'}</button>)}
            </div>
            <label className="flex items-center gap-1.5 text-xs text-gray-600">Think of the vectors as
              <select value={ctx} onChange={e => setCtx(e.target.value as Context)} className="h-8 rounded-md border border-gray-200 bg-white px-2 text-xs">{(Object.keys(CONTEXTS) as Context[]).map(c => <option key={c} value={c}>{CONTEXTS[c].label}{CONTEXTS[c].unit ? ` (${CONTEXTS[c].unit})` : ''}</option>)}</select>
            </label>
          </div>
          <div className="flex gap-1 overflow-x-auto" role="tablist" aria-label="Topic">
            {MODES.map(m => <button key={m.id} role="tab" aria-selected={mode === m.id} onClick={() => changeMode(m.id)} className={`shrink-0 rounded-full border px-3.5 py-1.5 text-xs font-medium transition ${mode === m.id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{m.title}</button>)}
          </div>

          <div className="grid grid-cols-1 gap-4 lg:grid-cols-[1fr_320px] xl:grid-cols-[1fr_320px_280px]">
            <div className="min-w-0 space-y-3">
              <div ref={boxRef} className="overflow-hidden rounded-2xl border border-gray-200 bg-white p-2 shadow-sm">
                <VectorCanvas dim={dim} width={size.width} height={canvasH} scene={scene} snap={snap} view={view} onView={setView} dragAxis={dragAxis} showPlanes={planes} showGrid={grid}
                  readOnly={practicing} onHandle={onHandle}
                  ariaLabel={`${dim === '2d' ? '2D' : '3D'} vector diagram. ${practicing ? 'The vectors for the current problem are drawn from the origin.' : 'Drag the coloured handles at the tips of the vectors, or focus the diagram and use the arrow keys.'}`} />
              </div>
              <div className="flex flex-wrap items-center gap-x-4 gap-y-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5">
                <label className="flex items-center gap-1.5 text-xs text-gray-600">Snap
                  <select value={snap} onChange={e => setSnap(Number(e.target.value))} className="h-7 rounded-md border border-gray-200 bg-white px-1.5 text-xs"><option value={1}>whole numbers</option><option value={0.5}>0.5</option><option value={0}>0.1 (free)</option></select>
                </label>
                {!practicing && (mode === 'components' || mode === 'scalar') && <Toggle label="Unit vector Â" on={showUnit} set={setShowUnit} />}
                {!practicing && mode === 'components' && <Toggle label="Components" on={showComponents} set={setShowComponents} />}
                {!practicing && mode !== 'scalar' && (dim === '2d' || mode !== 'components') && <Toggle label="Angle" on={showAngle} set={setShowAngle} />}
                {dim === '3d' && <>
                  <div className="flex items-center gap-1.5 text-xs text-gray-600">Drag tip <Seg value={dragAxis} set={setDragAxis} label="Drag direction" options={[{ id: 'floor', label: 'across floor' }, { id: 'height', label: 'up / down' }]} /></div>
                  <Toggle label="Planes" on={planes} set={setPlanes} />
                </>}
                <Toggle label="Grid" on={grid} set={setGrid} />
                <div className="ml-auto"><EmbedButton path="/embed/vectors" title="Vectors — A-Factor STEM Studio" params={{ dim, mode: practicing ? 'add' : mode, A: `${A.x},${A.y},${A.z}`, B: `${B.x},${B.y},${B.z}`, k: String(k) }} /></div>
              </div>
              <p className="text-[11px] text-gray-400">{practicing ? 'Practice: the problem’s vectors are drawn from the origin on the grid.' : `Drag the coloured dots at the vector tips${dim === '3d' ? ', drag empty space to rotate' : ''}; or click the diagram and use the arrow keys${dim === '3d' ? ' (Page Up/Down for z)' : ''}.`}</p>
            </div>

            <div className="min-w-0 space-y-3">
              {!practicing && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">{active.length > 1 ? 'Vectors' : 'Vector A'}</p>
                  {active.map(id => {
                    const v = vecs[dim][id], p = toPolar(v);
                    return (
                      <div key={id} className="space-y-1.5 rounded-xl border border-gray-100 p-2">
                        <div className="text-xs font-semibold" style={{ color: col[id] }}>{id} = {compText(v, dim, 2)} = {ijk(v, dim)}</div>
                        <div className="flex gap-1.5">{comp.map(c => <NumField key={c} label={`${id}${c}`} value={v[c]} min={-rg * 4} max={rg * 4} color={col[id]} onCommit={n => setVec(id, { ...v, [c]: n })} />)}</div>
                        {dim === '2d' && <div className="flex gap-1.5"><NumField label={`|${id}|`} value={p.r} min={0} max={rg * 6} color={col[id]} onCommit={n => setVec(id, fromPolar(n, p.theta))} /><NumField label="θ°" value={p.theta} min={0} max={360} color={col[id]} onCommit={n => setVec(id, fromPolar(p.r, n))} /></div>}
                      </div>
                    );
                  })}
                  {mode === 'scalar' && (
                    <div className="space-y-1.5"><div className="flex items-center gap-2"><NumField label="k" value={k} min={-10} max={10} color={COL.R} onCommit={setK} /></div><input type="range" min={-3} max={3} step={0.5} value={Math.max(-3, Math.min(3, k))} onChange={e => setK(Number(e.target.value))} aria-label="k slider" className="w-full" style={{ accentColor: COL.R }} /></div>
                  )}
                  {mode === 'add' && (
                    <div className="space-y-2">
                      <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-gray-500">Operation</span><Seg value={op} set={setOp} label="Operation" options={[{ id: 'A+B', label: 'A + B' }, { id: 'A−B', label: 'A − B' }, { id: 'B−A', label: 'B − A' }]} /></div>
                      <div className="flex flex-wrap items-center gap-2"><span className="text-xs text-gray-500">Method</span><Seg value={method} set={setMethod} label="Method" options={[{ id: 'triangle', label: 'Tip-to-tail' }, { id: 'parallelogram', label: 'Parallelogram' }, { id: 'both', label: 'Both' }]} /></div>
                      {op === 'A+B' && <Toggle label="Add a third vector C (polygon rule)" on={useC} set={setUseC} />}
                    </div>
                  )}
                  <div className="flex flex-wrap gap-1.5">
                    <button onClick={() => setVecs(s => ({ ...s, [dim]: DEFAULTS[dim] }))} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Reset</button>
                    {mode === 'dot' && dim === '2d' && <button onClick={() => setVecs(s => ({ ...s, '2d': { ...s['2d'], B: P(-s['2d'].A.y, s['2d'].A.x) } }))} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Make B ⟂ A</button>}
                    {mode === 'add' && <button onClick={() => { if (!useC) setUseC(true); setVec('C', neg(add(A, B))); }} className="rounded-md border border-gray-200 px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300">Balance with C</button>}
                  </div>
                </div>
              )}

              {!practicing && (
                <div className="space-y-2 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Results</p>
                  {mode === 'components' && (<>
                    <Stat k="Magnitude |A|" v={withUnit(fmt(mag(A)), ctx)} c="text-indigo-600" />
                    <Stat k="Components" v={compText(A, dim)} />
                    {unitA && <Stat k="Unit vector Â" v={compText(unitA, dim, 3)} />}
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700"><span className="font-medium">Direction: </span>{isZero(A) ? 'The zero vector has no direction.' : dirText(A).text}{dim === '2d' && !isZero(A) && dirText(A).bearing !== undefined ? ` · bearing ${fmt(dirText(A).bearing!, 1)}°` : ''}</div>
                    {dim === '3d' && !isZero(A) && <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">Angles with the axes: x {fmt(dirText(A).axisAngles!.x, 1)}°, y {fmt(dirText(A).axisAngles!.y, 1)}°, z {fmt(dirText(A).axisAngles!.z, 1)}°</div>}
                  </>)}
                  {mode === 'add' && (<>
                    <Stat k={`${op === 'A+B' ? (useC ? 'A + B + C' : 'A + B') : op === 'A−B' ? 'A − B' : 'B − A'} (${CONTEXTS[ctx].resultant.toLowerCase()})`} v={compText(Rtot, dim)} c="text-rose-600" />
                    <Stat k="Magnitude" v={withUnit(fmt(mag(Rtot)), ctx)} c="text-rose-600" />
                    <div className="rounded-lg bg-rose-50 px-3 py-2 text-xs leading-relaxed text-rose-900"><span className="font-medium">Direction: </span>{isZero(Rtot) ? 'Zero vector.' : dirText(Rtot).text}</div>
                    {ang !== null && <Stat k="Angle between A and B" v={`${fmt(ang, 1)}°`} />}
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">
                      {isZero(Rtot) ? <span className="font-medium text-emerald-700">The resultant is zero: the vectors close into a polygon. For forces this means the body is in equilibrium.</span>
                        : op === 'A+B' && !useC ? <>Order does not matter: B + A = {compText(add(B, A), dim)} = A + B. Also |A + B| = {fmt(mag(R))} ≤ |A| + |B| = {fmt(mag(A) + mag(B))}.</>
                        : <>Check: {op === 'A−B' ? 'A − B is the vector from the tip of B to the tip of A.' : op === 'B−A' ? 'B − A is the vector from the tip of A to the tip of B, the opposite of A − B.' : `A + B + C = ${compText(sum([A, B, C]), dim)}.`}</>}
                    </div>
                  </>)}
                  {mode === 'scalar' && (<>
                    <Stat k={`kA with k = ${fmt(k)}`} v={compText(kA, dim)} c="text-rose-600" />
                    <Stat k="Magnitude |kA|" v={withUnit(fmt(mag(kA)), ctx)} c="text-rose-600" />
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">{k === 0 ? 'k = 0 gives the zero vector.' : k > 0 ? `k > 0: same direction as A, ${k > 1 ? 'stretched' : k < 1 ? 'shrunk' : 'unchanged'}.` : `k < 0: opposite direction to A, ${Math.abs(k) > 1 ? 'stretched' : Math.abs(k) < 1 ? 'shrunk' : 'same length'}.`}</div>
                    {unitA && <Stat k="Unit vector Â" v={compText(unitA, dim, 3)} />}
                  </>)}
                  {mode === 'dot' && (<>
                    <Stat k="A·B" v={fmt(dot(A, B))} c="text-indigo-600" />
                    <Stat k="Angle θ" v={ang === null ? 'undefined' : `${fmt(ang, 1)}°`} />
                    <Stat k="Scalar projection of A on B" v={projScalar(A, B) === null ? '—' : fmt(projScalar(A, B)!)} c="text-cyan-700" />
                    <Stat k="Vector projection" v={projVector(A, B) ? compText(projVector(A, B)!, dim) : '—'} />
                    <div className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${Math.abs(dot(A, B)) < 1e-9 ? 'bg-emerald-50 text-emerald-900' : 'bg-gray-50 text-gray-700'}`}>{Math.abs(dot(A, B)) < 1e-9 ? 'A·B = 0: the vectors are perpendicular (or one is zero).' : dot(A, B) > 0 ? 'A·B > 0: the angle is acute (less than 90°).' : 'A·B < 0: the angle is obtuse (more than 90°).'} Example: a force A (N) moving a body through B (m) does work W = A·B joules.</div>
                  </>)}
                  {mode === 'cross' && (<>
                    {dim === '3d' ? <Stat k="A × B (drawn shortened if long)" v={compText(X, dim)} c="text-violet-700" /> : <Stat k="A × B (along z)" v={`(0, 0, ${fmt(X.z)})`} c="text-violet-700" />}
                    <Stat k="|A × B| = parallelogram area" v={fmt(mag(X))} c="text-violet-700" />
                    <Stat k="Check |A||B| sin θ" v={ang === null ? '—' : fmt(mag(A) * mag(B) * Math.sin((ang * Math.PI) / 180))} />
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-xs leading-relaxed text-gray-700">
                      {isZero(X) ? 'A × B = 0: the vectors are parallel (or one is zero), so the parallelogram has no area.' : dim === '3d' ? <>Right-hand rule: fingers along A, curl towards B, thumb along A × B. Check: (A×B)·A = {fmt(dot(X, A))} and (A×B)·B = {fmt(dot(X, B))}, both zero because A × B is perpendicular to each. B × A = {compText(neg(X), dim)}.</> : <>In 2D the cross product points along the z-axis, {X.z > 0 ? 'out of the page (B is counter-clockwise from A)' : 'into the page (B is clockwise from A)'}. <button className="font-medium text-indigo-600 hover:underline" onClick={() => changeDim('3d')}>Switch to 3D to see it.</button></>}
                    </div>
                  </>)}
                </div>
              )}

              {!practicing && working.length > 0 && (
                <details open className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <summary className="cursor-pointer text-xs font-medium uppercase tracking-wide text-gray-400">Working</summary>
                  <div className="mt-2 space-y-1.5">{working.map((l, i) => <p key={i} className="font-mono text-[11px] leading-relaxed text-gray-700">{l}</p>)}</div>
                </details>
              )}

              {practicing && (
                <div className="space-y-3 rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                  <div className="flex items-center justify-between"><p className="text-xs font-medium uppercase tracking-wide text-gray-400">Practice</p><span className="rounded-full bg-gray-100 px-2.5 py-1 text-[11px] font-medium text-gray-600">Score {score.right} / {score.tries}</span></div>
                  <label className="flex items-center gap-2 text-xs text-gray-600">Topic
                    <select value={kind} onChange={e => { const v = e.target.value as PracticeKind | 'mixed'; setKind(v); newProblem(v); }} className="h-8 flex-1 rounded-md border border-gray-200 bg-white px-2 text-xs">
                      <option value="mixed">Mixed</option>{PRACTICE_KINDS[dim].map(kk => <option key={kk} value={kk}>{KIND_LABEL[kk]}</option>)}
                    </select>
                  </label>
                  {problem && (<>
                    <p className="rounded-lg bg-indigo-50 px-3 py-2 text-sm leading-relaxed text-indigo-900">{problem.prompt}</p>
                    <div className="flex gap-2">{problem.inputs.map((lab, i) => (
                      <label key={i} className="flex min-w-0 flex-1 flex-col gap-1 text-[11px] text-gray-500">{lab}
                        <input type="number" inputMode="decimal" step="any" value={typed[i]} aria-label={lab} onChange={e => { setTyped(t => t.map((x, j) => (j === i ? e.target.value : x))); setResult(null); }} className={`h-8 w-full min-w-0 rounded-md border px-2 text-sm ${result && result.wrong.includes(i) ? 'border-red-300 bg-red-50' : 'border-gray-200'}`} />
                      </label>))}</div>
                    <div className="flex flex-wrap gap-2">
                      <button onClick={check} className="rounded-lg bg-indigo-600 px-4 py-2 text-xs font-medium text-white hover:bg-indigo-700">Check</button>
                      <button onClick={() => newProblem()} className="rounded-lg border border-gray-200 bg-white px-4 py-2 text-xs text-gray-700 hover:border-indigo-300">New problem</button>
                      <button onClick={() => setResult({ correct: false, wrong: [], revealed: true })} className="rounded-lg border border-gray-200 bg-white px-3 py-2 text-xs text-gray-500">Reveal</button>
                    </div>
                    {result && (
                      <div aria-live="polite" className={`rounded-lg px-3 py-2 text-xs leading-relaxed ${result.correct ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                        {result.correct ? '✓ Correct!' : result.revealed ? <>Answer: <span className="font-semibold">{problem.answer.map(a => fmt(a, 2)).join(', ')}</span>{problem.unit ? ` ${problem.unit}` : ''}. <span className="font-mono">{problem.explain}</span></> : result.wrong.length ? `Not quite: check ${result.wrong.map(i => problem.inputs[i]).join(' and ')}.` : 'Fill in every box first.'}
                      </div>
                    )}
                  </>)}
                </div>
              )}
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-amber-700">📋 Teacher notes</p>
                <ul className="space-y-2">{NOTES[mode].map((n, i) => <li key={i} className="flex gap-2 text-xs leading-relaxed text-amber-900"><span className="mt-0.5 shrink-0 text-amber-400">•</span>{n}</li>)}</ul>
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="mb-3 text-xs font-medium uppercase tracking-wide text-gray-500">✏️ Exercises</p>
                <div className="space-y-2">{EXERCISES[mode].map((ex, i) => (
                  <div key={`${mode}-${i}`} className="overflow-hidden rounded-xl border border-gray-100">
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

write_file src/app/embed/vectors/page.tsx << 'FILEEOF'
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
FILEEOF

# -- Register the sim on the simulations page (idempotent, CRLF-safe) ----------
node - << 'NODEEOF'
const fs = require('fs');
const p = 'src/app/simulations/page.tsx';
const raw = fs.readFileSync(p, 'utf8'), crlf = raw.includes('\r\n'), s = raw.replace(/\r\n/g, '\n');
if (/slug:\s*'vectors'/.test(s)) { console.log('  Vectors card already registered'); process.exit(0); }
const entry = [
  "  {", "    slug: 'vectors',", "    href: '/simulations/vectors',", "    title: 'Vectors: components, addition & products',",
  "    description: 'Resolve vectors into components, add and subtract them, scale them, and explore dot and cross products in 2D and 3D, with worked steps and practice.',",
  "    icon: '➡️',", "    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],", "    topic: 'Space and time',", "    status: 'live',", "  },"].join('\n') + '\n';
let t;
const space = s.search(/  \{\n    slug: 'space',/);
if (space >= 0) t = s.slice(0, space) + entry + s.slice(space);
else {
  const m = s.match(/const SIMULATIONS\s*=\s*\[\n/);
  if (!m) { console.error('ERROR: could not find the SIMULATIONS list in simulations/page.tsx. Add the Vectors card by hand.'); process.exit(1); }
  t = s.slice(0, m.index + m[0].length) + entry + s.slice(m.index + m[0].length);
}
if (!/'Space and time'/.test(t.split('const SIMULATIONS')[1] ? t.match(/const TOPICS[^\n]*/)?.[0] || '' : '')) {
  const tp = t.match(/const TOPICS\s*=\s*\[\s*'All'\s*,/);
  if (tp && !/const TOPICS[^\n]*'Space and time'/.test(t)) { t = t.replace(tp[0], tp[0] + " 'Space and time',"); console.log("  added the 'Space and time' topic filter"); }
}
if (!fs.existsSync(p + '.bak')) fs.writeFileSync(p + '.bak', raw);
fs.writeFileSync(p, crlf ? t.replace(/\n/g, '\r\n') : t);
console.log('  added the Vectors card to SIMULATIONS');
NODEEOF

echo ""
echo "Done. npm run dev, then open /simulations/vectors"
