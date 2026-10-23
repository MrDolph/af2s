// Nuclear playground logic: nuclide labels, decay rules, conservation checking,
// a small bundled reference table, and decay-law maths.
//
// Two very different kinds of statement live here and the UI keeps them apart:
//  • RULES — conservation of nucleon number, charge and lepton number. Pure bookkeeping:
//    a balanced equation is allowed by these laws, but may still be energetically
//    forbidden (Q < 0) or never observed.
//  • REFERENCE DATA — half-lives and decay modes for ~60 well-known nuclides, bundled by
//    hand from standard tables (rounded). Anything not in the table has NO bundled data.

import { ELEMENTS, BY_SYMBOL } from './elements';

export const SEC = { us: 1e-6, ms: 1e-3, s: 1, min: 60, h: 3600, d: 86400, y: 3.15576e7 } as const;
export type TimeUnit = keyof typeof SEC;

const SUP = '⁰¹²³⁴⁵⁶⁷⁸⁹';
export const sup = (n: number) => String(n).split('').map(d => SUP[Number(d)]).join('');
export const symbolOf = (z: number): string => (z === 0 ? 'n' : ELEMENTS[z - 1]?.symbol ?? `Z${z}`);
export const nameOf = (z: number): string => (z === 0 ? 'Neutron' : ELEMENTS[z - 1]?.name ?? `Element ${z}`);
export const label = (z: number, a: number) => `${sup(a)}${symbolOf(z)}`;
export const plainLabel = (z: number, a: number) => `${symbolOf(z)}-${a}`;

// ── Species and conservation ────────────────────────────────────────────────
export interface Species {
  coef: number;
  text: string;
  A: number; // nucleon (baryon) number
  Z: number; // charge in units of e (nuclear charge for nuclides)
  L: number; // lepton number
}

type PId = 'n' | 'p' | 'alpha' | 'e-' | 'e+' | 'nu' | 'nubar' | 'gamma';
const P: Record<PId, Omit<Species, 'coef'>> = {
  n: { text: 'n', A: 1, Z: 0, L: 0 },
  p: { text: 'p', A: 1, Z: 1, L: 0 },
  alpha: { text: 'α', A: 4, Z: 2, L: 0 },
  'e-': { text: 'e⁻', A: 0, Z: -1, L: 1 },
  'e+': { text: 'e⁺', A: 0, Z: 1, L: -1 },
  nu: { text: 'ν', A: 0, Z: 0, L: 1 },
  nubar: { text: 'ν̄', A: 0, Z: 0, L: -1 },
  gamma: { text: 'γ', A: 0, Z: 0, L: 0 },
};
export const particle = (id: PId, coef = 1): Species => ({ coef, ...P[id] });
export const nuclide = (z: number, a: number, coef = 1, star = false): Species =>
  ({ coef, text: `${label(z, a)}${star ? '*' : ''}`, A: a, Z: z, L: 0 });

export interface Balance {
  left: { A: number; Z: number; L: number };
  right: { A: number; Z: number; L: number };
  ok: { A: boolean; Z: boolean; L: boolean };
  balanced: boolean;
}

export function balance(left: Species[], right: Species[]): Balance {
  const sum = (s: Species[]) => s.reduce((t, x) => ({ A: t.A + x.coef * x.A, Z: t.Z + x.coef * x.Z, L: t.L + x.coef * x.L }), { A: 0, Z: 0, L: 0 });
  const l = sum(left), r = sum(right);
  const ok = { A: l.A === r.A, Z: l.Z === r.Z, L: l.L === r.L };
  return { left: l, right: r, ok, balanced: ok.A && ok.Z && ok.L };
}

export const sideText = (s: Species[]) => s.map(x => `${x.coef > 1 ? x.coef + ' ' : ''}${x.text}`).join(' + ');

// ── Decay modes ──────────────────────────────────────────────────────────────
export type Mode = 'A' | 'B-' | 'B+' | 'EC' | 'P' | 'N' | 'G';
export const MODE_LABEL: Record<Mode, string> = {
  A: 'α decay', 'B-': 'β⁻ decay', 'B+': 'β⁺ decay', EC: 'Electron capture', P: 'Proton emission', N: 'Neutron emission', G: 'Gamma emission (isomeric)',
};
export const MODE_SHORT: Record<Mode, string> = { A: 'α', 'B-': 'β⁻', 'B+': 'β⁺', EC: 'EC', P: 'p', N: 'n', G: 'γ' };

export interface DecayResult {
  mode: Mode;
  daughter: { z: number; a: number } | null;
  left: Species[];
  right: Species[];
  bal: Balance;
  issues: string[]; // reasons the daughter is not a valid nuclide
}

export function applyDecay(z: number, a: number, mode: Mode): DecayResult {
  const par = nuclide(z, a, 1, mode === 'G');
  let dz = z, da = a;
  let left: Species[] = [par];
  let extra: Species[] = [];
  switch (mode) {
    case 'A': dz = z - 2; da = a - 4; extra = [particle('alpha')]; break;
    case 'B-': dz = z + 1; extra = [particle('e-'), particle('nubar')]; break;
    case 'B+': dz = z - 1; extra = [particle('e+'), particle('nu')]; break;
    case 'EC': dz = z - 1; left = [par, particle('e-')]; extra = [particle('nu')]; break;
    case 'P': dz = z - 1; da = a - 1; extra = [particle('p')]; break;
    case 'N': da = a - 1; extra = [particle('n')]; break;
    case 'G': extra = [particle('gamma')]; break;
  }
  const issues: string[] = [];
  if (da < 1) issues.push('Mass number would drop below 1.');
  if (dz < 0) issues.push('Atomic number would be negative.');
  if (dz > da) issues.push('The daughter would have more protons than nucleons.');
  if (dz === 0 && da > 1) issues.push('A daughter with Z = 0 and A > 1 is not a bound nucleus.');
  if (dz > 118) issues.push('Daughter is beyond the known elements.');
  const valid = issues.length === 0;
  const right = [nuclide(dz, da), ...extra];
  return { mode, daughter: valid ? { z: dz, a: da } : null, left, right, bal: balance(left, right), issues };
}

// ── Rule-of-thumb stability hints (NOT data) ────────────────────────────────
/** Approximate β-stability line (semi-empirical valley): Z ≈ A / (1.98 + 0.0155 A^(2/3)). */
export const valleyZ = (a: number) => a / (1.98 + 0.0155 * Math.pow(a, 2 / 3));

export function hints(z: number, a: number): { zs: number; delta: number; lines: string[] } {
  const zs = valleyZ(a);
  const delta = z - zs;
  const lines: string[] = [];
  if (z === 0) lines.push('A free neutron is unstable: it β⁻-decays to a proton.');
  else if (delta < -0.9) lines.push('Neutron-rich for this mass number (below the stability line) — β⁻ decay is the usual way to move toward it.');
  else if (delta > 0.9) lines.push('Proton-rich for this mass number (above the stability line) — β⁺ decay or electron capture is the usual way to move toward it.');
  else lines.push('Close to the stability line for this mass number, so a stable or long-lived nuclide is plausible. Nothing guarantees it.');
  if (z >= 83 && a >= 200) lines.push('Heavy nuclei beyond Pb tend to shed mass by α decay (and some by spontaneous fission).');
  if (z <= 2 && a > 4 && z > 0) lines.push('Very light, very neutron-rich or proton-rich systems are typically extremely short-lived.');
  return { zs, delta, lines };
}

// ── Reference table (rounded; verify before quoting) ─────────────────────────
export interface RefNuclide {
  z: number; a: number;
  /** Half-life in seconds; null = stable (or observationally stable). */
  t: number | null;
  /** Decay modes with approximate branching percentages, dominant first. */
  modes: { mode: Mode; pct?: number }[];
  note?: string;
}

const Y = SEC.y, D = SEC.d, H = SEC.h, M = SEC.min;
const st = (z: number, a: number, note?: string): RefNuclide => ({ z, a, t: null, modes: [], note });
const r = (z: number, a: number, t: number, modes: [Mode, number?][], note?: string): RefNuclide =>
  ({ z, a, t, modes: modes.map(([mode, pct]) => ({ mode, pct })), note });

export const REFERENCE: RefNuclide[] = [
  st(1, 1), st(1, 2, 'Deuterium'), st(2, 3), st(2, 4), st(3, 7), st(6, 12), st(6, 13), st(7, 14), st(8, 16), st(10, 20), st(13, 27), st(14, 28), st(20, 40), st(26, 56),
  st(82, 206, 'End of the uranium-238 series'), st(82, 207), st(82, 208, 'Observationally stable'),
  r(0, 1, 609, [['B-']], 'Free neutron (mean lifetime ≈ 878 s)'),
  r(1, 3, 12.32 * Y, [['B-']], 'Tritium'),
  r(2, 6, 0.8067, [['B-']]),
  r(3, 8, 0.8399, [['B-']]),
  r(4, 7, 53.22 * D, [['EC']]),
  r(4, 8, 8.19e-17, [['A']], 'Splits into two α particles'),
  r(5, 12, 0.0202, [['B-']]),
  r(6, 11, 20.364 * M, [['B+']], 'PET isotope'),
  r(6, 14, 5730 * Y, [['B-']], 'Radiocarbon dating'),
  r(7, 13, 9.965 * M, [['B+']], 'PET isotope'),
  r(7, 16, 7.13, [['B-']]),
  r(8, 15, 122.24, [['B+']], 'PET isotope'),
  r(9, 18, 109.77 * M, [['B+', 97], ['EC', 3]], 'PET isotope (FDG)'),
  r(11, 22, 2.602 * Y, [['B+', 90], ['EC', 10]]),
  r(11, 24, 14.997 * H, [['B-']]),
  r(15, 32, 14.268 * D, [['B-']]),
  r(16, 35, 87.4 * D, [['B-']]),
  r(17, 36, 3.01e5 * Y, [['B-', 98], ['EC', 2]]),
  r(18, 41, 1.83 * H, [['B-']]),
  r(19, 40, 1.248e9 * Y, [['B-', 89], ['EC', 11]], 'Branches to Ca-40 (β⁻) and Ar-40 (EC / β⁺)'),
  r(24, 51, 27.7 * D, [['EC']]),
  r(26, 59, 44.5 * D, [['B-']]),
  r(27, 57, 271.7 * D, [['EC']]),
  r(27, 60, 5.271 * Y, [['B-']], 'Radiotherapy source'),
  r(31, 67, 3.26 * D, [['EC']]),
  r(31, 68, 67.7 * M, [['B+', 89], ['EC', 11]]),
  r(34, 75, 119.8 * D, [['EC']]),
  r(36, 85, 10.76 * Y, [['B-']]),
  r(38, 89, 50.5 * D, [['B-']]),
  r(38, 90, 28.8 * Y, [['B-']], 'Fission product'),
  r(39, 90, 64.05 * H, [['B-']]),
  r(43, 99, 2.11e5 * Y, [['B-']], 'Ground state (the medical isomer Tc-99m is separate)'),
  r(53, 125, 59.4 * D, [['EC']]),
  r(53, 131, 8.02 * D, [['B-']], 'Fission product'),
  r(54, 133, 5.243 * D, [['B-']]),
  r(55, 137, 30.08 * Y, [['B-']], 'Fission product'),
  r(77, 192, 73.83 * D, [['B-', 95], ['EC', 5]]),
  r(81, 201, 3.04 * D, [['EC']]),
  r(83, 210, 5.01 * D, [['B-']]),
  r(83, 214, 19.9 * M, [['B-']]),
  r(84, 210, 138.4 * D, [['A']]),
  r(84, 214, 164.3e-6, [['A']]),
  r(84, 218, 3.10 * M, [['A']]),
  r(82, 210, 22.2 * Y, [['B-']]),
  r(82, 214, 26.8 * M, [['B-']]),
  r(86, 222, 3.8235 * D, [['A']], 'Radon gas'),
  r(88, 226, 1600 * Y, [['A']]),
  r(90, 230, 7.54e4 * Y, [['A']]),
  r(90, 232, 1.405e10 * Y, [['A']]),
  r(90, 234, 24.1 * D, [['B-']]),
  r(91, 234, 6.70 * H, [['B-']], 'Ground state; the chain mostly passes through the 1.17-min isomer Pa-234m'),
  r(92, 234, 2.455e5 * Y, [['A']]),
  r(92, 235, 7.04e8 * Y, [['A']], 'Fissile'),
  r(92, 238, 4.468e9 * Y, [['A']]),
  r(94, 239, 2.411e4 * Y, [['A']], 'Fissile'),
  r(95, 241, 432.6 * Y, [['A']]),
];
const REF_MAP = new Map(REFERENCE.map(x => [`${x.z}-${x.a}`, x]));
export const lookup = (z: number, a: number): RefNuclide | undefined => REF_MAP.get(`${z}-${a}`);

export interface ChainStep { z: number; a: number; t: number | null; mode: Mode | null; note?: string }
export interface Chain { steps: ChainStep[]; end: 'stable' | 'unknown' | 'invalid' | 'limit' }

/** Follow the dominant reported mode until a stable nuclide or a nuclide with no bundled data. */
export function followChain(z: number, a: number, limit = 30): Chain {
  const steps: ChainStep[] = [];
  let cz = z, ca = a;
  for (let i = 0; i < limit; i++) {
    const ref = lookup(cz, ca);
    if (!ref) { steps.push({ z: cz, a: ca, t: null, mode: null }); return { steps, end: 'unknown' }; }
    if (ref.t === null) { steps.push({ z: cz, a: ca, t: null, mode: null, note: ref.note }); return { steps, end: 'stable' }; }
    const mode = ref.modes[0].mode;
    steps.push({ z: cz, a: ca, t: ref.t, mode, note: ref.note });
    const d = applyDecay(cz, ca, mode).daughter;
    if (!d) return { steps, end: 'invalid' };
    cz = d.z; ca = d.a;
  }
  return { steps, end: 'limit' };
}

// ── Decay law ─────────────────────────────────────────────────────────────────
export const remainingFraction = (t: number, halfLife: number) => Math.pow(2, -t / halfLife);
export const decayConstant = (halfLife: number) => Math.LN2 / halfLife;
export const timeToFraction = (f: number, halfLife: number) => halfLife * Math.log2(1 / f);
export const AVOGADRO = 6.02214076e23;

export function fmtNum(x: number, digits = 4): string {
  if (!Number.isFinite(x)) return '—';
  if (x === 0) return '0';
  const ax = Math.abs(x);
  if (ax >= 0.01 && ax < 1e5) return String(Number(x.toPrecision(digits)));
  return x.toExponential(digits - 1).replace('e+', ' × 10^').replace('e-', ' × 10^−').replace(/10\^(\d)/, '10^$1');
}

export function fmtTime(sec: number): string {
  if (!Number.isFinite(sec)) return '—';
  const a = Math.abs(sec);
  if (a < 1e-3) return `${fmtNum(sec / 1e-6, 3)} µs`;
  if (a < 1) return `${fmtNum(sec / 1e-3, 3)} ms`;
  if (a < 60) return `${fmtNum(sec, 3)} s`;
  if (a < 3600) return `${fmtNum(sec / 60, 3)} min`;
  if (a < 86400) return `${fmtNum(sec / 3600, 3)} h`;
  if (a < SEC.y) return `${fmtNum(sec / 86400, 3)} d`;
  return `${fmtNum(sec / SEC.y, 4)} y`;
}

// ── Equation parser ───────────────────────────────────────────────────────────
const SUPMAP: Record<string, string> = { '⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9' };
const ALIASES: Record<string, PId> = {
  n: 'n', neutron: 'n', p: 'p', proton: 'p', alpha: 'alpha', 'α': 'alpha',
  'e-': 'e-', electron: 'e-', 'beta-': 'e-', 'β-': 'e-', beta: 'e-',
  positron: 'e+', 'e+': 'e+', 'beta+': 'e+', 'β+': 'e+',
  nu: 'nu', neutrino: 'nu', 've': 'nu', 'νe': 'nu', 'ν': 'nu',
  nubar: 'nubar', 'anti-nu': 'nubar', antineutrino: 'nubar', 'anti-neutrino': 'nubar', 'ν̄': 'nubar', 'ν̄e': 'nubar',
  gamma: 'gamma', 'γ': 'gamma',
};
const NUCLIDE_ALIASES: Record<string, [number, number]> = { d: [1, 2], deuteron: [1, 2], deuterium: [1, 2], t: [1, 3], triton: [1, 3], tritium: [1, 3] };

function parseToken(raw: string): { sp?: Species; error?: string } {
  let tok = raw.trim();
  if (!tok) return {};
  let coef = 1;
  const m = tok.match(/^(\d+)\s*[x×*]?\s+(.+)$/) ?? tok.match(/^(\d+)\s*([nNpP]|alpha|neutron|proton|positron|electron|gamma|nu|beta[+-]?)$/i);
  if (m) { coef = parseInt(m[1], 10); tok = m[2].trim(); }
  const low = tok.toLowerCase();
  if (ALIASES[low] || ALIASES[tok]) return { sp: particle(ALIASES[low] ?? ALIASES[tok], coef) };
  if (NUCLIDE_ALIASES[low]) { const [z, a] = NUCLIDE_ALIASES[low]; return { sp: nuclide(z, a, coef) }; }
  const star = tok.endsWith('*');
  if (star) tok = tok.slice(0, -1);
  const m1 = tok.match(/^([A-Z][a-z]?)-?(\d+)$/) ?? (() => { const k = tok.match(/^(\d+)-?([A-Z][a-z]?)$/); return k ? [k[0], k[2], k[1]] : null; })();
  if (m1) {
    const el = BY_SYMBOL[m1[1]];
    const a = parseInt(m1[2], 10);
    if (!el) return { error: `Unknown element “${m1[1]}”.` };
    if (a < el.z) return { error: `${m1[1]}-${a}: mass number is smaller than the atomic number (${el.z}).` };
    return { sp: nuclide(el.z, a, coef, star) };
  }
  return { error: `Could not read “${raw.trim()}”. Use forms like U-235, 235U, ²³⁵U, n, p, alpha, e-, e+, nu, anti-nu, gamma.` };
}

export interface ParsedEquation { left: Species[]; right: Species[]; errors: string[] }

export function parseEquation(src: string): ParsedEquation {
  let s = src.replace(/[⁰¹²³⁴⁵⁶⁷⁸⁹]/g, c => SUPMAP[c]).replace(/[−–]/g, '-').replace(/[→⟶⇒]|=>|=/g, '->').replace(/\^/g, '');
  s = s.replace(/(^|[\s+>])(?:e|beta|β|positron)\s*\+/gi, '$1 positron ');
  const sides = s.split('->');
  if (sides.length !== 2) return { left: [], right: [], errors: ['Write the equation with one arrow, e.g. U-235 + n -> Ba-141 + Kr-92 + 3 n'] };
  const errors: string[] = [];
  const side = (txt: string) => txt.split('+').map(parseToken).flatMap(p => { if (p.error) errors.push(p.error); return p.sp ? [p.sp] : []; });
  const left = side(sides[0]), right = side(sides[1]);
  if (!left.length || !right.length) errors.push('Both sides of the equation need at least one species.');
  return { left, right, errors };
}
