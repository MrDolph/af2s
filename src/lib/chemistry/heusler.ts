// Heusler templates: half-Heusler XYZ (F-43m) and full-Heusler X2YZ (regular L2₁ and inverse XA).
//
// All structures are described on the four interpenetrating fcc sublattices of the
// conventional cubic cell:  A (0,0,0)=4a   B (¼,¼,¼)=4c   C (½,½,½)=4b   D (¾,¾,¾)=4d.
// Everything here is a *rule-based assessment of a user-built candidate*: valence-electron
// counting and Slater–Pauling are screening rules, not calculations.

import { BY_SYMBOL } from './elements';
import { formulaPlain, subscript, type Composition } from './compound';
import type { Atom, Site } from './perovskite';

export type Role = 'X' | 'Y' | 'Z';
export type Sub = 'A' | 'B' | 'C' | 'D';
export type TemplateId = 'half-X4c' | 'half-Y4c' | 'half-Z4c' | 'full-L21' | 'full-inverse';

export interface TemplateDef {
  id: TemplateId;
  family: 'half' | 'full';
  label: string;
  spaceGroup: string;
  note: string;
  layout: Record<Sub, Role | null>;
}

export const SUB_SITE: Record<Sub, Site> = { A: 'A', B: 'B', C: 'B2', D: 'X' }; // mapped onto the viewer's four site keys
export const SUB_NAME: Record<Sub, string> = { A: '4a (0,0,0)', B: '4c (¼,¼,¼)', C: '4b (½,½,½)', D: '4d (¾,¾,¾)' };

export const TEMPLATES: Record<TemplateId, TemplateDef> = {
  'half-X4c': {
    id: 'half-X4c', family: 'half', label: 'Half-Heusler XYZ · X on 4c', spaceGroup: 'F-43m (216)',
    note: 'Y and Z form a rock-salt lattice (4a/4b); X fills one tetrahedral hole (4c); the other (4d) is empty.',
    layout: { A: 'Y', B: 'X', C: 'Z', D: null },
  },
  'half-Y4c': {
    id: 'half-Y4c', family: 'half', label: 'Half-Heusler XYZ · Y on 4c', spaceGroup: 'F-43m (216)',
    note: 'Same prototype with the roles permuted: X and Z form the rock-salt lattice and Y sits on 4c.',
    layout: { A: 'X', B: 'Y', C: 'Z', D: null },
  },
  'half-Z4c': {
    id: 'half-Z4c', family: 'half', label: 'Half-Heusler XYZ · Z on 4c', spaceGroup: 'F-43m (216)',
    note: 'Same prototype with the roles permuted: X and Y form the rock-salt lattice and Z sits on 4c.',
    layout: { A: 'X', B: 'Z', C: 'Y', D: null },
  },
  'full-L21': {
    id: 'full-L21', family: 'full', label: 'Full-Heusler X₂YZ · regular (L2₁)', spaceGroup: 'Fm-3m (225)',
    note: 'X occupies both tetrahedral sites (4c and 4d), Y sits on 4b and Z on 4a.',
    layout: { A: 'Z', B: 'X', C: 'Y', D: 'X' },
  },
  'full-inverse': {
    id: 'full-inverse', family: 'full', label: 'Full-Heusler X₂YZ · inverse (XA)', spaceGroup: 'F-43m (216)',
    note: 'The two X atoms sit on neighbouring sites (4a and 4c), Y on 4b and Z on 4d. Often discussed when X is earlier in the series than Y.',
    layout: { A: 'X', B: 'X', C: 'Y', D: 'Z' },
  },
};

const FCC: [number, number, number][] = [[0, 0, 0], [0, 0.5, 0.5], [0.5, 0, 0.5], [0.5, 0.5, 0]];
const OFFSET: Record<Sub, number> = { A: 0, B: 0.25, C: 0.5, D: 0.75 };
const wrap = (v: number) => Math.round((((v % 1) + 1) % 1) * 1e6) / 1e6;

/** Atoms of one conventional cell, tagged with their sublattice (as a viewer Site key). */
export function heuslerAtoms(t: TemplateDef): (Atom & { sub: Sub; role: Role })[] {
  const out: (Atom & { sub: Sub; role: Role })[] = [];
  (Object.keys(OFFSET) as Sub[]).forEach(sub => {
    const role = t.layout[sub];
    if (!role) return;
    for (const f of FCC) {
      const o = OFFSET[sub];
      out.push({ site: SUB_SITE[sub], sub, role, frac: [wrap(f[0] + o), wrap(f[1] + o), wrap(f[2] + o)] });
    }
  });
  return out;
}

export const NN_DIST = Math.sqrt(3) / 4; // nearest-neighbour distance in units of a

/** Valence electrons counted the Heusler way: s + d for groups 1–12, s + p for groups 13–18 (group − 10). */
export function valenceElectrons(symbol: string): { n: number; approx: boolean } {
  const e = BY_SYMBOL[symbol];
  if (!e || e.group == null) return { n: 3, approx: true }; // f-block: trivalent assumption
  return { n: e.group <= 12 ? e.group : e.group - 10, approx: false };
}

export function roleCount(t: TemplateDef, role: Role): number {
  return (Object.values(t.layout) as (Role | null)[]).filter(r => r === role).length;
}

export interface HeuslerReport {
  composition: Composition;
  /** Plain formula in X, Y, Z order (e.g. Co2MnSi), the way Heuslers are conventionally written. */
  formula: string;
  /** Same with subscripts. */
  display: string;
  nv: number;
  approx: boolean;
  checks: { label: string; text: string; tone: 'good' | 'info' | 'warn' }[];
  /** Slater–Pauling estimate, μB per formula unit (signed), valid only for half-metallic ferromagnets. */
  moment: number | null;
}

export function analyseHeusler(t: TemplateDef, el: Record<Role, string>): HeuslerReport {
  const composition: Composition = {};
  let nv = 0, approx = false;
  (['X', 'Y', 'Z'] as Role[]).forEach(r => {
    const n = roleCount(t, r);
    if (!n) return;
    composition[el[r]] = (composition[el[r]] ?? 0) + n;
    const v = valenceElectrons(el[r]);
    nv += v.n * n;
    approx = approx || v.approx;
  });
  const half = t.family === 'half';
  const closed = half ? 18 : 24;
  const checks: HeuslerReport['checks'] = [];

  if (half) {
    if (nv === 18) checks.push({ label: '18-electron rule', tone: 'good', text: 'N_v = 18: the closed-shell count typical of non-magnetic, semiconducting half-Heuslers (e.g. TiNiSn).' });
    else if (nv === 8) checks.push({ label: '8-electron rule', tone: 'good', text: 'N_v = 8: the s–p closed-shell count of the 8-electron half-Heuslers (e.g. LiMgN-type).' });
    else checks.push({ label: 'Electron count', tone: 'info', text: `N_v = ${nv}. Not a closed-shell count (8 or 18), so a gap is not expected from counting alone.` });
  } else {
    if (nv === 24) checks.push({ label: '24-electron count', tone: 'good', text: 'N_v = 24: the closed-shell count of non-magnetic full-Heuslers (e.g. Fe₂VAl).' });
    else checks.push({ label: 'Electron count', tone: 'info', text: `N_v = ${nv}. Not the 24-electron closed-shell count.` });
  }

  let moment: number | null = null;
  if (nv !== closed) {
    moment = nv - closed;
    const mag = Math.abs(moment);
    checks.push({
      label: 'Slater–Pauling',
      tone: 'info',
      text: `M ≈ N_v − ${closed} = ${moment > 0 ? '+' : ''}${moment} μB per formula unit (|M| = ${mag}). Only meaningful if the compound is a half-metallic ferromagnet or ferrimagnet — an upper-level screen, not a prediction.`,
    });
  }
  if (!half && t.id === 'full-inverse') {
    checks.push({ label: 'Arrangement', tone: 'info', text: 'Inverse and regular arrangements usually differ in energy by a modest amount; which one a given X₂YZ prefers has to be tested by calculation.' });
  }
  if (new Set(Object.values(el).filter(Boolean)).size < (half ? 3 : 3) && (el.X === el.Y || el.Y === el.Z || el.X === el.Z)) {
    checks.push({ label: 'Repeated element', tone: 'warn', text: 'Two roles use the same element, so this is a different composition from a true ternary Heusler.' });
  }
  if (approx) checks.push({ label: 'f-block', tone: 'warn', text: 'An f-block element is counted as trivalent; real f-electron behaviour is not captured.' });

  const used = (['X', 'Y', 'Z'] as Role[]).filter(r => roleCount(t, r) > 0);
  const distinct = new Set(used.map(r => el[r])).size === used.length;
  const formula = distinct ? used.map(r => `${el[r]}${roleCount(t, r) === 1 ? '' : roleCount(t, r)}`).join('') : formulaPlain(composition);
  const display = distinct ? used.map(r => `${el[r]}${subscript(roleCount(t, r))}`).join('') : formula;
  return { composition, formula, display, nv, approx, checks, moment };
}

export function heuslerCif(opts: { title: string; a: number; t: TemplateDef; el: Record<Role, string> }): string {
  const { title, a, t, el } = opts;
  const counters: Record<string, number> = {};
  const rows = heuslerAtoms(t).map(at => {
    const s = el[at.role];
    counters[s] = (counters[s] ?? 0) + 1;
    return `${s}${counters[s]} ${s} ${at.frac.map(v => v.toFixed(5)).join(' ')} 1.0`;
  });
  return [
    `data_${title.replace(/[^A-Za-z0-9_]/g, '_')}`,
    '# PROPOSED MODEL generated by A-Factor STEM Studio (Chemistry playground).',
    `# Template: ${t.label}. Lattice parameter was set by the user; geometry is NOT relaxed.`,
    '# Not evidence that this material exists, orders this way, or is stable.',
    `_cell_length_a ${a.toFixed(4)}`, `_cell_length_b ${a.toFixed(4)}`, `_cell_length_c ${a.toFixed(4)}`,
    '_cell_angle_alpha 90', '_cell_angle_beta 90', '_cell_angle_gamma 90',
    "_symmetry_space_group_name_H-M 'P 1'", '_symmetry_Int_Tables_number 1',
    'loop_', '_symmetry_equiv_pos_as_xyz', "'x, y, z'",
    'loop_', '_atom_site_label', '_atom_site_type_symbol',
    '_atom_site_fract_x', '_atom_site_fract_y', '_atom_site_fract_z', '_atom_site_occupancy',
    ...rows, '',
  ].join('\n');
}

export function heuslerDensity(t: TemplateDef, a: number, el: Record<Role, string>): number {
  const mass = heuslerAtoms(t).reduce((m, at) => m + BY_SYMBOL[el[at.role]].mass, 0);
  return (mass / 6.02214076e23) / (Math.pow(a, 3) * 1e-24);
}
