// Crystal builder: cubic prototype structures built from fractional coordinates.
//
// Everything numeric (coordination numbers, nearest-neighbour distance, atoms per cell, density,
// packing fraction) is COMPUTED from the geometry of the prototype and the lattice parameter you
// give — nothing is looked up. Whether a particular compound really adopts a prototype is a
// separate question this module cannot answer.

import { BY_SYMBOL } from './elements';
import { chargeBalance, reduce, formulaPlain, type ChargeReport, type Composition } from './compound';
import { RADII_B_VI, RADII_X_VI, key as radiusKey, type Site } from './perovskite';
import { AVOGADRO } from './nuclear';

export type Role = 'A' | 'X';
export type ProtoId = 'sc' | 'bcc' | 'fcc' | 'diamond' | 'cscl' | 'rocksalt' | 'zincblende' | 'fluorite' | 'cu3au';
type V3 = [number, number, number];

export interface Sublattice { role: Role; site: Site; name: string; positions: V3[] }
export interface ProtoDef {
  id: ProtoId;
  label: string;
  group: 'Elements' | 'AX compounds' | 'AX₂ compounds' | 'Ordered alloys';
  spaceGroup: string;
  roles: Role[];
  note: string;
  sublattices: Sublattice[];
}

const FCC: V3[] = [[0, 0, 0], [0, 0.5, 0.5], [0.5, 0, 0.5], [0.5, 0.5, 0]];
const shift = (ps: V3[], s: number): V3[] => ps.map(p => p.map(v => Math.round((((v + s) % 1) + 1) % 1 * 1e6) / 1e6) as V3);

export const PROTOTYPES: Record<ProtoId, ProtoDef> = {
  sc: { id: 'sc', label: 'Simple cubic', group: 'Elements', spaceGroup: 'Pm-3m (221)', roles: ['A'],
    note: 'One atom per cell at the corners. Rare in practice (α-polonium is the usual example).',
    sublattices: [{ role: 'A', site: 'A', name: 'A (0,0,0)', positions: [[0, 0, 0]] }] },
  bcc: { id: 'bcc', label: 'Body-centred cubic (bcc)', group: 'Elements', spaceGroup: 'Im-3m (229)', roles: ['A'],
    note: 'Corner atoms plus one atom at the cell centre; 8 nearest neighbours.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (0,0,0)', positions: [[0, 0, 0]] }, { role: 'A', site: 'B', name: 'A (½,½,½)', positions: [[0.5, 0.5, 0.5]] }] },
  fcc: { id: 'fcc', label: 'Face-centred cubic (fcc)', group: 'Elements', spaceGroup: 'Fm-3m (225)', roles: ['A'],
    note: 'Corners plus face centres: cubic close packing, 12 nearest neighbours.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (fcc)', positions: FCC }] },
  diamond: { id: 'diamond', label: 'Diamond cubic', group: 'Elements', spaceGroup: 'Fd-3m (227)', roles: ['A'],
    note: 'Two interpenetrating fcc lattices offset by (¼,¼,¼); every atom has 4 tetrahedral neighbours.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (fcc)', positions: FCC }, { role: 'A', site: 'B', name: 'A (fcc + ¼¼¼)', positions: shift(FCC, 0.25) }] },
  cscl: { id: 'cscl', label: 'Caesium chloride (CsCl)', group: 'AX compounds', spaceGroup: 'Pm-3m (221)', roles: ['A', 'X'],
    note: 'Simple cubic A with X at the body centre: 8-fold coordination for both.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (0,0,0)', positions: [[0, 0, 0]] }, { role: 'X', site: 'X', name: 'X (½,½,½)', positions: [[0.5, 0.5, 0.5]] }] },
  rocksalt: { id: 'rocksalt', label: 'Rocksalt (NaCl)', group: 'AX compounds', spaceGroup: 'Fm-3m (225)', roles: ['A', 'X'],
    note: 'Two fcc lattices offset by (½,½,½): 6-fold (octahedral) coordination for both.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (fcc)', positions: FCC }, { role: 'X', site: 'X', name: 'X (fcc + ½½½)', positions: shift(FCC, 0.5) }] },
  zincblende: { id: 'zincblende', label: 'Zincblende (ZnS)', group: 'AX compounds', spaceGroup: 'F-43m (216)', roles: ['A', 'X'],
    note: 'Two fcc lattices offset by (¼,¼,¼): 4-fold (tetrahedral) coordination; the diamond structure with two species.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (fcc)', positions: FCC }, { role: 'X', site: 'X', name: 'X (fcc + ¼¼¼)', positions: shift(FCC, 0.25) }] },
  fluorite: { id: 'fluorite', label: 'Fluorite (CaF₂)', group: 'AX₂ compounds', spaceGroup: 'Fm-3m (225)', roles: ['A', 'X'],
    note: 'A on an fcc lattice with X filling all eight tetrahedral holes. Swap the roles for the antifluorite type (e.g. Li₂O).',
    sublattices: [{ role: 'A', site: 'A', name: 'A (fcc)', positions: FCC }, { role: 'X', site: 'X', name: 'X (fcc + ¼¼¼)', positions: shift(FCC, 0.25) }, { role: 'X', site: 'B2', name: 'X (fcc + ¾¾¾)', positions: shift(FCC, 0.75) }] },
  cu3au: { id: 'cu3au', label: 'Cu₃Au-type (L1₂)', group: 'Ordered alloys', spaceGroup: 'Pm-3m (221)', roles: ['A', 'X'],
    note: 'An ordered fcc alloy: A at the corners and X on the face centres, giving AX₃.',
    sublattices: [{ role: 'A', site: 'A', name: 'A (0,0,0)', positions: [[0, 0, 0]] }, { role: 'X', site: 'X', name: 'X (face centres)', positions: [[0.5, 0.5, 0], [0.5, 0, 0.5], [0, 0.5, 0.5]] }] },
};
export const PROTO_ORDER: ProtoId[] = ['sc', 'bcc', 'fcc', 'diamond', 'cscl', 'rocksalt', 'zincblende', 'fluorite', 'cu3au'];

export interface CellAtom { role: Role; site: Site; frac: V3 }
export const cellAtoms = (p: ProtoDef): CellAtom[] => p.sublattices.flatMap(s => s.positions.map(frac => ({ role: s.role, site: s.site, frac })));

// ── Computed geometry ────────────────────────────────────────────────────────
export interface Coordination { role: Role; like: number; unlike: number; total: number }
export interface Geometry {
  atomsPerCell: number;
  counts: Record<Role, number>;
  /** Nearest-neighbour distance in units of the lattice parameter. */
  nn: number;
  coordination: Coordination[];
  stoich: string; // e.g. "AX2"
}

const geometryCache = new Map<ProtoId, Geometry>();

export function geometry(p: ProtoDef): Geometry {
  const hit = geometryCache.get(p.id);
  if (hit) return hit;
  const atoms = cellAtoms(p);
  const all: { role: Role; pos: V3 }[] = [];
  for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) for (let k = -1; k <= 1; k++) {
    for (const a of atoms) all.push({ role: a.role, pos: [a.frac[0] + i, a.frac[1] + j, a.frac[2] + k] });
  }
  const dist = (u: V3, v: V3) => Math.hypot(u[0] - v[0], u[1] - v[1], u[2] - v[2]);
  const coordination: Coordination[] = [];
  let nn = Infinity;
  for (const role of p.roles) {
    const origin = atoms.find(a => a.role === role)!;
    let dmin = Infinity;
    for (const o of all) { const d = dist(origin.frac, o.pos); if (d > 1e-6 && d < dmin) dmin = d; }
    const shell = all.filter(o => Math.abs(dist(origin.frac, o.pos) - dmin) < 1e-6);
    const like = shell.filter(o => o.role === role).length;
    coordination.push({ role, like, unlike: shell.length - like, total: shell.length });
    nn = Math.min(nn, dmin);
  }
  const counts: Record<Role, number> = { A: 0, X: 0 };
  atoms.forEach(a => { counts[a.role]++; });
  const g = (a: number, b: number): number => (b ? g(b, a % b) : a);
  const d = p.roles.length === 1 ? counts.A : g(counts.A, counts.X);
  const stoich = p.roles.length === 1 ? 'A' : `A${counts.A / d === 1 ? '' : counts.A / d}X${counts.X / d === 1 ? '' : counts.X / d}`;
  const out = { atomsPerCell: atoms.length, counts, nn, coordination, stoich };
  geometryCache.set(p.id, out);
  return out;
}

export interface CrystalReport {
  composition: Composition;
  formula: string;
  geo: Geometry;
  massPerCell: number;
  density: number; // g/cm³
  nnAngstrom: number;
  /** Ideal hard-sphere packing fraction — only meaningful for a single element. */
  packing: number | null;
  charge: ChargeReport | null;
  radius: RadiusRule | null;
}

export function analyseCrystal(p: ProtoDef, el: Record<Role, string>, a: number): CrystalReport {
  const geo = geometry(p);
  const composition: Composition = {};
  (p.roles).forEach(r => { composition[el[r]] = (composition[el[r]] ?? 0) + geo.counts[r]; });
  const massPerCell = p.roles.reduce((m, r) => m + BY_SYMBOL[el[r]].mass * geo.counts[r], 0);
  const density = (massPerCell / AVOGADRO) / (Math.pow(a, 3) * 1e-24);
  const reduced = reduce(composition);
  const mono = p.roles.length === 1 || el.A === el.X;
  const packing = mono ? geo.atomsPerCell * (4 / 3) * Math.PI * Math.pow(geo.nn / 2, 3) : null;
  const charge = Object.keys(reduced).length > 1 ? chargeBalance(reduced) : null;
  return {
    composition, formula: formulaPlain(reduced), geo, massPerCell, density, nnAngstrom: geo.nn * a, packing, charge,
    radius: p.roles.length === 2 && charge?.status === 'balanced' ? radiusRule(p, el, charge) : null,
  };
}

// ── Pauling radius-ratio rule (heuristic with many exceptions) ───────────────
const EXTRA_CATION_VI: Record<string, number> = { 'Rb:1': 1.52, 'Cs:1': 1.67 };
const cationRadius = (s: string, q: number) => RADII_B_VI[radiusKey(s, q)] ?? EXTRA_CATION_VI[radiusKey(s, q)] ?? null;

export interface RadiusRule { ratio: number; cationRadius: number; anionRadius: number; expectedCN: number; expectedText: string; consistent: boolean | null; actualCN: number }

export function radiusRule(p: ProtoDef, el: Record<Role, string>, charge: ChargeReport): RadiusRule | null {
  const sol = charge.solutions[0]?.states;
  if (!sol) return null;
  const qa = sol[el.A], qx = sol[el.X];
  if (qa === undefined || qx === undefined || el.A === el.X) return null;
  // Whichever role carries the positive charge is the cation.
  const cat = qa > 0 ? { sym: el.A, q: qa, role: 'A' as Role } : { sym: el.X, q: qx, role: 'X' as Role };
  const an = qa > 0 ? { sym: el.X, q: qx } : { sym: el.A, q: qa };
  const rc = cationRadius(cat.sym, cat.q), ra = RADII_X_VI[radiusKey(an.sym, an.q)];
  if (rc == null || ra == null) return null;
  const ratio = rc / ra;
  const [cn, text] = ratio < 0.155 ? [2, 'below 0.155 (linear)'] : ratio < 0.225 ? [3, 'trigonal'] : ratio < 0.414 ? [4, 'tetrahedral'] : ratio < 0.732 ? [6, 'octahedral'] : ratio <= 1 ? [8, 'cubic'] : [12, 'above 1 (close-packed, 12)'];
  const actual = geometry(p).coordination.find(c => c.role === cat.role)!.total;
  return { ratio, cationRadius: rc, anionRadius: ra, expectedCN: cn, expectedText: text, consistent: actual === cn, actualCN: actual };
}

// ── CIF export ───────────────────────────────────────────────────────────────
export function crystalCif(p: ProtoDef, el: Record<Role, string>, a: number, title: string): string {
  const counters: Record<string, number> = {};
  const rows = cellAtoms(p).map(at => {
    const s = el[at.role];
    counters[s] = (counters[s] ?? 0) + 1;
    return `${s}${counters[s]} ${s} ${at.frac.map(v => v.toFixed(5)).join(' ')} 1.0`;
  });
  return [
    `data_${title.replace(/[^A-Za-z0-9_]/g, '_')}`,
    '# PROPOSED MODEL generated by A-Factor STEM Studio (Chemistry playground).',
    `# Prototype: ${p.label}. Lattice parameter was set by the user; geometry is NOT relaxed.`,
    '# Not evidence that this material exists in this structure.',
    `_cell_length_a ${a.toFixed(4)}`, `_cell_length_b ${a.toFixed(4)}`, `_cell_length_c ${a.toFixed(4)}`,
    '_cell_angle_alpha 90', '_cell_angle_beta 90', '_cell_angle_gamma 90',
    "_symmetry_space_group_name_H-M 'P 1'", '_symmetry_Int_Tables_number 1',
    'loop_', '_symmetry_equiv_pos_as_xyz', "'x, y, z'",
    'loop_', '_atom_site_label', '_atom_site_type_symbol',
    '_atom_site_fract_x', '_atom_site_fract_y', '_atom_site_fract_z', '_atom_site_occupancy',
    ...rows, '',
  ].join('\n');
}
