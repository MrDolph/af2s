// Composition maths: formula, molar mass, and a rule-based charge-balance check.
//
// IMPORTANT: everything here is a *rule-based assessment of a user-built
// candidate*. A balanced charge sum is necessary for a simple ionic picture,
// not evidence that the compound exists or is stable.

import { BY_SYMBOL, type Element } from './elements';

export type Composition = Record<string, number>; // symbol -> atom count

const SUB = '₀₁₂₃₄₅₆₇₈₉';
export const subscript = (n: number): string =>
  n === 1 ? '' : String(n).split('').map(d => (/\d/.test(d) ? SUB[Number(d)] : d)).join('');

export function cleanComposition(c: Composition): Composition {
  const out: Composition = {};
  for (const [s, n] of Object.entries(c)) {
    if (BY_SYMBOL[s] && Number.isFinite(n) && n > 0) out[s] = Math.round(n);
  }
  return out;
}

/** Electropositive-first for inorganic formulae; Hill order if carbon is present. */
export function orderedSymbols(c: Composition): string[] {
  const syms = Object.keys(c);
  if (c['C']) {
    const rest = syms.filter(s => s !== 'C' && s !== 'H').sort();
    return ['C', ...(c['H'] ? ['H'] : []), ...rest];
  }
  return syms.sort((a, b) => {
    const ea = BY_SYMBOL[a].en ?? 5, eb = BY_SYMBOL[b].en ?? 5;
    return ea - eb || a.localeCompare(b);
  });
}

export function formulaOf(c: Composition): string {
  const comp = cleanComposition(c);
  return orderedSymbols(comp).map(s => `${s}${subscript(comp[s])}`).join('');
}

export function formulaPlain(c: Composition): string {
  const comp = cleanComposition(c);
  return orderedSymbols(comp).map(s => `${s}${comp[s] === 1 ? '' : comp[s]}`).join('');
}

export function molarMass(c: Composition): number {
  return Object.entries(cleanComposition(c)).reduce((m, [s, n]) => m + BY_SYMBOL[s].mass * n, 0);
}

export function massFractions(c: Composition): { symbol: string; fraction: number }[] {
  const comp = cleanComposition(c);
  const total = molarMass(comp);
  return orderedSymbols(comp).map(symbol => ({ symbol, fraction: total ? (BY_SYMBOL[symbol].mass * comp[symbol]) / total : 0 }));
}

/** Reduce counts by their greatest common divisor (empirical formula). */
export function reduce(c: Composition): Composition {
  const comp = cleanComposition(c);
  const g = (a: number, b: number): number => (b ? g(b, a % b) : a);
  const d = Object.values(comp).reduce(g, 0) || 1;
  return Object.fromEntries(Object.entries(comp).map(([s, n]) => [s, n / d]));
}

export interface ChargeSolution {
  states: Record<string, number>;
  /** Number of less-common oxidation states used (0 = all “typical”). */
  unusual: number;
}

export interface ChargeReport {
  status: 'empty' | 'single' | 'balanced' | 'unbalanced' | 'too-complex' | 'no-data';
  solutions: ChargeSolution[];
  message: string;
}

const MAX_COMBOS = 400_000;

export function chargeBalance(c: Composition): ChargeReport {
  const comp = cleanComposition(c);
  const syms = orderedSymbols(comp);
  if (syms.length === 0) return { status: 'empty', solutions: [], message: 'Add elements to begin.' };
  if (syms.length === 1) {
    return { status: 'single', solutions: [], message: 'A single element — no charge balance to check (formal oxidation state 0).' };
  }
  const noData = syms.filter(s => {
    const e: Element = BY_SYMBOL[s];
    return e.common.length + e.other.length === 0;
  });
  if (noData.length) {
    return { status: 'no-data', solutions: [], message: `No established oxidation states are tabulated for ${noData.join(', ')}.` };
  }

  const options = syms.map(s => {
    const e = BY_SYMBOL[s];
    return [...e.common.map(v => ({ v, unusual: 0 })), ...e.other.map(v => ({ v, unusual: 1 }))];
  });
  const combos = options.reduce((p, o) => p * o.length, 1);
  if (combos > MAX_COMBOS) {
    return { status: 'too-complex', solutions: [], message: 'Too many elements to enumerate oxidation states here; try fewer elements.' };
  }

  const found: ChargeSolution[] = [];
  const pick: number[] = new Array(syms.length).fill(0);
  const rec = (i: number, sum: number, unusual: number) => {
    if (i === syms.length) {
      if (Math.abs(sum) < 1e-9) {
        found.push({ states: Object.fromEntries(syms.map((s, k) => [s, pick[k]])), unusual });
      }
      return;
    }
    for (const o of options[i]) {
      pick[i] = o.v;
      rec(i + 1, sum + o.v * comp[syms[i]], unusual + o.unusual);
    }
  };
  rec(0, 0, 0);

  // Prefer solutions that use only common states; drop all-same-sign "solutions" (impossible
  // anyway since the sum is zero) and keep a short, deterministic list.
  found.sort((a, b) => a.unusual - b.unusual);
  const solutions = found.slice(0, 6);
  if (!solutions.length) {
    return {
      status: 'unbalanced',
      solutions: [],
      message: 'No combination of tabulated oxidation states sums to zero. The compound may be metallic/intermetallic, mixed-valence, or simply not an ionic composition.',
    };
  }
  const typical = solutions[0].unusual === 0;
  return {
    status: 'balanced',
    solutions,
    message: typical
      ? 'Charges can balance using common oxidation states. This is a rule-of-thumb check, not proof the compound exists.'
      : 'Charges balance only if a less-common oxidation state is used — treat with extra caution.',
  };
}
