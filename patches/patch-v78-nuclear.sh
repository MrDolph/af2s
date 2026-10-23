#!/bin/bash
# A-Factor STEM Studio — Chemistry playground, part 3: Nuclear playground
# Run inside af2s/ (the project ROOT) AFTER patch-v76 and patch-v77:
#     bash patches/patch-v78-nuclear.sh
#
# ADDS   /chemistry/nuclear
#   - Chart of nuclides (N vs Z) with a rule-of-thumb beta-stability line; click to pick a nuclide
#   - Decay explorer: alpha, beta-, beta+, electron capture, proton/neutron emission, gamma;
#     daughter nuclide, full equation, and a conservation table (nucleon number, charge, lepton number)
#   - Decay chains followed from bundled reference data (e.g. U-238 -> Pb-206)
#   - Half-life lab: N = N0 * 2^(-t/T), activity, mass left, time to reach a chosen percentage, decay curve
#   - Equation checker: type U-235 + n -> Ba-141 + Kr-92 + 3 n (also 235U, ²³⁵U, n, p, alpha, e-, e+, nu, anti-nu, gamma, d, t)
# UPDATES
#   - EvidencePanel: optional candidate/database/calculated overrides (other pages unchanged)
#   - /chemistry hub: Nuclear card switched from "Coming soon" to Live
# Reference data is a small hand-bundled table (~70 nuclides, rounded) and is labelled as such;
# nothing outside it is presented as known. Q-values are NOT computed.
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -d src ]; then echo "ERROR: run from the project root (package.json + src/)."; exit 1; fi
if [ ! -f src/lib/chemistry/heusler.ts ]; then echo "ERROR: apply patch-v76 and patch-v77 first."; exit 1; fi

echo "Applying Nuclear playground (v78)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/chemistry/nuclear.ts << 'FILEEOF'
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
FILEEOF

write_file src/components/chemistry/EvidencePanel.tsx << 'FILEEOF'
'use client';
// Makes the four evidence levels explicit so a built candidate is never mistaken for a known material.

type Tier = { state: 'yes' | 'warn' | 'no'; text: string };

interface Props {
  rule: { label: string; ok: boolean | null };
  extra?: string;
  /** Replace the default “you built a candidate” line (e.g. for nuclides or equations). */
  candidate?: string;
  /** Override the database / calculated tiers when a page does bundle some data. */
  database?: Tier;
  calculated?: Tier;
}

export function EvidencePanel({ rule, extra, candidate, database, calculated }: Props) {
  const tier = (title: string, state: 'yes' | 'warn' | 'no', body: string) => (
    <li className="flex gap-2.5 py-2 text-xs">
      <span className={`mt-0.5 h-2 w-2 shrink-0 rounded-full ${state === 'yes' ? 'bg-emerald-500' : state === 'warn' ? 'bg-amber-500' : 'bg-gray-300'}`} />
      <span><span className="font-medium text-gray-900">{title}.</span> <span className="text-gray-600">{body}</span></span>
    </li>
  );
  return (
    <div className="rounded-2xl border border-gray-200 bg-white p-5">
      <h3 className="text-sm font-semibold text-gray-900">What this result is — and isn’t</h3>
      <ul className="mt-1 divide-y divide-gray-100">
        {tier('User-built candidate', 'yes', candidate ?? 'You chose this composition' + (extra ? ` / ${extra}` : '') + '. Choosing elements does not mean the compound exists.')}
        {tier('Rule-based assessment', rule.ok === null ? 'no' : rule.ok ? 'yes' : 'warn', rule.label)}
        {tier('Database-supported material', database?.state ?? 'no', database?.text ?? 'Not checked. Look the formula up yourself (e.g. Materials Project, ICSD, OQMD) before calling it a known phase.')}
        {tier('Calculated result', calculated?.state ?? 'no', calculated?.text ?? 'None. No DFT or other calculation is run here; tolerance factors are geometric heuristics.')}
      </ul>
    </div>
  );
}
FILEEOF

write_file src/components/chemistry/NuclideChart.tsx << 'FILEEOF'
'use client';
import { useMemo } from 'react';
import { REFERENCE, valleyZ, label, type Mode } from '@/lib/chemistry/nuclear';

interface Props {
  selected: { z: number; a: number };
  daughter: { z: number; a: number } | null;
  onSelect: (z: number, a: number) => void;
}

const W = 640, H = 440, X0 = 44, X1 = 624, Y0 = 404, Y1 = 16, NMAX = 160, ZMAX = 110;
const px = (n: number) => X0 + (n / NMAX) * (X1 - X0);
const py = (z: number) => Y0 - (z / ZMAX) * (Y0 - Y1);

const COLOR: Record<Mode | 'S', string> = { A: '#f59e0b', 'B-': '#38bdf8', 'B+': '#fb7185', EC: '#a78bfa', P: '#34d399', N: '#34d399', G: '#9ca3af', S: '#334155' };

export function NuclideChart({ selected, daughter, onSelect }: Props) {
  const valley = useMemo(() => {
    const pts: string[] = [];
    for (let a = 1; a <= 260; a += 2) {
      const z = valleyZ(a), n = a - z;
      if (n <= NMAX && z <= ZMAX) pts.push(`${px(n).toFixed(1)},${py(z).toFixed(1)}`);
    }
    return pts.join(' ');
  }, []);

  const click = (e: React.MouseEvent<SVGSVGElement>) => {
    const box = e.currentTarget.getBoundingClientRect();
    const x = ((e.clientX - box.left) / box.width) * W, y = ((e.clientY - box.top) / box.height) * H;
    const n = Math.round(((x - X0) / (X1 - X0)) * NMAX), z = Math.round(((Y0 - y) / (Y0 - Y1)) * ZMAX);
    if (n < 0 || z < 0 || n > NMAX || z > ZMAX || n + z < 1) return;
    onSelect(z, z + n);
  };

  const sel = { x: px(selected.a - selected.z), y: py(selected.z) };
  const dau = daughter ? { x: px(daughter.a - daughter.z), y: py(daughter.z) } : null;

  return (
    <div>
      <svg viewBox={`0 0 ${W} ${H}`} className="w-full cursor-crosshair rounded-xl bg-slate-50" onClick={click} role="img" aria-label="Chart of nuclides: neutron number on the horizontal axis, proton number on the vertical axis. Click to choose a nuclide.">
        <defs><marker id="arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="6" markerHeight="6" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#4f46e5" /></marker></defs>
        {Array.from({ length: Math.floor(NMAX / 20) + 1 }, (_, i) => i * 20).map(n => (
          <g key={`n${n}`}><line x1={px(n)} x2={px(n)} y1={Y0} y2={Y1} stroke="#e5e7eb" strokeWidth={0.7} /><text x={px(n)} y={Y0 + 14} fontSize={10} textAnchor="middle" fill="#6b7280">{n}</text></g>
        ))}
        {Array.from({ length: Math.floor(ZMAX / 20) + 1 }, (_, i) => i * 20).map(z => (
          <g key={`z${z}`}><line x1={X0} x2={X1} y1={py(z)} y2={py(z)} stroke="#e5e7eb" strokeWidth={0.7} /><text x={X0 - 6} y={py(z) + 3} fontSize={10} textAnchor="end" fill="#6b7280">{z}</text></g>
        ))}
        <text x={(X0 + X1) / 2} y={H - 6} fontSize={11} textAnchor="middle" fill="#374151">Neutron number N</text>
        <text transform={`translate(12 ${(Y0 + Y1) / 2}) rotate(-90)`} fontSize={11} textAnchor="middle" fill="#374151">Proton number Z</text>
        <line x1={px(0)} y1={py(0)} x2={px(ZMAX)} y2={py(ZMAX)} stroke="#9ca3af" strokeDasharray="4 3" strokeWidth={1} />
        <polyline points={valley} fill="none" stroke="#6366f1" strokeWidth={1.6} opacity={0.65} />
        {REFERENCE.map(r => (
          <circle key={`${r.z}-${r.a}`} cx={px(r.a - r.z)} cy={py(r.z)} r={3.2} fill={COLOR[r.t === null ? 'S' : r.modes[0].mode]} stroke="#fff" strokeWidth={0.6} />
        ))}
        {dau && <line x1={sel.x} y1={sel.y} x2={dau.x} y2={dau.y} stroke="#4f46e5" strokeWidth={1.6} markerEnd="url(#arrow)" />}
        <circle cx={sel.x} cy={sel.y} r={7} fill="none" stroke="#4f46e5" strokeWidth={2} />
        <text x={Math.min(sel.x + 10, X1 - 40)} y={Math.max(sel.y - 10, 24)} fontSize={11} fontWeight={600} fill="#312e81">{label(selected.z, selected.a)}</text>
      </svg>
      <div className="mt-2 flex flex-wrap gap-x-3 gap-y-1 text-[10px] text-gray-500">
        {([['S', 'Stable'], ['B-', 'β⁻'], ['B+', 'β⁺'], ['EC', 'EC'], ['A', 'α']] as [Mode | 'S', string][]).map(([k, t]) => (
          <span key={k} className="flex items-center gap-1"><span className="inline-block h-2 w-2 rounded-full" style={{ background: COLOR[k] }} />{t}</span>
        ))}
        <span className="flex items-center gap-1"><span className="inline-block h-0.5 w-4 bg-indigo-500 opacity-70" />β-stability line (rule of thumb)</span>
        <span className="flex items-center gap-1"><span className="inline-block w-4 border-t border-dashed border-gray-400" />N = Z</span>
        <span>Dots are the bundled reference nuclides only · click anywhere to choose a nuclide</span>
      </div>
    </div>
  );
}
FILEEOF

write_file src/components/chemistry/DecayCurve.tsx << 'FILEEOF'
'use client';
import { useMemo } from 'react';

interface Props { /** elapsed time in half-lives */ tHalf: number }

const W = 560, H = 250, X0 = 46, X1 = 540, Y0 = 210, Y1 = 14;

export function DecayCurve({ tHalf }: Props) {
  const max = Math.min(20, Math.max(6, Math.ceil(tHalf) + 1));
  const px = (t: number) => X0 + (t / max) * (X1 - X0);
  const py = (f: number) => Y0 - f * (Y0 - Y1);
  const path = useMemo(() => Array.from({ length: 121 }, (_, i) => {
    const t = (i / 120) * max;
    return `${i ? 'L' : 'M'}${px(t).toFixed(1)},${py(Math.pow(2, -t)).toFixed(1)}`;
  }).join(' '),
  // eslint-disable-next-line react-hooks/exhaustive-deps
  [max]);
  const f = Math.pow(2, -tHalf);
  const inRange = tHalf <= max;
  return (
    <svg viewBox={`0 0 ${W} ${H}`} className="w-full rounded-xl bg-slate-50" role="img" aria-label="Exponential decay curve: fraction of nuclei remaining against elapsed half-lives.">
      {[0, 0.25, 0.5, 0.75, 1].map(v => (
        <g key={v}><line x1={X0} x2={X1} y1={py(v)} y2={py(v)} stroke="#e5e7eb" strokeWidth={0.7} /><text x={X0 - 6} y={py(v) + 3} fontSize={10} textAnchor="end" fill="#6b7280">{v}</text></g>
      ))}
      {Array.from({ length: max + 1 }, (_, i) => i).filter(i => max <= 10 || i % 2 === 0).map(i => (
        <g key={i}><line x1={px(i)} x2={px(i)} y1={Y0} y2={Y0 + 4} stroke="#9ca3af" /><text x={px(i)} y={Y0 + 16} fontSize={10} textAnchor="middle" fill="#6b7280">{i}</text></g>
      ))}
      <text x={(X0 + X1) / 2} y={H - 6} fontSize={11} textAnchor="middle" fill="#374151">Elapsed time (half-lives)</text>
      <text transform={`translate(12 ${(Y0 + Y1) / 2}) rotate(-90)`} fontSize={11} textAnchor="middle" fill="#374151">N / N₀</text>
      <path d={path} fill="none" stroke="#4f46e5" strokeWidth={2} />
      {inRange && (
        <g>
          <line x1={px(tHalf)} x2={px(tHalf)} y1={py(f)} y2={Y0} stroke="#f59e0b" strokeDasharray="3 3" />
          <line x1={X0} x2={px(tHalf)} y1={py(f)} y2={py(f)} stroke="#f59e0b" strokeDasharray="3 3" />
          <circle cx={px(tHalf)} cy={py(f)} r={4.5} fill="#f59e0b" stroke="#fff" strokeWidth={1} />
        </g>
      )}
    </svg>
  );
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
  { slug: 'crystal-builder', href: '#', title: 'Crystal builder', icon: '🔷', topic: 'Materials', status: 'coming',
    description: 'Place elements into general structural sites, rotate unit cells and compare arrangements.' },
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

write_file src/app/chemistry/nuclear/page.tsx << 'FILEEOF'
'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { NuclideChart } from '@/components/chemistry/NuclideChart';
import { DecayCurve } from '@/components/chemistry/DecayCurve';
import {
  AVOGADRO, MODE_LABEL, MODE_SHORT, SEC, applyDecay, balance, decayConstant, fmtNum, fmtTime, followChain, hints, label,
  lookup, nameOf, parseEquation, plainLabel, remainingFraction, sideText, symbolOf, timeToFraction,
  type Mode, type TimeUnit,
} from '@/lib/chemistry/nuclear';
import { ELEMENTS } from '@/lib/chemistry/elements';

const MODES: Mode[] = ['A', 'B-', 'B+', 'EC', 'P', 'N', 'G'];
const NUCLIDE_PRESETS: [string, number, number][] = [
  ['U-238', 92, 238], ['C-14', 6, 14], ['K-40', 19, 40], ['Co-60', 27, 60], ['F-18', 9, 18], ['Rn-222', 86, 222], ['Cs-137', 55, 137], ['H-3', 1, 3], ['n', 0, 1],
];
const EQ_EXAMPLES: [string, string][] = [
  ['U-235 fission', 'U-235 + n -> Ba-141 + Kr-92 + 3 n'],
  ['D–T fusion', 'H-2 + H-3 -> He-4 + n'],
  ['α decay', 'U-238 -> Th-234 + alpha'],
  ['β⁻ decay', 'C-14 -> N-14 + e- + anti-nu'],
  ['β⁺ decay', 'Na-22 -> Ne-22 + e+ + nu'],
  ['Electron capture', 'Be-7 + e- -> Li-7 + nu'],
  ['Missing antineutrino', 'C-14 -> N-14 + e-'],
];
const UNITS: TimeUnit[] = ['us', 'ms', 's', 'min', 'h', 'd', 'y'];
const UNIT_LABEL: Record<TimeUnit, string> = { us: 'µs', ms: 'ms', s: 's', min: 'min', h: 'h', d: 'days', y: 'years' };

function bestUnit(sec: number): { value: number; unit: TimeUnit } {
  for (const u of [...UNITS].reverse()) if (sec >= SEC[u]) return { value: Number((sec / SEC[u]).toPrecision(4)), unit: u };
  return { value: Number((sec / SEC.us).toPrecision(4)), unit: 'us' };
}

const Row = ({ k, v }: { k: string; v: React.ReactNode }) => (
  <div className="flex justify-between gap-3 border-b border-gray-100 py-1.5 text-xs last:border-0"><dt className="text-gray-500">{k}</dt><dd className="text-right font-medium text-gray-900">{v}</dd></div>
);
const Card = ({ children, title }: { children: React.ReactNode; title?: string }) => (
  <div className="rounded-2xl border border-gray-200 bg-white p-5">{title && <h2 className="mb-3 text-sm font-semibold text-gray-900">{title}</h2>}{children}</div>
);

function BalanceTable({ bal }: { bal: ReturnType<typeof balance> }) {
  const rows: [string, 'A' | 'Z' | 'L'][] = [['Nucleon number A', 'A'], ['Charge Z (in e)', 'Z'], ['Lepton number L', 'L']];
  return (
    <table className="w-full text-xs">
      <thead className="text-[10px] uppercase tracking-wide text-gray-400"><tr><th className="py-1 text-left font-medium">Conserved</th><th className="text-right font-medium">Left</th><th className="text-right font-medium">Right</th><th className="w-8" /></tr></thead>
      <tbody>
        {rows.map(([name, k]) => (
          <tr key={k} className="border-t border-gray-100">
            <td className="py-1.5 text-gray-600">{name}</td>
            <td className="text-right font-mono text-gray-900">{bal.left[k]}</td>
            <td className="text-right font-mono text-gray-900">{bal.right[k]}</td>
            <td className={`text-right font-semibold ${bal.ok[k] ? 'text-emerald-600' : 'text-red-600'}`} aria-label={bal.ok[k] ? 'conserved' : 'not conserved'}>{bal.ok[k] ? '✓' : '✗'}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}

export default function NuclearPage() {
  const [nuc, setNuc] = useState({ z: 92, a: 238 });
  const [modeState, setModeState] = useState<{ key: string; mode: Mode } | null>(null);
  const [custom, setCustom] = useState<{ key: string; value: number; unit: TimeUnit } | null>(null);
  const [amountKind, setAmountKind] = useState<'mass' | 'atoms'>('mass');
  const [amount, setAmount] = useState(1);
  const [time, setTime] = useState(1);
  const [timeUnit, setTimeUnit] = useState<TimeUnit>('y');
  const [targetPct, setTargetPct] = useState(25);
  const [eq, setEq] = useState(EQ_EXAMPLES[0][1]);

  const { z, a } = nuc;
  const key = `${z}-${a}`;
  const ref = lookup(z, a);
  const hint = hints(z, a);
  const nameText = z === 0 ? 'Free neutron' : `${nameOf(z)}-${a}`;

  const defaultMode: Mode = ref?.modes[0]?.mode ?? (hint.delta < -0.9 ? 'B-' : hint.delta > 0.9 ? 'B+' : z >= 83 ? 'A' : 'B-');
  const mode = modeState?.key === key ? modeState.mode : defaultMode;
  const decay = applyDecay(z, a, mode);
  const chain = followChain(z, a);
  const reported = ref?.modes.find(m => m.mode === mode);
  const daughterRef = decay.daughter ? lookup(decay.daughter.z, decay.daughter.a) : undefined;

  // Half-life lab
  const refHL = ref?.t ?? null;
  const refBest = refHL ? bestUnit(refHL) : null;
  const hlValue = custom?.key === key ? custom.value : refBest?.value ?? 1;
  const hlUnit = custom?.key === key ? custom.unit : refBest?.unit ?? 'y';
  const T = custom?.key === key ? custom.value * SEC[custom.unit] : refHL;
  const tSec = time * SEC[timeUnit];
  const lab = (() => {
    if (!T || T <= 0 || !(tSec >= 0)) return null;
    const f = remainingFraction(tSec, T);
    const n0 = amountKind === 'atoms' ? amount : (amount / a) * AVOGADRO; // molar mass ≈ A g/mol
    const n = n0 * f;
    const lambda = decayConstant(T);
    const frac = Math.min(Math.max(targetPct / 100, 1e-12), 1);
    return { f, n0, n, lambda, act0: lambda * n0, act: lambda * n, massLeft: (n / AVOGADRO) * a, tTarget: timeToFraction(frac, T), tHalf: tSec / T };
  })();

  const parsed = useMemo(() => parseEquation(eq), [eq]);
  const eqBal = useMemo(() => (parsed.errors.length ? null : balance(parsed.left, parsed.right)), [parsed]);

  const choose = (zz: number, aa: number) => setNuc({ z: zz, a: Math.max(aa, zz, 1) });
  const setMode = (m: Mode) => setModeState({ key, mode: m });

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Nuclear playground</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Chemistry rearranges electrons; nuclear processes change the nucleus. Pick a nuclide, test decay modes against the conservation laws, and run the decay law. Balance tells you a process is <span className="font-medium text-gray-700">allowed by the bookkeeping</span> — not that it happens.</p>

          <div className="grid gap-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            <div className="space-y-5">
              <Card>
                <NuclideChart selected={nuc} daughter={decay.daughter} onSelect={choose} />
              </Card>

              <Card title="Decay chain (bundled reference data)">
                <div className="flex flex-wrap items-center gap-1.5 text-xs">
                  {chain.steps.map((s, i) => (
                    <span key={i} className="flex items-center gap-1.5">
                      <button type="button" onClick={() => choose(s.z, s.a)} className={`rounded-md border px-2 py-1 ${s.z === z && s.a === a ? 'border-indigo-600 bg-indigo-50 text-indigo-800' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`}>
                        <span className="font-semibold">{label(s.z, s.a)}</span>
                        {s.t !== null && <span className="ml-1 text-[10px] text-gray-400">{fmtTime(s.t)}</span>}
                      </button>
                      {s.mode && <span className="text-[11px] text-gray-400">{MODE_SHORT[s.mode]} →</span>}
                    </span>
                  ))}
                </div>
                <p className="mt-2 text-[11px] text-gray-500">
                  {chain.end === 'stable' && `Ends at a stable nuclide after ${chain.steps.length - 1} step${chain.steps.length === 2 ? '' : 's'}.`}
                  {chain.end === 'unknown' && 'The chain stops where the bundled table has no entry — the nuclide may be stable or simply not listed here.'}
                  {chain.end === 'invalid' && 'The chain stops because the next daughter would not be a valid nucleus.'}
                  {chain.end === 'limit' && 'Stopped after 30 steps.'} Each step follows only the dominant reported mode; branching is ignored.
                </p>
              </Card>

              <Card title="Nuclear equation checker">
                <div className="mb-2 flex flex-wrap gap-2">
                  {EQ_EXAMPLES.map(([t, v]) => <button key={t} type="button" onClick={() => setEq(v)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{t}</button>)}
                </div>
                <label className="sr-only" htmlFor="eq">Nuclear equation</label>
                <input id="eq" value={eq} onChange={e => setEq(e.target.value)} spellCheck={false} className="h-10 w-full rounded-lg border border-gray-200 px-3 font-mono text-sm" placeholder="U-235 + n -> Ba-141 + Kr-92 + 3 n" />
                <p className="mt-1 text-[11px] text-gray-400">Write nuclides as U-235, 235U or ²³⁵U; particles as n, p, alpha, e-, e+, nu, anti-nu, gamma, d, t.</p>
                {parsed.errors.length > 0 ? (
                  <ul className="mt-3 space-y-1 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">{parsed.errors.map(e => <li key={e}>{e}</li>)}</ul>
                ) : eqBal && (
                  <div className="mt-3">
                    <div className="rounded-lg bg-gray-50 px-3 py-2 text-center text-base text-gray-900">{sideText(parsed.left)} → {sideText(parsed.right)}</div>
                    <div className="mt-3"><BalanceTable bal={eqBal} /></div>
                    <p className={`mt-3 rounded-lg px-3 py-2 text-xs ${eqBal.balanced ? 'bg-emerald-50 text-emerald-900' : 'bg-red-50 text-red-800'}`}>
                      {eqBal.balanced ? 'Balanced: nucleon number, charge and lepton number are all conserved. Energy (Q-value) is not checked.' : `Not balanced: ${[!eqBal.ok.A && 'nucleon number', !eqBal.ok.Z && 'charge', !eqBal.ok.L && 'lepton number'].filter(Boolean).join(', ')} not conserved.`}
                    </p>
                  </div>
                )}
              </Card>
            </div>

            <div className="space-y-5">
              <Card>
                <div className="flex flex-wrap gap-2">
                  {NUCLIDE_PRESETS.map(([t, zz, aa]) => <button key={t} type="button" onClick={() => choose(zz, aa)} className={`rounded-full border px-2.5 py-1 text-[11px] ${z === zz && a === aa ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-700 hover:border-indigo-300'}`}>{t}</button>)}
                </div>
                <div className="mt-3 flex gap-2">
                  <label className="flex-1 text-[11px] text-gray-500">Element
                    <select value={z} onChange={e => choose(Number(e.target.value), a)} className="mt-1 h-8 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                      <option value={0}>n — Neutron</option>
                      {ELEMENTS.map(el => <option key={el.z} value={el.z}>{el.symbol} — {el.name} (Z={el.z})</option>)}
                    </select>
                  </label>
                  <label className="w-24 text-[11px] text-gray-500">Mass no. A
                    <input type="number" min={Math.max(1, z)} max={300} value={a} onChange={e => choose(z, Math.round(Number(e.target.value)) || 1)} className="mt-1 h-8 w-full rounded-md border border-gray-200 px-2 text-sm" />
                  </label>
                </div>
                <div className="mt-4 flex items-baseline gap-3">
                  <span className="text-4xl font-semibold text-gray-900">{label(z, a)}</span>
                  <span className="text-sm text-gray-500">{nameText}</span>
                </div>
                <dl className="mt-2">
                  <Row k="Protons / neutrons" v={`${z} / ${a - z}`} />
                  <Row k="N/Z" v={z ? (((a - z) / z)).toFixed(2) : '—'} />
                  {ref ? <>
                    <Row k="Half-life" v={ref.t === null ? 'Stable (observationally)' : fmtTime(ref.t)} />
                    <Row k="Reported decay" v={ref.modes.length ? ref.modes.map(m => `${MODE_SHORT[m.mode]}${m.pct ? ` ${m.pct}%` : ''}`).join(', ') : '—'} />
                  </> : <Row k="Reference data" v="None bundled" />}
                </dl>
                {ref?.note && <p className="mt-1 text-[11px] text-gray-500">{ref.note}</p>}
                {!ref && <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] text-amber-900">No half-life or decay mode is bundled for {plainLabel(z, a)}. Look it up in NUBASE / ENSDF (e.g. NNDC NuDat or the IAEA Live Chart of Nuclides) before relying on any value. The rule-of-thumb hint below is not data.</p>}
                <p className="mt-3 text-[11px] leading-relaxed text-gray-500"><span className="font-medium text-gray-700">Rule of thumb:</span> {hint.lines.join(' ')} <span className="text-gray-400">(stability line at Z ≈ {hint.zs.toFixed(1)} for A = {a})</span></p>
              </Card>

              <Card title="Decay explorer">
                <div className="flex flex-wrap gap-1.5">
                  {MODES.map(m => <button key={m} type="button" onClick={() => setMode(m)} className={`rounded-md border px-2.5 py-1 text-xs ${mode === m ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`} title={MODE_LABEL[m]}>{MODE_SHORT[m]}</button>)}
                </div>
                <p className="mt-1 text-[11px] text-gray-400">{MODE_LABEL[mode]}</p>
                <div className="mt-3 rounded-lg bg-gray-50 px-3 py-3 text-center text-base text-gray-900" aria-live="polite">{sideText(decay.left)} → {sideText(decay.right)}</div>
                {decay.issues.length > 0 && <ul className="mt-2 space-y-1 rounded-lg bg-red-50 px-3 py-2 text-xs text-red-800">{decay.issues.map(i => <li key={i}>{i}</li>)}</ul>}
                <div className="mt-3"><BalanceTable bal={decay.bal} /></div>
                <div className="mt-3 space-y-1.5 text-[11px] leading-relaxed">
                  <p className={`rounded-lg px-3 py-2 ${reported ? 'bg-emerald-50 text-emerald-900' : 'bg-gray-50 text-gray-700'}`}>
                    {reported ? `${MODE_SHORT[mode]} is a reported decay mode of ${plainLabel(z, a)}${reported.pct ? ` (≈ ${reported.pct}% branch)` : ''}.`
                      : ref ? (ref.t === null ? `${plainLabel(z, a)} is listed as stable, so this decay is not observed — it balances on paper only.` : `${MODE_SHORT[mode]} is not a reported mode for ${plainLabel(z, a)} in the bundled table.`)
                      : 'No reference data for this nuclide, so there is nothing to compare this mode against.'}
                  </p>
                  <p className="px-1 text-gray-500">Conservation laws are necessary, not sufficient: the decay must also release energy (Q &gt; 0), which is not computed here.</p>
                </div>
                {decay.daughter && (
                  <button type="button" onClick={() => choose(decay.daughter!.z, decay.daughter!.a)} className="mt-3 rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">
                    Go to daughter {plainLabel(decay.daughter.z, decay.daughter.a)}{daughterRef ? (daughterRef.t === null ? ' (stable)' : ` (${fmtTime(daughterRef.t)})`) : ''} →
                  </button>
                )}
              </Card>

              <Card title="Half-life lab">
                <div className="grid grid-cols-2 gap-3 text-[11px] text-gray-500">
                  <div className="col-span-2">Half-life
                    <div className="mt-1 flex gap-2">
                      <input type="number" min={0} step="any" value={hlValue} onChange={e => setCustom({ key, value: Number(e.target.value), unit: hlUnit })} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Half-life value" />
                      <select value={hlUnit} onChange={e => setCustom({ key, value: hlValue, unit: e.target.value as TimeUnit })} className="h-8 rounded-md border border-gray-200 bg-white px-2 text-sm text-gray-900" aria-label="Half-life unit">{UNITS.map(u => <option key={u} value={u}>{UNIT_LABEL[u]}</option>)}</select>
                    </div>
                    <span className="mt-1 block text-gray-400">{custom?.key === key ? 'Your value. ' : refHL ? 'From the bundled reference. ' : 'No bundled value — enter one. '}{custom?.key === key && refHL ? <button type="button" className="text-indigo-600 hover:underline" onClick={() => setCustom(null)}>Reset to reference</button> : null}</span>
                  </div>
                  <div>Initial amount
                    <div className="mt-1 flex gap-1.5">
                      <input type="number" min={0} step="any" value={amount} onChange={e => setAmount(Number(e.target.value))} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Initial amount" />
                      <select value={amountKind} onChange={e => setAmountKind(e.target.value as 'mass' | 'atoms')} className="h-8 rounded-md border border-gray-200 bg-white px-1 text-sm text-gray-900"><option value="mass">g</option><option value="atoms">atoms</option></select>
                    </div>
                  </div>
                  <div>Elapsed time
                    <div className="mt-1 flex gap-1.5">
                      <input type="number" min={0} step="any" value={time} onChange={e => setTime(Number(e.target.value))} className="h-8 w-full rounded-md border border-gray-200 px-2 text-sm text-gray-900" aria-label="Elapsed time" />
                      <select value={timeUnit} onChange={e => setTimeUnit(e.target.value as TimeUnit)} className="h-8 rounded-md border border-gray-200 bg-white px-1 text-sm text-gray-900">{UNITS.map(u => <option key={u} value={u}>{UNIT_LABEL[u]}</option>)}</select>
                    </div>
                  </div>
                </div>

                {!lab ? (
                  <p className="mt-3 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">Enter a positive half-life and a non-negative time to run the decay law.</p>
                ) : (
                  <>
                    <div className="mt-3"><DecayCurve tHalf={lab.tHalf} /></div>
                    <dl className="mt-3">
                      <Row k="Elapsed" v={`${fmtNum(lab.tHalf, 4)} half-lives`} />
                      <Row k="Fraction remaining N/N₀" v={`${fmtNum(lab.f, 4)} (${fmtNum(lab.f * 100, 4)} %)`} />
                      <Row k="Nuclei remaining" v={fmtNum(lab.n, 4)} />
                      <Row k="Mass remaining (≈ A g/mol)" v={`${fmtNum(lab.massLeft, 4)} g`} />
                      <Row k="Decay constant λ" v={`${fmtNum(lab.lambda, 4)} s⁻¹`} />
                      <Row k="Activity now / initially" v={`${fmtNum(lab.act, 4)} / ${fmtNum(lab.act0, 4)} Bq`} />
                    </dl>
                    <div className="mt-3 flex flex-wrap items-center gap-2 text-xs text-gray-600">
                      Time until
                      <input type="number" min={0.0001} max={100} step="any" value={targetPct} onChange={e => setTargetPct(Number(e.target.value))} className="h-7 w-20 rounded-md border border-gray-200 px-2 text-sm" aria-label="Percent remaining" />
                      % remains:
                      <span className="font-semibold text-gray-900">{targetPct > 0 && targetPct <= 100 ? fmtTime(lab.tTarget) : '—'}</span>
                    </div>
                    <p className="mt-2 text-[11px] text-gray-400">N = N₀·2^(−t/T½) for a single nuclide with no ingrowth from parents. Mass uses A g/mol as the molar mass.</p>
                  </>
                )}
              </Card>

              <EvidencePanel
                candidate="You chose this nuclide, decay mode or equation. Writing a balanced equation does not mean the process is observed."
                rule={{ label: `Conservation of nucleon number, charge and lepton number (${decay.bal.balanced ? 'balanced for the selected decay' : 'check the selected decay'}). Rule-of-thumb stability hints are not data.`, ok: decay.bal.balanced }}
                database={{ state: ref ? 'warn' : 'no', text: ref ? 'Half-life and decay modes come from a small hand-bundled table of ~70 well-known nuclides, rounded. Verify against NUBASE / ENSDF before quoting.' : 'No bundled data for this nuclide. Check NUBASE / ENSDF (NNDC NuDat, IAEA Live Chart).' }}
                calculated={{ state: 'no', text: 'No Q-values, binding energies or branching ratios are computed; only the decay law is evaluated.' }}
              />
              <p className="px-1 text-[10px] text-gray-400">Symbol check: {symbolOf(z)} · units of the decay lab convert with 1 y = 365.25 d.</p>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
FILEEOF

echo ""
echo "Done. npm run dev, then open /chemistry/nuclear"
