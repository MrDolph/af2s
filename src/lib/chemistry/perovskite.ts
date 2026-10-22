// Perovskite geometry: Shannon radii, Goldschmidt tolerance factor, octahedral
// factor, structural models (as atom lists) and a CIF writer.
//
// These are *geometric heuristics and idealised models* for teaching and for
// screening candidates. They do not establish stability: for that you need
// total-energy / phonon calculations or experimental evidence.

import { BY_SYMBOL } from './elements';
import { formulaPlain, type Composition } from './compound';

// Shannon (1976) effective ionic radii in Å, keyed by "Symbol:charge".
// A site: twelve-coordinate (XII). B site: six-coordinate (VI). X site: six-coordinate.
// High-spin values for the 3d metals. Bundled for teaching — verify against the
// original table before quoting a number in a publication.
export const RADII_A_XII: Record<string, number> = {
  'Na:1': 1.39, 'K:1': 1.64, 'Rb:1': 1.72, 'Cs:1': 1.88, 'Tl:1': 1.70,
  'Ca:2': 1.34, 'Sr:2': 1.44, 'Ba:2': 1.61, 'Pb:2': 1.49, 'La:3': 1.36,
};
export const RADII_B_VI: Record<string, number> = {
  'Li:1': 0.76, 'Na:1': 1.02, 'K:1': 1.38, 'Cu:1': 0.77, 'Ag:1': 1.15,
  'Mg:2': 0.72, 'Ca:2': 1.00, 'Sr:2': 1.18, 'Ba:2': 1.35, 'Mn:2': 0.83, 'Fe:2': 0.78,
  'Co:2': 0.745, 'Ni:2': 0.69, 'Cu:2': 0.73, 'Zn:2': 0.74, 'Cd:2': 0.95, 'Ge:2': 0.73,
  'Sn:2': 1.10, 'Pb:2': 1.19,
  'Al:3': 0.535, 'Ga:3': 0.62, 'In:3': 0.80, 'Sc:3': 0.745, 'Y:3': 0.90, 'V:3': 0.64,
  'Cr:3': 0.615, 'Fe:3': 0.645, 'Sb:3': 0.76, 'Bi:3': 1.03,
  'Ti:4': 0.605, 'Zr:4': 0.72, 'Hf:4': 0.71, 'Ge:4': 0.53, 'Sn:4': 0.69, 'Mn:4': 0.53,
  'Nb:5': 0.64, 'Ta:5': 0.64,
};
export const RADII_X_VI: Record<string, number> = {
  'F:-1': 1.33, 'Cl:-1': 1.81, 'Br:-1': 1.96, 'I:-1': 2.20,
  'O:-2': 1.40, 'S:-2': 1.84, 'Se:-2': 1.98, 'Te:-2': 2.21,
};

export const key = (symbol: string, charge: number) => `${symbol}:${charge}`;

/** Oxidation states of an element that have a tabulated radius at the given site. */
export function availableStates(symbol: string, site: 'A' | 'B' | 'X'): number[] {
  const table = site === 'A' ? RADII_A_XII : site === 'B' ? RADII_B_VI : RADII_X_VI;
  return Object.keys(table).filter(k => k.startsWith(symbol + ':')).map(k => Number(k.split(':')[1])).sort((a, b) => b - a);
}

export interface SiteAssignment {
  A: { symbol: string; charge: number };
  B: { symbol: string; charge: number };
  X: { symbol: string; charge: number };
}

export interface PerovskiteReport {
  formula: string;
  chargeSum: number; // should be 0 for ABX3
  rA: number | null;
  rB: number | null;
  rX: number | null;
  tolerance: number | null;
  octahedral: number | null;
  missing: string[]; // site radii we could not find
  toleranceVerdict: string;
  octahedralVerdict: string;
  /** a (Å) if B–X touch / if A–X touch. */
  aBX: number | null;
  aAX: number | null;
}

export function analyse(s: SiteAssignment, anions = 3): PerovskiteReport {
  const comp: Composition = {};
  comp[s.A.symbol] = (comp[s.A.symbol] ?? 0) + 1;
  comp[s.B.symbol] = (comp[s.B.symbol] ?? 0) + 1;
  comp[s.X.symbol] = (comp[s.X.symbol] ?? 0) + anions;

  const rA = RADII_A_XII[key(s.A.symbol, s.A.charge)] ?? null;
  const rB = RADII_B_VI[key(s.B.symbol, s.B.charge)] ?? null;
  const rX = RADII_X_VI[key(s.X.symbol, s.X.charge)] ?? null;
  const missing: string[] = [];
  if (rA == null) missing.push(`A: ${s.A.symbol}${fmtCharge(s.A.charge)} (CN 12)`);
  if (rB == null) missing.push(`B: ${s.B.symbol}${fmtCharge(s.B.charge)} (CN 6)`);
  if (rX == null) missing.push(`X: ${s.X.symbol}${fmtCharge(s.X.charge)} (CN 6)`);

  const chargeSum = s.A.charge + s.B.charge + anions * s.X.charge;
  let tolerance: number | null = null, octahedral: number | null = null;
  let aBX: number | null = null, aAX: number | null = null;
  if (rA != null && rB != null && rX != null) {
    tolerance = (rA + rX) / (Math.SQRT2 * (rB + rX));
    octahedral = rB / rX;
    aBX = 2 * (rB + rX);
    aAX = Math.SQRT2 * (rA + rX);
  }

  const toleranceVerdict =
    tolerance == null ? 'Needs all three radii.'
    : tolerance > 1.06 ? 'Above ~1.0: A is large for the cavity — hexagonal / non-perovskite polytypes are common.'
    : tolerance >= 0.9 ? 'In the range where a cubic (or nearly cubic) perovskite is geometrically plausible.'
    : tolerance >= 0.8 ? 'Below 0.9: octahedral tilting is expected (distorted, e.g. orthorhombic), if the perovskite forms at all.'
    : 'Below ~0.8: A is small for the cavity — other structure types are likely to compete.';
  const octahedralVerdict =
    octahedral == null ? 'Needs all three radii.'
    : octahedral < 0.414 ? 'Below 0.414: B is small for an octahedral hole — octahedral coordination is geometrically strained.'
    : octahedral <= 0.732 ? 'Within the usual 0.414–0.732 window for octahedral coordination.'
    : 'Above 0.732: B is large — higher coordination is more likely than octahedral.';

  return { formula: formulaPlain(comp), chargeSum, rA, rB, rX, tolerance, octahedral, missing, toleranceVerdict, octahedralVerdict, aBX, aAX };
}

export interface ModelSites {
  A: { symbol: string; charge: number };
  B: { symbol: string; charge: number };
  B2?: { symbol: string; charge: number };
  X: { symbol: string; charge: number };
}

function verdicts(t: number | null, mu: number | null) {
  const toleranceVerdict =
    t == null ? 'Needs all radii.'
    : t > 1.06 ? 'Above ~1.0: A is large for the cavity — hexagonal / non-perovskite polytypes are common.'
    : t >= 0.9 ? 'In the range where a cubic (or nearly cubic) perovskite is geometrically plausible.'
    : t >= 0.8 ? 'Below 0.9: octahedral tilting is expected (distorted, e.g. orthorhombic), if the perovskite forms at all.'
    : 'Below ~0.8: A is small for the cavity — other structure types are likely to compete.';
  const octahedralVerdict =
    mu == null ? 'Needs all radii.'
    : mu < 0.414 ? 'Below 0.414: B is small for an octahedral hole — octahedral coordination is geometrically strained.'
    : mu <= 0.732 ? 'Within the usual 0.414–0.732 window for octahedral coordination.'
    : 'Above 0.732: B is large — higher coordination is more likely than octahedral.';
  return { toleranceVerdict, octahedralVerdict };
}

/** ABX3 (cubic model) or A2BB'X6 (double model; B radius is the B/B′ average). */
export function analyseModel(model: ModelId, s: ModelSites): PerovskiteReport & { composition: Composition } {
  if (model === 'cubic' || !s.B2) {
    const r = analyse({ A: s.A, B: s.B, X: s.X });
    const composition: Composition = {};
    composition[s.A.symbol] = (composition[s.A.symbol] ?? 0) + 1;
    composition[s.B.symbol] = (composition[s.B.symbol] ?? 0) + 1;
    composition[s.X.symbol] = (composition[s.X.symbol] ?? 0) + 3;
    return { ...r, composition };
  }
  const rA = RADII_A_XII[key(s.A.symbol, s.A.charge)] ?? null;
  const rB1 = RADII_B_VI[key(s.B.symbol, s.B.charge)] ?? null;
  const rB2 = RADII_B_VI[key(s.B2.symbol, s.B2.charge)] ?? null;
  const rX = RADII_X_VI[key(s.X.symbol, s.X.charge)] ?? null;
  const missing: string[] = [];
  if (rA == null) missing.push(`A: ${s.A.symbol}${fmtCharge(s.A.charge)} (CN 12)`);
  if (rB1 == null) missing.push(`B: ${s.B.symbol}${fmtCharge(s.B.charge)} (CN 6)`);
  if (rB2 == null) missing.push(`B′: ${s.B2.symbol}${fmtCharge(s.B2.charge)} (CN 6)`);
  if (rX == null) missing.push(`X: ${s.X.symbol}${fmtCharge(s.X.charge)} (CN 6)`);
  const composition: Composition = {};
  const bump = (sym: string, n: number) => { composition[sym] = (composition[sym] ?? 0) + n; };
  bump(s.A.symbol, 2); bump(s.B.symbol, 1); bump(s.B2.symbol, 1); bump(s.X.symbol, 6);
  const rB = rB1 != null && rB2 != null ? (rB1 + rB2) / 2 : null;
  let tolerance: number | null = null, octahedral: number | null = null, aBX: number | null = null, aAX: number | null = null;
  if (rA != null && rB != null && rX != null) {
    tolerance = (rA + rX) / (Math.SQRT2 * (rB + rX));
    octahedral = rB / rX;
    aBX = 2 * (rB + rX);
    aAX = Math.SQRT2 * (rA + rX);
  }
  return {
    formula: formulaPlain(composition),
    chargeSum: 2 * s.A.charge + s.B.charge + s.B2.charge + 6 * s.X.charge,
    rA, rB, rX, tolerance, octahedral, missing, ...verdicts(tolerance, octahedral), aBX, aAX, composition,
  };
}

const SUPERSCRIPT = '⁰¹²³⁴⁵⁶⁷⁸⁹';
/** 2 → "²⁺", -1 → "⁻", 0 → "⁰". */
export function fmtCharge(q: number): string {
  if (q === 0) return '⁰';
  const m = Math.abs(q);
  const digits = m === 1 ? '' : String(m).split('').map(d => SUPERSCRIPT[Number(d)]).join('');
  return digits + (q > 0 ? '⁺' : '⁻');
}

// ── Structural models ────────────────────────────────────────────────────────

export type Site = 'A' | 'B' | 'B2' | 'X';
export interface Atom { site: Site; frac: [number, number, number] }
export type ModelId = 'cubic' | 'double';

export interface ModelDef {
  id: ModelId;
  label: string;
  spaceGroup: string;
  note: string;
  /** Cell edge as a multiple of the simple-cubic perovskite edge `a`. */
  cellFactor: number;
  atoms: Atom[];
}

// Simple cubic perovskite ABX3, Pm-3m: A (0,0,0), B (½,½,½), X (½,½,0),(½,0,½),(0,½,½).
const cubicAtoms: Atom[] = [
  { site: 'A', frac: [0, 0, 0] },
  { site: 'B', frac: [0.5, 0.5, 0.5] },
  { site: 'X', frac: [0.5, 0.5, 0] },
  { site: 'X', frac: [0.5, 0, 0.5] },
  { site: 'X', frac: [0, 0.5, 0.5] },
];

// Ordered double perovskite A2BB′X6, rock-salt ordering of B/B′, Fm-3m, built
// from the 2×2×2 block of cubic cells (edge = 2a).
function doubleAtoms(): Atom[] {
  const atoms: Atom[] = [];
  for (let i = 0; i < 2; i++) for (let j = 0; j < 2; j++) for (let k = 0; k < 2; k++) {
    const o: [number, number, number] = [i, j, k];
    const f = (v: [number, number, number]): [number, number, number] =>
      [(o[0] + v[0]) / 2, (o[1] + v[1]) / 2, (o[2] + v[2]) / 2];
    atoms.push({ site: 'A', frac: f([0, 0, 0]) });
    atoms.push({ site: (i + j + k) % 2 === 0 ? 'B' : 'B2', frac: f([0.5, 0.5, 0.5]) });
    atoms.push({ site: 'X', frac: f([0.5, 0.5, 0]) });
    atoms.push({ site: 'X', frac: f([0.5, 0, 0.5]) });
    atoms.push({ site: 'X', frac: f([0, 0.5, 0.5]) });
  }
  return atoms;
}

export const MODELS: Record<ModelId, ModelDef> = {
  cubic: {
    id: 'cubic', label: 'Cubic ABX₃ (aristotype)', spaceGroup: 'Pm-3m (221)', cellFactor: 1,
    note: 'Ideal corner-sharing BX₆ octahedra with no tilting. A proposed model, not a relaxed structure.',
    atoms: cubicAtoms,
  },
  double: {
    id: 'double', label: 'Ordered double perovskite A₂BB′X₆', spaceGroup: 'Fm-3m (225)', cellFactor: 2,
    note: 'B and B′ alternate like rock salt on the octahedral sites. Needs a second B-site element.',
    atoms: doubleAtoms(),
  },
};

/** Replicate a model's cell n×n×n; returns positions in units of the model's cell edge. */
export function supercell(atoms: Atom[], n: number): { site: Site; pos: [number, number, number] }[] {
  const out: { site: Site; pos: [number, number, number] }[] = [];
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) for (let k = 0; k < n; k++) {
    for (const a of atoms) {
      const p: [number, number, number] = [a.frac[0] + i, a.frac[1] + j, a.frac[2] + k];
      out.push({ site: a.site, pos: p });
    }
  }
  return out;
}

/** Atoms on the cell boundary (frac = 1) are drawn so edges look complete. */
export function withBoundaryImages(atoms: Atom[], n: number): { site: Site; pos: [number, number, number] }[] {
  const base = supercell(atoms, n);
  const out = [...base];
  const key3 = (p: number[]) => p.map(v => v.toFixed(4)).join(',');
  const have = new Set(base.map(a => key3(a.pos)));
  const add = (site: Site, p: [number, number, number]) => {
    const k = key3(p);
    if (!have.has(k)) { have.add(k); out.push({ site, pos: p }); }
  };
  for (const a of base) {
    const shifts = a.pos.map(v => (Math.abs(v) < 1e-9 ? [0, n] : [0])) as number[][];
    for (const sx of shifts[0]) for (const sy of shifts[1]) for (const sz of shifts[2]) {
      if (sx || sy || sz) add(a.site, [a.pos[0] + sx, a.pos[1] + sy, a.pos[2] + sz]);
    }
  }
  return out;
}

// ── CIF export (P1 listing of every atom in one cell) ────────────────────────
export function toCif(opts: {
  title: string; a: number; model: ModelDef;
  elements: Record<Site, string | undefined>;
}): string {
  const { a, model, elements, title } = opts;
  const L = (a * model.cellFactor).toFixed(4);
  const rows: string[] = [];
  const counters: Record<string, number> = {};
  for (const at of model.atoms) {
    const el = elements[at.site];
    if (!el) continue;
    counters[el] = (counters[el] ?? 0) + 1;
    const label = `${el}${counters[el]}`;
    rows.push(`${label} ${el} ${at.frac.map(v => v.toFixed(5)).join(' ')} 1.0`);
  }
  return [
    `data_${title.replace(/[^A-Za-z0-9_]/g, '_')}`,
    '# PROPOSED MODEL generated by A-Factor STEM Studio (Chemistry playground).',
    '# Lattice parameter is an ionic-radius estimate and the geometry is NOT relaxed.',
    '# Not evidence that this material exists or is stable.',
    `_cell_length_a ${L}`, `_cell_length_b ${L}`, `_cell_length_c ${L}`,
    '_cell_angle_alpha 90', '_cell_angle_beta 90', '_cell_angle_gamma 90',
    "_symmetry_space_group_name_H-M 'P 1'", '_symmetry_Int_Tables_number 1',
    'loop_', '_symmetry_equiv_pos_as_xyz', "'x, y, z'",
    'loop_', '_atom_site_label', '_atom_site_type_symbol',
    '_atom_site_fract_x', '_atom_site_fract_y', '_atom_site_fract_z', '_atom_site_occupancy',
    ...rows, '',
  ].join('\n');
}

/** Rough density (g/cm³) of a model cell: mass of cell contents / volume. */
export function density(model: ModelDef, a: number, elements: Record<Site, string | undefined>): number | null {
  let mass = 0;
  for (const at of model.atoms) {
    const el = elements[at.site];
    if (!el) return null;
    mass += BY_SYMBOL[el].mass;
  }
  const volA3 = Math.pow(a * model.cellFactor, 3);
  // atoms are all inside one cell by construction (fractional coordinates in [0,1)).
  return (mass / 6.02214076e23) / (volA3 * 1e-24);
}
