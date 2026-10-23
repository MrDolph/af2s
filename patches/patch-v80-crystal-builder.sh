#!/bin/bash
# A-Factor STEM Studio — Chemistry playground, part 4: Crystal builder (v80)
# Run inside af2s/ (the project ROOT) AFTER patch-v76 ... v79:
#     bash patches/patch-v80-crystal-builder.sh
#
# ADDS   /chemistry/crystal-builder
#   - Nine cubic prototypes: simple cubic, bcc, fcc, diamond, CsCl, rocksalt, zincblende, fluorite
#     (antifluorite by swapping roles), Cu3Au-type (L1_2)
#   - Assign elements and a lattice parameter; rotatable model with nearest-neighbour bonds, 1x1x1 / 2x2x2 cells
#   - COMPUTED from the geometry: atoms per cell, coordination numbers, nearest-neighbour distance, density,
#     ideal packing fraction (single elements), and a side-by-side comparison table of all prototypes
#   - Rule-based checks: charge balance and the Pauling radius-ratio rule (flagged as a heuristic with exceptions,
#     e.g. Li2O and LiI)
#   - Presets (NaCl, MgO, CsCl, ZnS, GaAs, CaF2, Li2O, Cu, Fe, Si, Po, Cu3Au), saved candidates, proposed-structure CIF
# UPDATES  candidates.ts (candidate kind 'crystal'); /chemistry hub (Crystal builder card now Live)
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -d src ]; then echo "ERROR: run from the project root (package.json + src/)."; exit 1; fi
if [ ! -f src/lib/chemistry/nuclear.ts ]; then echo "ERROR: apply patch-v76 ... v79 first."; exit 1; fi

echo "Applying Crystal builder (v80)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/chemistry/crystal.ts << 'FILEEOF'
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
FILEEOF

write_file src/lib/chemistry/candidates.ts << 'FILEEOF'
'use client';
// Saved candidates: kept in this browser's localStorage (nothing is uploaded).
import { useSyncExternalStore } from 'react';
import type { Composition } from './compound';

export interface Candidate {
  id: string;
  name: string;
  savedAt: string; // ISO
  kind: 'composition' | 'perovskite' | 'heusler' | 'crystal';
  formula: string;
  composition: Composition;
  molarMass: number;
  /** Rule-based charge-balance outcome at the time of saving. */
  chargeStatus: string;
  perovskite?: {
    model: 'cubic' | 'double';
    sites: Record<string, { symbol: string; charge: number } | undefined>;
    a: number;
    tolerance: number | null;
    octahedral: number | null;
    density: number | null;
  };
  heusler?: {
    template: string;
    elements: Record<string, string>;
    a: number;
    valenceElectrons: number;
    slaterPauling: number | null;
  };
  crystal?: {
    prototype: string;
    elements: Record<string, string>;
    a: number;
    density: number;
  };
  note?: string;
}

const KEY = 'af2s.chemistry.candidates.v1';
const EVENT = 'af2s-chem-candidates';
let cache: { raw: string | null; list: Candidate[] } = { raw: null, list: [] };

function read(): Candidate[] {
  if (typeof window === 'undefined') return [];
  try {
    const raw = window.localStorage.getItem(KEY);
    if (raw === cache.raw) return cache.list;
    const parsed = raw ? (JSON.parse(raw) as Candidate[]) : [];
    cache = { raw, list: Array.isArray(parsed) ? parsed : [] };
    return cache.list;
  } catch {
    return cache.list;
  }
}

function write(list: Candidate[]) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(list));
  } catch { /* storage full or blocked — the in-page list still works until reload */ }
  window.dispatchEvent(new Event(EVENT));
}

function subscribe(cb: () => void) {
  window.addEventListener(EVENT, cb);
  window.addEventListener('storage', cb);
  return () => { window.removeEventListener(EVENT, cb); window.removeEventListener('storage', cb); };
}
const EMPTY: Candidate[] = [];

export function useCandidates(): Candidate[] {
  return useSyncExternalStore(subscribe, read, () => EMPTY);
}
export function saveCandidate(c: Omit<Candidate, 'id' | 'savedAt'>): Candidate {
  const full: Candidate = { ...c, id: `c${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`, savedAt: new Date().toISOString() };
  write([full, ...read()]);
  return full;
}
export function deleteCandidate(id: string) { write(read().filter(c => c.id !== id)); }
export function renameCandidate(id: string, name: string) { write(read().map(c => (c.id === id ? { ...c, name } : c))); }

export function download(filename: string, text: string, mime = 'text/plain') {
  const url = URL.createObjectURL(new Blob([text], { type: mime }));
  const a = document.createElement('a');
  a.href = url; a.download = filename; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

export function candidatesToCsv(list: Candidate[]): string {
  const esc = (v: unknown) => `"${String(v ?? '').replace(/"/g, '""')}"`;
  const head = ['name', 'formula', 'kind', 'molar_mass_g_per_mol', 'charge_balance', 'model', 'tolerance_factor', 'octahedral_factor', 'a_estimate_A', 'saved_at', 'note'];
  const rows = list.map(c => [
    c.name, c.formula, c.kind, c.molarMass.toFixed(3), c.chargeStatus,
    c.perovskite?.model ?? '', c.perovskite?.tolerance?.toFixed(3) ?? '', c.perovskite?.octahedral?.toFixed(3) ?? '',
    c.perovskite?.a.toFixed(3) ?? '', c.savedAt, c.note ?? '',
  ].map(esc).join(','));
  return [head.join(','), ...rows].join('\n');
}
FILEEOF

write_file src/app/chemistry/page.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

interface Playground {
  slug: string; href: string; title: string; description: string; icon: string; topic: string; status: 'live' | 'coming';
}

// Add new chemistry playgrounds here. The topic filter is built from this list.
const PLAYGROUNDS: Playground[] = [
  { slug: 'periodic-table', href: '/chemistry/periodic-table', title: 'Periodic table', icon: '🧪', topic: 'Foundations', status: 'live',
    description: 'All 118 elements: electron configuration, oxidation states, electronegativity and mass. Click to explore, then send an element to the compound builder.' },
  { slug: 'compound-builder', href: '/chemistry/compound-builder', title: 'Compound builder', icon: '⚗️', topic: 'Foundations', status: 'live',
    description: 'Click elements to add them, set atom counts, and read off the formula, molar mass, mass percentages and a rule-based charge-balance check.' },
  { slug: 'perovskite-lab', href: '/chemistry/perovskite-lab', title: 'Perovskite lab', icon: '💎', topic: 'Materials', status: 'live',
    description: 'Assign A, B and X sites (ABX₃ or double A₂BB′X₆), get the Goldschmidt tolerance and octahedral factors, rotate the model, and export a CIF.' },
  { slug: 'heusler', href: '/chemistry/heusler', title: 'Heusler alloys', icon: '🔩', topic: 'Materials', status: 'live',
    description: 'Half-Heusler XYZ and full-Heusler X₂YZ (regular and inverse) with alternative site arrangements, valence-electron rules and a Slater–Pauling estimate.' },
  { slug: 'crystal-builder', href: '/chemistry/crystal-builder', title: 'Crystal builder', icon: '🔷', topic: 'Materials', status: 'live',
    description: 'Pick a cubic prototype (rocksalt, CsCl, zincblende, fluorite, fcc, bcc, diamond…), assign elements and read computed coordination, density and packing.' },
  { slug: 'organic', href: '#', title: 'Organic molecules', icon: '🧬', topic: 'Organic', status: 'coming',
    description: 'Connect atoms with bonds, explore functional groups, and compare isomers that share a formula.' },
  { slug: 'nuclear', href: '/chemistry/nuclear', title: 'Nuclear playground', icon: '☢️', topic: 'Nuclear', status: 'live',
    description: 'Choose a nuclide, test decay modes against conservation laws, follow decay chains, run the half-life law and check nuclear equations.' },
];
const TOPICS = ['All', ...Array.from(new Set(PLAYGROUNDS.map(p => p.topic)))];

export default function ChemistryHub() {
  const [topic, setTopic] = useState('All');
  const visible = topic === 'All' ? PLAYGROUNDS : PLAYGROUNDS.filter(p => p.topic === topic);
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 py-10 sm:px-6 sm:py-14">
            <div className="max-w-2xl">
              <span className="mb-3 inline-block rounded-full bg-emerald-50 px-3 py-0.5 text-xs font-medium text-emerald-700">New · Chemistry &amp; Materials</span>
              <h1 className="mb-3 text-2xl font-semibold leading-tight text-gray-900 sm:text-3xl">Chemistry &amp; Materials Playground</h1>
              <p className="text-sm leading-relaxed text-gray-500 sm:text-base">
                Build compositions and crystal models, then see what the rules say about them. Everything you build is a
                <span className="font-medium text-gray-700"> candidate</span> — the playground never claims a compound exists just because you can assemble its formula.
              </p>
              <Link href="/simulations" className="mt-4 inline-flex items-center gap-1.5 rounded-full border border-gray-200 bg-white px-3 py-1 text-xs font-medium text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700">
                Looking for physics? Physics simulations →
              </Link>
            </div>
          </div>
        </section>

        <section className="mx-auto max-w-7xl px-4 py-8 sm:px-6">
          <div className="scrollbar-hide mb-6 flex gap-2 overflow-x-auto pb-2">
            {TOPICS.map(t => {
              const n = t === 'All' ? PLAYGROUNDS.length : PLAYGROUNDS.filter(p => p.topic === t).length;
              const active = topic === t;
              return (
                <button key={t} onClick={() => setTopic(t)}
                  className={`flex shrink-0 items-center gap-1.5 whitespace-nowrap rounded-full border px-4 py-1.5 text-xs font-medium transition ${active ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'}`}>
                  {t}<span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>{n}</span>
                </button>
              );
            })}
          </div>

          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {visible.map(p => (
              <div key={p.slug} className={`group relative overflow-hidden rounded-2xl border bg-white transition ${p.status === 'live' ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md' : 'border-gray-100 opacity-70'}`}>
                {p.status === 'live' ? (
                  <div className="absolute right-3 top-3 flex items-center gap-1"><span className="h-1.5 w-1.5 animate-pulse rounded-full bg-emerald-500" /><span className="text-[10px] font-medium text-emerald-600">Live</span></div>
                ) : (
                  <span className="absolute right-3 top-3 rounded-full bg-gray-100 px-1.5 py-0.5 text-[10px] font-medium text-gray-400">Coming soon</span>
                )}
                <Link href={p.status === 'live' ? p.href : '#'} className={p.status !== 'live' ? 'pointer-events-none' : ''} aria-disabled={p.status !== 'live'}>
                  <div className="p-5">
                    <div className="mb-3 flex items-center gap-2"><span className="text-2xl">{p.icon}</span><span className="text-[10px] font-medium uppercase tracking-wide text-gray-400">{p.topic}</span></div>
                    <h2 className="mb-1.5 text-sm font-semibold text-gray-900 transition group-hover:text-indigo-700">{p.title}</h2>
                    <p className="text-xs leading-relaxed text-gray-500">{p.description}</p>
                  </div>
                </Link>
              </div>
            ))}
          </div>

          <div className="mt-8 rounded-2xl border border-gray-200 bg-white p-5">
            <h2 className="text-sm font-semibold text-gray-900">Four levels of evidence</h2>
            <dl className="mt-3 grid gap-3 text-xs sm:grid-cols-2 lg:grid-cols-4">
              {[
                ['User-built candidate', 'A composition or structure you proposed.'],
                ['Rule-based assessment', 'Checks such as charge balance or geometric factors.'],
                ['Database-supported material', 'A reported compound or structure, with its source.'],
                ['Calculated result', 'A property from a stated computational method.'],
              ].map(([k, v]) => (
                <div key={k}><dt className="font-medium text-gray-900">{k}</dt><dd className="mt-0.5 text-gray-500">{v}</dd></div>
              ))}
            </dl>
            <p className="mt-3 text-[11px] text-gray-400">This first release produces the first two. Database look-ups and calculations are not built in yet, and results are labelled accordingly.</p>
          </div>
        </section>
      </main>
    </>
  );
}
FILEEOF

write_file src/app/chemistry/crystal-builder/page.tsx << 'FILEEOF'
'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass, reduce } from '@/lib/chemistry/compound';
import { withBoundaryImages, fmtCharge, type Site } from '@/lib/chemistry/perovskite';
import {
  PROTOTYPES, PROTO_ORDER, analyseCrystal, cellAtoms, crystalCif, geometry, type ProtoId, type Role,
} from '@/lib/chemistry/crystal';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const ROLE_COLOR: Record<Role, string> = { A: '#f59e0b', X: '#818cf8' };
type Els = Record<Role, string>;

interface Preset { label: string; proto: ProtoId; el: Els; a: number; note: string }
const PRESETS: Preset[] = [
  { label: 'NaCl', proto: 'rocksalt', el: { A: 'Na', X: 'Cl' }, a: 5.64, note: 'The textbook rocksalt structure; note the computed density against the ≈ 2.16 g/cm³ usually quoted.' },
  { label: 'MgO', proto: 'rocksalt', el: { A: 'Mg', X: 'O' }, a: 4.21, note: 'Rocksalt oxide.' },
  { label: 'CsCl', proto: 'cscl', el: { A: 'Cs', X: 'Cl' }, a: 4.12, note: 'Eight-fold coordination: the large Cs⁺ ion gives a radius ratio near 0.92.' },
  { label: 'ZnS', proto: 'zincblende', el: { A: 'Zn', X: 'S' }, a: 5.41, note: 'Zincblende (sphalerite) form of ZnS; ZnS also exists as hexagonal wurtzite, which this builder does not draw.' },
  { label: 'GaAs', proto: 'zincblende', el: { A: 'Ga', X: 'As' }, a: 5.65, note: 'A covalent III–V semiconductor in the zincblende structure — the radius-ratio rule is for ionic solids, so ignore it here.' },
  { label: 'CaF₂', proto: 'fluorite', el: { A: 'Ca', X: 'F' }, a: 5.46, note: 'Fluorite: Ca²⁺ is 8-coordinate, F⁻ 4-coordinate.' },
  { label: 'Li₂O', proto: 'fluorite', el: { A: 'O', X: 'Li' }, a: 4.62, note: 'Antifluorite (roles swapped). A good example where the radius-ratio rule predicts octahedral Li⁺ but the real structure is tetrahedral.' },
  { label: 'Cu', proto: 'fcc', el: { A: 'Cu', X: 'Cu' }, a: 3.61, note: 'Close-packed fcc metal.' },
  { label: 'Fe (bcc)', proto: 'bcc', el: { A: 'Fe', X: 'Fe' }, a: 2.87, note: 'Room-temperature α-iron is bcc.' },
  { label: 'Si', proto: 'diamond', el: { A: 'Si', X: 'Si' }, a: 5.43, note: 'Diamond cubic silicon.' },
  { label: 'Po (sc)', proto: 'sc', el: { A: 'Po', X: 'Po' }, a: 3.35, note: 'α-polonium is the rare example of a simple cubic element.' },
  { label: 'Cu₃Au', proto: 'cu3au', el: { A: 'Au', X: 'Cu' }, a: 3.75, note: 'An ordered fcc alloy at low temperature; it disorders on heating.' },
];

function ElementSelect({ label, color, value, onChange }: { label: string; color: string; value: string; onChange: (s: string) => void }) {
  return (
    <div className="min-w-0 rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500"><span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: color }} />{label}</div>
      <select value={value} onChange={e => onChange(e.target.value)} className="mt-2 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={label}>
        {ELEMENTS.filter(x => x.z <= 103).map(x => <option key={x.symbol} value={x.symbol}>{x.symbol} — {x.name}</option>)}
      </select>
    </div>
  );
}

export default function CrystalBuilderPage() {
  const [pid, setPid] = useState<ProtoId>(PRESETS[0].proto);
  const [el, setEl] = useState<Els>(PRESETS[0].el);
  const [a, setA] = useState(PRESETS[0].a);
  const [note, setNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [saved, setSaved] = useState(false);

  const proto = PROTOTYPES[pid];
  const binary = proto.roles.length === 2;
  const effEl: Els = binary ? el : { A: el.A, X: el.A };
  const geo = geometry(proto);
  const rep = analyseCrystal(proto, effEl, a);

  const atoms = useMemo(() => withBoundaryImages(cellAtoms(proto).map(x => ({ site: x.site, frac: x.frac })), n), [proto, n]);
  const styles = (() => {
    const out: Partial<Record<Site, SiteStyle>> = {};
    proto.sublattices.forEach(s => {
      const sym = effEl[s.role];
      out[s.site] = { label: sym, color: ROLE_COLOR[s.role], radius: 0.075 + 0.012 * BY_SYMBOL[sym].period };
    });
    return out;
  })();
  const siteNames = Object.fromEntries(proto.sublattices.map(s => [s.site, s.name])) as Partial<Record<Site, string>>;

  const loadPreset = (p: Preset) => { setPid(p.proto); setEl(p.el); setA(p.a); setNote(p.note); setSaved(false); };
  const setRole = (r: Role, s: string) => { setEl(e => ({ ...e, [r]: s })); setNote(null); setSaved(false); };
  const changeProto = (id: ProtoId) => { setPid(id); setNote(null); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: `${rep.formula} (${proto.label.split(' (')[0]})`, kind: 'crystal', formula: rep.formula, composition: reduce(rep.composition),
      molarMass: molarMass(reduce(rep.composition)), chargeStatus: rep.charge?.status ?? 'single element',
      crystal: { prototype: pid, elements: effEl, a, density: rep.density }, note: note ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.crystal) { setPid(c.crystal.prototype as ProtoId); setEl(c.crystal.elements as Els); setA(c.crystal.a); setNote(c.note ?? null); }
  };

  const groups = ['Elements', 'AX compounds', 'AX₂ compounds', 'Ordered alloys'] as const;
  const rr = rep.radius;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Crystal builder</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Choose a cubic prototype, assign elements and a lattice parameter, and read off coordination, density and packing. These are <span className="font-medium text-gray-700">computed from the geometry</span>; they don’t show that a material adopts that structure.</p>

          <div className="mb-4 flex flex-wrap gap-2">
            {PRESETS.map(p => <button key={p.label} type="button" onClick={() => loadPreset(p)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>)}
          </div>
          {note && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{note} <span className="opacity-70">Lattice parameters are approximate literature values — check the primary source before citing.</span></p>}

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} siteNames={siteNames} bondDist={geo.nn} bondMode="nn" sizeScale={0.85} sizeNote="atom size shows period only" showBonds={bonds} showCell={cell} showA />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />Nearest-neighbour bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{proto.label} · {proto.spaceGroup}. {proto.note}</p>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <h2 className="mb-3 text-sm font-semibold text-gray-900">Compare the prototypes <span className="font-normal text-gray-400">(computed from each geometry)</span></h2>
                <div className="overflow-x-auto">
                  <table className="w-full min-w-[460px] text-left text-xs">
                    <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 pr-2 font-medium">Prototype</th><th className="pr-2 font-medium">Atoms / cell</th><th className="pr-2 font-medium">Type</th><th className="pr-2 font-medium">Coordination</th><th className="font-medium">NN dist.</th></tr></thead>
                    <tbody>
                      {PROTO_ORDER.map(id => {
                        const g = geometry(PROTOTYPES[id]);
                        return (
                          <tr key={id} className={`border-t border-gray-100 ${id === pid ? 'bg-indigo-50/60' : ''}`}>
                            <td className="py-1.5 pr-2"><button type="button" onClick={() => changeProto(id)} className="text-left font-medium text-gray-900 hover:text-indigo-700">{PROTOTYPES[id].label}</button></td>
                            <td className="pr-2 text-gray-700">{g.atomsPerCell}</td>
                            <td className="pr-2 text-gray-700">{g.stoich}</td>
                            <td className="pr-2 text-gray-700">{g.coordination.map(c => `${c.role} ${c.total}`).join(' · ')}</td>
                            <td className="text-gray-700">{g.nn.toFixed(3)} a</td>
                          </tr>
                        );
                      })}
                    </tbody>
                  </table>
                </div>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <label className="text-[11px] font-medium uppercase tracking-wide text-gray-400" htmlFor="proto">Prototype</label>
                <select id="proto" value={pid} onChange={e => changeProto(e.target.value as ProtoId)} className="mt-1 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  {groups.map(g => <optgroup key={g} label={g}>{PROTO_ORDER.filter(id => PROTOTYPES[id].group === g).map(id => <option key={id} value={id}>{PROTOTYPES[id].label}</option>)}</optgroup>)}
                </select>

                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  <ElementSelect label={binary ? 'A element' : 'Element'} color={ROLE_COLOR.A} value={el.A} onChange={s => setRole('A', s)} />
                  {binary && <ElementSelect label="X element" color={ROLE_COLOR.X} value={el.X} onChange={s => setRole('X', s)} />}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{rep.formula}</div>
                <div className="text-xs text-gray-500">{geo.atomsPerCell} atoms per cubic cell · {geo.stoich === 'A' ? 'one element' : `AX type ${geo.stoich}`}</div>

                <div className="mt-3 flex items-center gap-2 text-xs">
                  <label htmlFor="a" className="font-medium text-gray-500">Lattice parameter a (Å)</label>
                  <input id="a" type="number" step={0.01} min={1.5} max={12} value={a} onChange={e => { setA(Number(e.target.value) || 5); setSaved(false); }} className="h-8 w-24 rounded-md border border-gray-200 px-2 text-sm" />
                </div>
                <p className="mt-1 text-[11px] text-gray-400">Preset values are approximate literature numbers. For a new combination this is a placeholder you set — not a prediction.</p>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  {geo.coordination.filter(c => binary || c.role === 'A').map(c => (
                    <div key={c.role} className="flex justify-between py-1.5"><dt className="text-gray-500">Coordination of {binary ? `${effEl[c.role]} (${c.role})` : effEl.A}</dt><dd className="font-medium text-gray-900">{c.total}{c.like > 0 && c.unlike > 0 ? ` (${c.unlike} unlike + ${c.like} like)` : ''}</dd></div>
                  ))}
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Nearest-neighbour distance</dt><dd className="font-medium text-gray-900">{rep.nnAngstrom.toFixed(3)} Å</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Density</dt><dd className="font-medium text-gray-900">{rep.density.toFixed(3)} g/cm³</dd></div>
                  {rep.packing != null && <div className="flex justify-between py-1.5"><dt className="text-gray-500">Packing fraction (ideal hard spheres)</dt><dd className="font-medium text-gray-900">{rep.packing.toFixed(4)}</dd></div>}
                </dl>

                {rep.charge && (
                  <div className={`mt-3 rounded-lg px-3 py-2 text-[11px] leading-relaxed ${rep.charge.status === 'balanced' ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                    <span className="font-medium">Charge balance.</span> {rep.charge.message}
                    {rep.charge.solutions[0] && <span className="mt-0.5 block font-mono">{Object.entries(rep.charge.solutions[0].states).map(([s, q]) => `${s}${fmtCharge(q)}`).join('  ')}</span>}
                  </div>
                )}
                {rr && (
                  <div className={`mt-2 rounded-lg px-3 py-2 text-[11px] leading-relaxed ${rr.consistent ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                    <span className="font-medium">Radius-ratio rule.</span> r(cation)/r(anion) = {rr.cationRadius.toFixed(2)}/{rr.anionRadius.toFixed(2)} = {rr.ratio.toFixed(3)}, which suggests {rr.expectedCN}-fold coordination ({rr.expectedText}); this prototype has {rr.actualCN}. {rr.consistent ? 'Consistent.' : 'Not consistent — the rule has many exceptions (covalent character, polarisation), so this does not rule the structure out.'}
                  </div>
                )}

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${rep.formula}-${pid}-proposed.cif`, crystalCif(proto, effEl, a, rep.formula), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(rep.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: rep.charge ? (rep.charge.status === 'balanced' ? 'Charges can balance' : rep.charge.message) + (rr ? `; radius ratio ${rr.ratio.toFixed(2)} ${rr.consistent ? 'matches' : 'does not match'} this prototype.` : '.') : 'Single element — no charge check; geometry only.', ok: rep.charge ? (rep.charge.status === 'balanced' && (rr ? rr.consistent : true)) : null }}
                extra={proto.label}
                calculated={{ state: 'warn', text: 'Only simple geometric quantities (coordination, density, packing) from the prototype and your lattice parameter. No energies or relaxation.' }}
                database={{ state: 'no', text: 'Not checked. Compare with a structure database (e.g. ICSD, Crystallography Open Database, Materials Project) before saying a compound adopts this structure.' }}
              />
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
FILEEOF

echo ""
echo "Done. npm run dev, then open /chemistry/crystal-builder"
