#!/bin/bash
# A-Factor STEM Studio — Chemistry playground, part 5: Organic molecules (v82) — the last module
# Run inside af2s/ (the project ROOT) AFTER patch-v76 ... v80 (v81, the font fix, is independent):
#     bash patches/patch-v82-organic.sh
#
# ADDS   /chemistry/organic
#   - Molecule editor: Move / Add atom / Bond / Erase tools, elements C N O S P F Cl Br I, auto-bond chain drawing,
#     bond cycling (single -> double -> triple -> none), undo, skeletal or labelled style; touch friendly
#   - Hydrogens fill in automatically from valence; over-valent atoms are flagged in red
#   - Computed from the bond graph: formula, molar mass, degrees of unsaturation, SMILES, functional groups
#     (alcohol, ether, aldehyde, ketone, acid, ester, amide, amines, nitrile, alkene, alkyne, halides, thiol, aromatic ring...)
#   - Recognises a drawing against a built-in library of 63 molecules (graph isomorphism, so any drawing of
#     ethanol is found) and lists constitutional isomers of the same formula; six ready-made isomer sets
#   - SMILES input (organic subset, aromatic rings, branches, ring closures) with clear error messages
#   - Save candidate, copy SMILES, download .mol (V2000), open composition in the compound builder
# NOT MODELLED  charges, radicals, stereochemistry (cis/trans, R/S), 3D geometry, energies, pKa, spectra
# UPDATES candidates.ts (candidate kind 'organic'); /chemistry hub (Organic card now Live; no cards remain "Coming soon")
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -d src ]; then echo "ERROR: run from the project root (package.json + src/)."; exit 1; fi
if [ ! -f src/lib/chemistry/crystal.ts ]; then echo "ERROR: apply patch-v76 ... v80 first."; exit 1; fi

echo "Applying Organic molecules (v82)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/chemistry/organic.ts << 'FILEEOF'
// Organic molecules: a small molecular-graph toolkit for the playground.
//
// A molecule is a graph of heavy atoms and bonds (orders 1–3); hydrogens are IMPLICIT and filled
// from standard valences. Everything reported (formula, mass, degrees of unsaturation, functional
// groups, "same structure" matching) is derived from that graph by explicit rules.
//
// Not modelled: charges, radicals, stereochemistry (cis/trans, R/S), fused-ring layout polish,
// 3D geometry or energies.

import { formulaOf, molarMass, type Composition } from './compound';

export interface MAtom { el: string; x: number; y: number }
export interface MBond { a: number; b: number; order: number }
export interface Mol { atoms: MAtom[]; bonds: MBond[] }

export const PALETTE = ['C', 'N', 'O', 'S', 'P', 'F', 'Cl', 'Br', 'I'] as const;
const VALENCES: Record<string, number[]> = { C: [4], N: [3], O: [2], S: [2, 4, 6], P: [3, 5], F: [1], Cl: [1], Br: [1], I: [1] };
const HALOGENS = new Set(['F', 'Cl', 'Br', 'I']);
export const BOND_PX = 44;

// ── Basic graph helpers ───────────────────────────────────────────────────────
export interface Nbr { to: number; order: number; bi: number }
export function adjacency(m: Mol): Nbr[][] {
  const adj: Nbr[][] = m.atoms.map(() => []);
  m.bonds.forEach((b, bi) => { adj[b.a].push({ to: b.b, order: b.order, bi }); adj[b.b].push({ to: b.a, order: b.order, bi }); });
  return adj;
}

export function valenceInfo(m: Mol): { h: number[]; bad: number[] } {
  const adj = adjacency(m);
  const h: number[] = [], bad: number[] = [];
  m.atoms.forEach((a, i) => {
    const used = adj[i].reduce((s, e) => s + e.order, 0);
    const v = (VALENCES[a.el] ?? []).find(x => x >= used);
    if (v === undefined) { h.push(0); bad.push(i); } else h.push(v - used);
  });
  return { h, bad };
}

export function components(m: Mol): number {
  const adj = adjacency(m);
  const seen = new Array(m.atoms.length).fill(false);
  let c = 0;
  for (let i = 0; i < m.atoms.length; i++) {
    if (seen[i]) continue;
    c++;
    const st = [i]; seen[i] = true;
    while (st.length) { const u = st.pop()!; for (const e of adj[u]) if (!seen[e.to]) { seen[e.to] = true; st.push(e.to); } }
  }
  return c;
}

export function composition(m: Mol): Composition {
  const { h } = valenceInfo(m);
  const comp: Composition = {};
  m.atoms.forEach(a => { comp[a.el] = (comp[a.el] ?? 0) + 1; });
  const H = h.reduce((s, x) => s + x, 0);
  if (H > 0) comp.H = H;
  return comp;
}
export const formulaText = (m: Mol) => formulaOf(composition(m));
export const massOf = (m: Mol) => molarMass(composition(m));

/** Degrees of unsaturation (rings + π bonds) from the molecular formula. */
export function dbe(m: Mol): number | null {
  const c = composition(m);
  const g = (s: string) => c[s] ?? 0;
  const x = ['F', 'Cl', 'Br', 'I'].reduce((s, e) => s + g(e), 0);
  const v = (2 * g('C') + 2 + g('N') + g('P') - g('H') - x) / 2;
  return Number.isInteger(v) && v >= 0 ? v : null;
}

// ── Rings (smallest set of independent cycles) and aromaticity ───────────────
export function rings(m: Mol): number[][] {
  const adj = adjacency(m);
  const nb = m.bonds.length;
  const target = nb - m.atoms.length + components(m);
  if (target <= 0) return [];
  const cycles = new Map<string, { atoms: number[]; bonds: number[] }>();
  m.bonds.forEach((e, ei) => {
    const prev = new Map<number, { from: number; bi: number }>();
    const q = [e.a]; prev.set(e.a, { from: -1, bi: -1 });
    while (q.length && !prev.has(e.b)) {
      const u = q.shift()!;
      for (const n of adj[u]) if (n.bi !== ei && !prev.has(n.to)) { prev.set(n.to, { from: u, bi: n.bi }); q.push(n.to); }
    }
    if (!prev.has(e.b)) return;
    const atoms: number[] = [], bonds: number[] = [ei];
    for (let cur = e.b; cur !== -1;) { atoms.push(cur); const p = prev.get(cur)!; if (p.bi >= 0) bonds.push(p.bi); cur = p.from; }
    atoms.reverse();
    const key = [...bonds].sort((x, y) => x - y).join(',');
    if (!cycles.has(key)) cycles.set(key, { atoms, bonds });
  });
  const sorted = [...cycles.values()].sort((a, b) => a.atoms.length - b.atoms.length);
  const basis: boolean[][] = [];
  const out: number[][] = [];
  for (const c of sorted) {
    const vec = new Array(nb).fill(false); c.bonds.forEach(b => { vec[b] = true; });
    const reduced = vec.slice();
    for (const row of basis) { const p = row.indexOf(true); if (reduced[p]) for (let k = 0; k < nb; k++) reduced[k] = reduced[k] !== row[k]; }
    if (reduced.includes(true)) { basis.push(reduced); out.push(c.atoms); if (out.length === target) break; }
  }
  return out;
}

export function aromaticInfo(m: Mol): { rings: number[][]; atoms: Set<number>; bonds: Set<number> } {
  const key = (a: number, b: number) => (a < b ? `${a}-${b}` : `${b}-${a}`);
  const bondAt = new Map(m.bonds.map((b, i) => [key(b.a, b.b), i]));
  const ar: number[][] = [], atoms = new Set<number>(), bonds = new Set<number>();
  for (const r of rings(m)) {
    if (r.length !== 6 || !r.every(a => m.atoms[a].el === 'C' || m.atoms[a].el === 'N')) continue;
    const bi = r.map((a, k) => bondAt.get(key(a, r[(k + 1) % 6]))!);
    const ord = bi.map(i => m.bonds[i].order);
    if (ord.every((o, k) => (o === 1 || o === 2) && o !== ord[(k + 1) % 6])) { ar.push(r); r.forEach(a => atoms.add(a)); bi.forEach(i => bonds.add(i)); }
  }
  return { rings: ar, atoms, bonds };
}

// ── Functional groups ────────────────────────────────────────────────────────
export interface Group { label: string; count: number }

export function functionalGroups(m: Mol): Group[] {
  const adj = adjacency(m);
  const { h } = valenceInfo(m);
  const ar = aromaticInfo(m);
  const el = (i: number) => m.atoms[i].el;
  const counts = new Map<string, number>();
  const add = (l: string) => counts.set(l, (counts.get(l) ?? 0) + 1);
  const carbonylO = (i: number) => adj[i].find(e => e.order === 2 && el(e.to) === 'O' && adj[e.to].length === 1);
  const isCarbonyl = (i: number) => el(i) === 'C' && !!carbonylO(i);

  m.atoms.forEach((a, i) => {
    if (a.el === 'C') {
      const co = carbonylO(i);
      if (co) {
        const others = adj[i].filter(e => e !== co);
        const oh = others.some(e => el(e.to) === 'O' && e.order === 1 && h[e.to] > 0);
        const or = others.some(e => el(e.to) === 'O' && e.order === 1 && h[e.to] === 0);
        const nn = others.some(e => el(e.to) === 'N' && e.order === 1);
        const x = others.some(e => HALOGENS.has(el(e.to)));
        if (oh) add('Carboxylic acid'); else if (or) add('Ester'); else if (nn) add('Amide'); else if (x) add('Acyl halide');
        else if (h[i] > 0) add('Aldehyde'); else if (others.filter(e => el(e.to) === 'C').length === 2) add('Ketone');
      }
    } else if (a.el === 'O' && adj[i].length >= 1) {
      const heavy = adj[i].filter(e => e.order === 1);
      if (h[i] > 0 && heavy.length === 1 && el(heavy[0].to) === 'C' && !isCarbonyl(heavy[0].to)) add(ar.atoms.has(heavy[0].to) ? 'Phenol' : 'Alcohol');
      else if (heavy.length === 2 && heavy.every(e => el(e.to) === 'C') && !heavy.some(e => isCarbonyl(e.to))) add('Ether');
    } else if (a.el === 'N') {
      const hv = adj[i];
      if (hv.every(e => e.order === 1 && el(e.to) === 'C' && !isCarbonyl(e.to)) && hv.length >= 1) add(['Primary amine', 'Secondary amine', 'Tertiary amine'][hv.length - 1]);
    } else if (a.el === 'S') {
      const hv = adj[i].filter(e => e.order === 1 && el(e.to) === 'C');
      if (h[i] > 0 && hv.length === 1) add('Thiol'); else if (hv.length === 2 && adj[i].length === 2) add('Thioether');
    }
  });
  m.bonds.forEach((b, bi) => {
    const e1 = el(b.a), e2 = el(b.b), set = [e1, e2].sort().join('');
    if (set === 'CC' && b.order === 2 && !ar.bonds.has(bi)) add('Alkene');
    if (set === 'CC' && b.order === 3) add('Alkyne');
    if (set === 'CN' && b.order === 3) add('Nitrile');
    if (set === 'CN' && b.order === 2 && !ar.bonds.has(bi)) add('Imine');
    const [c, x] = e1 === 'C' ? [b.a, b.b] : e2 === 'C' ? [b.b, b.a] : [-1, -1];
    if (c >= 0 && HALOGENS.has(el(x)) && !isCarbonyl(c)) add(ar.atoms.has(c) ? 'Aryl halide' : 'Alkyl halide');
  });
  if (ar.rings.length) counts.set('Aromatic ring', ar.rings.length);
  return [...counts.entries()].map(([label, count]) => ({ label, count }));
}

// ── Same-structure test (graph isomorphism on element + bond order) ──────────
export function sameStructure(a: Mol, b: Mol): boolean {
  if (a.atoms.length !== b.atoms.length || a.bonds.length !== b.bonds.length) return false;
  const n = a.atoms.length;
  const A = adjacency(a), B = adjacency(b);
  const orderOf = (adj: Nbr[][], u: number, v: number) => adj[u].find(e => e.to === v)?.order ?? 0;
  const sig = (m: Mol, adj: Nbr[][], i: number) => `${m.atoms[i].el}:${adj[i].map(e => e.order).sort().join('')}`;
  const sa = a.atoms.map((_, i) => sig(a, A, i)), sb = b.atoms.map((_, i) => sig(b, B, i));
  if ([...sa].sort().join('|') !== [...sb].sort().join('|')) return false;
  // Match atoms in BFS order so each new atom is constrained by an already-mapped neighbour.
  const order: number[] = [], seen = new Array(n).fill(false);
  for (let s = 0; s < n; s++) {
    if (seen[s]) continue;
    seen[s] = true; const q = [s];
    while (q.length) { const u = q.shift()!; order.push(u); for (const e of A[u]) if (!seen[e.to]) { seen[e.to] = true; q.push(e.to); } }
  }
  const map = new Array(n).fill(-1), used = new Array(n).fill(false);
  let budget = 300000;
  const rec = (k: number): boolean => {
    if (k === n) return true;
    if (--budget < 0) return false;
    const u = order[k];
    for (let v = 0; v < n; v++) {
      if (used[v] || sa[u] !== sb[v]) continue;
      let ok = true, mappedA = 0, mappedB = 0;
      for (const e of A[u]) if (map[e.to] >= 0) { mappedA++; if (orderOf(B, v, map[e.to]) !== e.order) { ok = false; break; } }
      if (!ok) continue;
      for (const e of B[v]) if (used[e.to]) mappedB++;
      if (mappedA !== mappedB) continue;
      map[u] = v; used[v] = true;
      if (rec(k + 1)) return true;
      map[u] = -1; used[v] = false;
    }
    return false;
  };
  return rec(0);
}

// ── SMILES (organic subset: C N O S P F Cl Br I, aromatic c n o s, branches, rings, = # bonds) ──
export function parseSmiles(src: string): { mol?: Mol; error?: string } {
  const s = src.trim();
  if (!s) return { error: 'Enter a SMILES string, e.g. CCO or c1ccccc1.' };
  const atoms: { el: string; arom: boolean; hExplicit: boolean }[] = [];
  const bonds: { a: number; b: number; order: number | 'ar' }[] = [];
  const stack: number[] = [];
  const open = new Map<number, { atom: number; order: number | 'ar' | null }>();
  let prev = -1, pending: number | 'ar' | null = null;
  const addAtom = (el: string, arom: boolean, hExplicit = false) => {
    const idx = atoms.push({ el, arom, hExplicit }) - 1;
    if (prev >= 0) bonds.push({ a: prev, b: idx, order: pending ?? (arom && atoms[prev].arom ? 'ar' : 1) });
    pending = null; prev = idx;
  };
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (ch === '(') { if (prev < 0) return { error: 'A branch “(” needs an atom before it.' }; stack.push(prev); }
    else if (ch === ')') { if (!stack.length) return { error: 'Unmatched “)”.' }; prev = stack.pop()!; }
    else if (ch === '-') pending = 1;
    else if (ch === '=') pending = 2;
    else if (ch === '#') pending = 3;
    else if (ch === ':') pending = 'ar';
    else if (ch === '.') return { error: 'Separate molecules (“.”) are not supported — enter one molecule.' };
    else if (/[0-9%]/.test(ch)) {
      let label = Number(ch);
      if (ch === '%') { label = Number(s.slice(i + 1, i + 3)); i += 2; }
      if (prev < 0) return { error: 'A ring digit needs an atom before it.' };
      const o = open.get(label);
      if (o) {
        if (o.atom === prev) return { error: 'A ring closure cannot join an atom to itself.' };
        bonds.push({ a: o.atom, b: prev, order: pending ?? o.order ?? (atoms[o.atom].arom && atoms[prev].arom ? 'ar' : 1) });
        open.delete(label);
      } else open.set(label, { atom: prev, order: pending });
      pending = null;
    } else if (ch === '[') {
      const end = s.indexOf(']', i);
      if (end < 0) return { error: 'Missing “]”.' };
      const inner = s.slice(i + 1, end);
      const m = inner.match(/^([A-Z][a-z]?|[cnos])(H\d?)?$/);
      if (!m) return { error: `Bracket atom “[${inner}]” is not supported (charges, isotopes and stereochemistry are not modelled).` };
      const arom = m[1] === m[1].toLowerCase();
      const el = arom ? m[1].toUpperCase() : m[1];
      if (!VALENCES[el]) return { error: `Element “${el}” is not supported. Use C, N, O, S, P, F, Cl, Br or I.` };
      addAtom(el, arom, !!m[2]);
      i = end;
    } else if (s.startsWith('Cl', i)) { addAtom('Cl', false); i++; }
    else if (s.startsWith('Br', i)) { addAtom('Br', false); i++; }
    else if ('CNOSPFI'.includes(ch)) addAtom(ch, false);
    else if ('cnos'.includes(ch)) addAtom(ch.toUpperCase(), true);
    else return { error: `Unexpected character “${ch}”.` };
  }
  if (open.size) return { error: 'A ring was opened but never closed.' };
  if (stack.length) return { error: 'Missing “)”.' };
  if (!atoms.length) return { error: 'No atoms found.' };
  if (pending !== null) return { error: 'A bond symbol must be followed by an atom.' };

  // Kekulé form for aromatic bonds: find a perfect matching of double bonds.
  const arBonds = bonds.map((b, i) => ({ b, i })).filter(x => x.b.order === 'ar');
  if (arBonds.length) {
    const deg = new Array(atoms.length).fill(0);
    bonds.forEach(b => { deg[b.a]++; deg[b.b]++; });
    const need = atoms.map((a, i) => a.arom && (a.el === 'C' || (a.el === 'N' && !a.hExplicit && deg[i] === 2)));
    const matched = new Array(atoms.length).fill(false);
    const chosen = new Set<number>();
    const solve = (): boolean => {
      const u = need.findIndex((n, i) => n && !matched[i]);
      if (u < 0) return true;
      for (const { b, i } of arBonds) {
        const v = b.a === u ? b.b : b.b === u ? b.a : -1;
        if (v < 0 || !need[v] || matched[v]) continue;
        matched[u] = matched[v] = true; chosen.add(i);
        if (solve()) return true;
        matched[u] = matched[v] = false; chosen.delete(i);
      }
      return false;
    };
    if (!solve()) return { error: 'Could not assign alternating double bonds to the aromatic ring.' };
    bonds.forEach((b, i) => { if (b.order === 'ar') b.order = chosen.has(i) ? 2 : 1; });
  }
  return { mol: { atoms: atoms.map(a => ({ el: a.el, x: 0, y: 0 })), bonds: bonds.map(b => ({ a: b.a, b: b.b, order: b.order as number })) } };
}

export function toSmiles(m: Mol): string {
  const n = m.atoms.length;
  if (!n) return '';
  const adj = adjacency(m);
  const visited = new Array(n).fill(false);
  const parentBond = new Array(n).fill(-1);
  const children: { to: number; bi: number }[][] = m.atoms.map(() => []);
  const closures: { bi: number; digit: number }[][] = m.atoms.map(() => []);
  const closureSeen = new Set<number>();
  let nextDigit = 1;
  const dfs = (u: number) => {
    visited[u] = true;
    for (const e of adj[u]) {
      if (e.bi === parentBond[u]) continue;
      if (!visited[e.to]) { parentBond[e.to] = e.bi; children[u].push({ to: e.to, bi: e.bi }); dfs(e.to); }
      else if (!closureSeen.has(e.bi)) { closureSeen.add(e.bi); const d = nextDigit++; closures[u].push({ bi: e.bi, digit: d }); closures[e.to].push({ bi: e.bi, digit: d }); }
    }
  };
  const parts: string[] = [];
  for (let s = 0; s < n; s++) if (!visited[s]) { dfs(s); parts.push(String(s)); }
  const sym = (o: number) => (o === 2 ? '=' : o === 3 ? '#' : '');
  const emit = (u: number): string => {
    let out = m.atoms[u].el;
    for (const c of closures[u]) out += (m.bonds[c.bi].order > 1 && c.digit >= 0 && closures[u][0] === c ? sym(m.bonds[c.bi].order) : '') + (c.digit > 9 ? `%${c.digit}` : c.digit);
    const ch = children[u];
    ch.forEach((c, k) => { const piece = sym(m.bonds[c.bi].order) + emit(c.to); out += k < ch.length - 1 ? `(${piece})` : piece; });
    return out;
  };
  return parts.map(p => emit(Number(p))).join('.');
}

// ── 2D layout (bond length 1 unit; rings as regular polygons, chains zig-zag) ──
type P = { x: number; y: number };
const TAU = Math.PI * 2;
const norm = (a: number) => ((a % TAU) + TAU) % TAU;

export function layoutUnits(m: Mol): P[] {
  const n = m.atoms.length;
  const adj = adjacency(m);
  const rs = rings(m);
  const pos: (P | null)[] = new Array(n).fill(null);
  const ringPlaced = new Set<number[]>();
  const sign: number[] = new Array(n).fill(1);
  const queue: number[] = [];
  const R = (k: number) => 1 / (2 * Math.sin(Math.PI / k));

  const placePolygon = (ring: number[], start: number, at: P, outward: number | null) => {
    const k = ring.length, r = R(k);
    const i0 = ring.indexOf(start);
    const order = ring.map((_, j) => ring[(i0 + j) % k]);
    let cx = 0, cy = 0, phi0 = -Math.PI / 2;
    if (outward === null) { cx = at.x; cy = at.y; }
    else { cx = at.x + r * Math.cos(outward); cy = at.y + r * Math.sin(outward); phi0 = Math.atan2(at.y - cy, at.x - cx); }
    order.forEach((a, j) => {
      const ang = phi0 + (TAU * j) / k;
      if (outward === null) pos[a] = { x: cx + r * Math.cos(ang), y: cy + r * Math.sin(ang) };
      else if (j === 0) pos[a] = at;
      else pos[a] = { x: cx + r * Math.cos(ang), y: cy + r * Math.sin(ang) };
    });
    ringPlaced.add(ring);
    order.forEach(a => queue.push(a));
  };

  const place = (u: number) => {
    const here = pos[u]!;
    const free = adj[u].filter(e => !pos[e.to]);
    if (!free.length) return;
    const known = adj[u].filter(e => pos[e.to]).map(e => norm(Math.atan2(pos[e.to]!.y - here.y, pos[e.to]!.x - here.x))).sort((a, b) => a - b);
    const k = free.length;
    let angles: number[];
    const inRing = rs.some(r => r.includes(u));
    if (!known.length) angles = k === 1 ? [0] : k === 2 ? [-Math.PI / 3, Math.PI / 3] : free.map((_, i) => -Math.PI / 2 + (TAU * i) / k);
    else if (known.length === 1 && k === 1 && !inRing) { angles = [known[0] + Math.PI + sign[u] * (Math.PI / 3)]; }
    else {
      let gap = 0, start = 0;
      known.forEach((a, i) => { const nx = i === known.length - 1 ? known[0] + TAU : known[i + 1]; if (nx - a > gap) { gap = nx - a; start = a; } });
      angles = free.map((_, i) => start + (gap * (i + 1)) / (k + 1));
    }
    free.forEach((e, i) => {
      if (pos[e.to]) return;
      const th = angles[i];
      const at = { x: here.x + Math.cos(th), y: here.y + Math.sin(th) };
      const ring = rs.find(r => r.includes(e.to) && !ringPlaced.has(r) && r.every(a => !pos[a]));
      if (ring && !rs.some(r => r.includes(u) && r.includes(e.to))) placePolygon(ring, e.to, at, th);
      else { pos[e.to] = at; sign[e.to] = -sign[u]; queue.push(e.to); }
    });
  };

  let offsetX = 0;
  for (let s = 0; s < n; s++) {
    if (pos[s]) continue;
    const ring = rs.find(r => r.includes(s) && r.every(a => !pos[a]));
    const before = pos.map(p => p !== null);
    if (ring) placePolygon(ring, s, { x: 0, y: 0 }, null); else { pos[s] = { x: 0, y: 0 }; queue.push(s); }
    while (queue.length) place(queue.shift()!);
    // Shift this component right of everything placed before it.
    const mine = pos.map((p, i) => (p && !before[i] ? i : -1)).filter(i => i >= 0);
    const minX = Math.min(...mine.map(i => pos[i]!.x));
    const dx = offsetX - minX;
    mine.forEach(i => { pos[i] = { x: pos[i]!.x + dx, y: pos[i]!.y }; });
    offsetX = Math.max(...mine.map(i => pos[i]!.x)) + 1.6;
  }
  const out = pos.map(p => p ?? { x: 0, y: 0 });

  // Fallback for crowded layouts (fused rings etc.): short spring relaxation.
  let crowded = false;
  for (let i = 0; i < n && !crowded; i++) for (let j = i + 1; j < n; j++) if (Math.hypot(out[i].x - out[j].x, out[i].y - out[j].y) < 0.55) { crowded = true; break; }
  if (crowded) {
    for (let it = 0; it < 120; it++) {
      const f = out.map(() => ({ x: 0, y: 0 }));
      m.bonds.forEach(b => {
        const dx = out[b.b].x - out[b.a].x, dy = out[b.b].y - out[b.a].y, d = Math.hypot(dx, dy) || 1e-3, k = (d - 1) * 0.3;
        f[b.a].x += (dx / d) * k; f[b.a].y += (dy / d) * k; f[b.b].x -= (dx / d) * k; f[b.b].y -= (dy / d) * k;
      });
      for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
        const dx = out[j].x - out[i].x, dy = out[j].y - out[i].y, d = Math.hypot(dx, dy) || 1e-3;
        if (d < 1.1) { const k = (1.1 - d) * 0.15; f[i].x -= (dx / d) * k; f[i].y -= (dy / d) * k; f[j].x += (dx / d) * k; f[j].y += (dy / d) * k; }
      }
      out.forEach((p, i) => { p.x += f[i].x; p.y += f[i].y; });
    }
  }
  return out;
}

/** Lay a molecule out and fit it centred in a w×h box (bond length capped at BOND_PX). */
export function placeMol(m: Mol, w = 640, h = 340, pad = 40): Mol {
  if (!m.atoms.length) return m;
  const u = layoutUnits(m);
  const xs = u.map(p => p.x), ys = u.map(p => p.y);
  const bw = Math.max(...xs) - Math.min(...xs), bh = Math.max(...ys) - Math.min(...ys);
  const sc = Math.min(BOND_PX, bw > 0 ? (w - 2 * pad) / bw : BOND_PX, bh > 0 ? (h - 2 * pad) / bh : BOND_PX);
  const cx = (Math.max(...xs) + Math.min(...xs)) / 2, cy = (Math.max(...ys) + Math.min(...ys)) / 2;
  return { ...m, atoms: m.atoms.map((a, i) => ({ ...a, x: w / 2 + (u[i].x - cx) * sc, y: h / 2 + (u[i].y - cy) * sc })) };
}

// ── MOL file export (V2000) ───────────────────────────────────────────────────
export function toMolfile(m: Mol, name = 'molecule'): string {
  const f = (v: number) => v.toFixed(4).padStart(10);
  const cx = m.atoms.length ? m.atoms.reduce((t, a) => t + a.x, 0) / m.atoms.length : 0;
  const cy = m.atoms.length ? m.atoms.reduce((t, a) => t + a.y, 0) / m.atoms.length : 0;
  const lines = [name, '  A-Factor STEM Studio', '', `${String(m.atoms.length).padStart(3)}${String(m.bonds.length).padStart(3)}  0  0  0  0  0  0  0  0999 V2000`];
  m.atoms.forEach(a => lines.push(`${f(((a.x - cx) / BOND_PX) * 1.5)}${f((-(a.y - cy) / BOND_PX) * 1.5)}${f(0)} ${a.el.padEnd(3)} 0  0  0  0  0  0  0  0  0  0  0  0`));
  m.bonds.forEach(b => lines.push(`${String(b.a + 1).padStart(3)}${String(b.b + 1).padStart(3)}${String(b.order).padStart(3)}  0`));
  lines.push('M  END', '');
  return lines.join('\n');
}

// ── Editing helpers ───────────────────────────────────────────────────────────
export function removeAtom(m: Mol, idx: number): Mol {
  return {
    atoms: m.atoms.filter((_, i) => i !== idx),
    bonds: m.bonds.filter(b => b.a !== idx && b.b !== idx).map(b => ({ a: b.a > idx ? b.a - 1 : b.a, b: b.b > idx ? b.b - 1 : b.b, order: b.order })),
  };
}
/** Cycle bond between two atoms: none → single → double → triple → none. */
export function cycleBond(m: Mol, a: number, b: number): Mol {
  if (a === b) return m;
  const i = m.bonds.findIndex(x => (x.a === a && x.b === b) || (x.a === b && x.b === a));
  if (i < 0) return { ...m, bonds: [...m.bonds, { a, b, order: 1 }] };
  const o = m.bonds[i].order;
  if (o >= 3) return { ...m, bonds: m.bonds.filter((_, k) => k !== i) };
  return { ...m, bonds: m.bonds.map((x, k) => (k === i ? { ...x, order: o + 1 } : x)) };
}

// ── Library ───────────────────────────────────────────────────────────────────
export interface Preset { name: string; smiles: string; group: string }
const P = (group: string, items: [string, string][]): Preset[] => items.map(([name, smiles]) => ({ name, smiles, group }));
export const LIBRARY: Preset[] = [
  ...P('Alkanes', [['Methane', 'C'], ['Ethane', 'CC'], ['Propane', 'CCC'], ['Butane', 'CCCC'], ['Isobutane (2-methylpropane)', 'CC(C)C'], ['Pentane', 'CCCCC'], ['Cyclopentane', 'C1CCCC1'], ['Cyclohexane', 'C1CCCCC1']]),
  ...P('Alkenes & alkynes', [['Ethene', 'C=C'], ['Propene', 'C=CC'], ['But-1-ene', 'C=CCC'], ['But-2-ene', 'CC=CC'], ['2-Methylpropene', 'CC(C)=C'], ['Cyclobutane', 'C1CCC1'], ['1,3-Butadiene', 'C=CC=C'], ['Ethyne (acetylene)', 'C#C'], ['Propyne', 'CC#C']]),
  ...P('Alcohols & ethers', [['Methanol', 'CO'], ['Ethanol', 'CCO'], ['Propan-1-ol', 'CCCO'], ['Propan-2-ol', 'CC(C)O'], ['Ethane-1,2-diol', 'OCCO'], ['Glycerol', 'OCC(O)CO'], ['Dimethyl ether', 'COC'], ['Methoxyethane', 'CCOC'], ['Diethyl ether', 'CCOCC']]),
  ...P('Aldehydes & ketones', [['Formaldehyde', 'C=O'], ['Acetaldehyde', 'CC=O'], ['Propanal', 'CCC=O'], ['Acetone', 'CC(C)=O'], ['Butanone', 'CCC(C)=O']]),
  ...P('Acids, esters & amides', [['Formic acid', 'OC=O'], ['Acetic acid', 'CC(O)=O'], ['Propanoic acid', 'CCC(O)=O'], ['Butanoic acid', 'CCCC(O)=O'], ['Methyl formate', 'COC=O'], ['Methyl acetate', 'COC(C)=O'], ['Ethyl acetate', 'CCOC(C)=O'], ['Acetamide', 'CC(N)=O'], ['Urea', 'NC(N)=O'], ['Acetyl chloride', 'CC(Cl)=O']]),
  ...P('Amines & nitriles', [['Methylamine', 'CN'], ['Ethylamine', 'CCN'], ['Dimethylamine', 'CNC'], ['Trimethylamine', 'CN(C)C'], ['Acetonitrile', 'CC#N'], ['Glycine', 'NCC(O)=O']]),
  ...P('Aromatics', [['Benzene', 'c1ccccc1'], ['Toluene', 'Cc1ccccc1'], ['Phenol', 'Oc1ccccc1'], ['Aniline', 'Nc1ccccc1'], ['Benzaldehyde', 'O=Cc1ccccc1'], ['Benzoic acid', 'OC(=O)c1ccccc1'], ['Chlorobenzene', 'Clc1ccccc1'], ['Pyridine', 'c1ccncc1']]),
  ...P('Halides & sulfur', [['Chloromethane', 'CCl'], ['Dichloromethane', 'ClCCl'], ['Chloroform', 'ClC(Cl)Cl'], ['Chloroethane', 'CCCl'], ['Bromoethane', 'CCBr'], ['Methanethiol', 'CS'], ['Ethanethiol', 'CCS'], ['Dimethyl sulfide', 'CSC']]),
];

export const ISOMER_SETS: { formula: string; names: string[] }[] = [
  { formula: 'C₄H₁₀', names: ['Butane', 'Isobutane (2-methylpropane)'] },
  { formula: 'C₂H₆O', names: ['Ethanol', 'Dimethyl ether'] },
  { formula: 'C₃H₆O', names: ['Acetone', 'Propanal'] },
  { formula: 'C₃H₈O', names: ['Propan-1-ol', 'Propan-2-ol', 'Methoxyethane'] },
  { formula: 'C₄H₈', names: ['But-1-ene', 'But-2-ene', '2-Methylpropene', 'Cyclobutane'] },
  { formula: 'C₄H₈O₂', names: ['Butanoic acid', 'Ethyl acetate'] },
];

let libCache: { p: Preset; mol: Mol; key: string }[] | null = null;
export function library() {
  if (!libCache) libCache = LIBRARY.map(p => { const mol = parseSmiles(p.smiles).mol!; return { p, mol, key: formulaText(mol) }; });
  return libCache;
}
export const loadPreset = (name: string, w = 640, h = 340): Mol | null => {
  const hit = library().find(x => x.p.name === name);
  return hit ? placeMol(hit.mol, w, h) : null;
};
/** Library lookups for an arbitrary drawn molecule. */
export function identify(m: Mol): { same: string | null; isomers: string[] } {
  if (!m.atoms.length) return { same: null, isomers: [] };
  const key = formulaText(m);
  const same = library().find(x => x.key === key && sameStructure(m, x.mol));
  const isomers = library().filter(x => x.key === key && x !== same).map(x => x.p.name);
  return { same: same?.p.name ?? null, isomers };
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
  kind: 'composition' | 'perovskite' | 'heusler' | 'crystal' | 'organic';
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
  organic?: {
    atoms: { el: string; x: number; y: number }[];
    bonds: { a: number; b: number; order: number }[];
    smiles: string;
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

write_file src/components/chemistry/MoleculeEditor.tsx << 'FILEEOF'
'use client';
import { useRef } from 'react';
import { cycleBond, removeAtom, valenceInfo, type Mol } from '@/lib/chemistry/organic';

export type Tool = 'move' | 'atom' | 'bond' | 'erase';
export const H = 340;
const SUB = '₀₁₂₃₄₅₆₇₈₉';
const sub = (n: number) => String(n).split('').map(d => SUB[Number(d)]).join('');
const COLORS: Record<string, string> = { O: '#dc2626', N: '#2563eb', S: '#b45309', P: '#c2410c', F: '#15803d', Cl: '#15803d', Br: '#9a3412', I: '#7e22ce', C: '#111827' };

interface Props {
  mol: Mol;
  tool: Tool;
  element: string;
  selected: number | null;
  autoBond: boolean;
  skeletal: boolean;
  /** Width of the drawing space in SVG units (narrower on phones so atoms stay legible). */
  width: number;
  /** Replace the molecule without recording undo (used while dragging). */
  onLive: (m: Mol) => void;
  /** Replace the molecule and record an undo step. */
  onCommit: (m: Mol) => void;
  onSelect: (i: number | null) => void;
  /** Called once when a drag starts, so the page can record an undo step. */
  onDragStart: () => void;
}

function segDist(px: number, py: number, ax: number, ay: number, bx: number, by: number) {
  const dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy || 1;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / l2));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

export function MoleculeEditor({ mol, tool, element, selected, autoBond, skeletal, width: W, onLive, onCommit, onSelect, onDragStart }: Props) {
  const svgRef = useRef<SVGSVGElement>(null);
  const drag = useRef<number | null>(null);
  const { h, bad } = valenceInfo(mol);
  const badSet = new Set(bad);
  const deg = mol.atoms.map(() => 0);
  mol.bonds.forEach(b => { deg[b.a]++; deg[b.b]++; });

  const labelled = (i: number) => !skeletal || mol.atoms[i].el !== 'C' || deg[i] === 0;
  const text = (i: number) => {
    const a = mol.atoms[i];
    if (skeletal && a.el === 'C' && deg[i] === 0) return `CH${h[i] > 1 ? sub(h[i]) : ''}`;
    return `${a.el}${h[i] > 0 && !(skeletal && a.el === 'C') ? 'H' + (h[i] > 1 ? sub(h[i]) : '') : ''}`;
  };

  const point = (e: React.PointerEvent) => {
    const r = svgRef.current!.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * W, y: ((e.clientY - r.top) / r.height) * H };
  };
  const hitAtom = (p: { x: number; y: number }) => {
    let best = -1, bd = 18;
    mol.atoms.forEach((a, i) => { const d = Math.hypot(a.x - p.x, a.y - p.y); if (d < bd) { bd = d; best = i; } });
    return best;
  };
  const hitBond = (p: { x: number; y: number }) => {
    let best = -1, bd = 8;
    mol.bonds.forEach((b, i) => { const d = segDist(p.x, p.y, mol.atoms[b.a].x, mol.atoms[b.a].y, mol.atoms[b.b].x, mol.atoms[b.b].y); if (d < bd) { bd = d; best = i; } });
    return best;
  };

  const down = (e: React.PointerEvent) => {
    const p = point(e);
    const ai = hitAtom(p);
    if (tool === 'move') {
      if (ai >= 0) { drag.current = ai; onSelect(ai); onDragStart(); svgRef.current!.setPointerCapture(e.pointerId); } else onSelect(null);
    } else if (tool === 'atom') {
      if (ai >= 0) {
        if (mol.atoms[ai].el !== element) onCommit({ ...mol, atoms: mol.atoms.map((a, i) => (i === ai ? { ...a, el: element } : a)) });
        onSelect(ai);
      } else {
        const x = Math.max(16, Math.min(W - 16, p.x)), y = Math.max(16, Math.min(H - 16, p.y));
        const atoms = [...mol.atoms, { el: element, x, y }];
        const idx = atoms.length - 1;
        const bonds = autoBond && selected !== null && selected < mol.atoms.length ? [...mol.bonds, { a: selected, b: idx, order: 1 }] : mol.bonds;
        onCommit({ atoms, bonds });
        onSelect(idx);
      }
    } else if (tool === 'bond') {
      if (ai < 0) { onSelect(null); return; }
      if (selected !== null && selected !== ai && selected < mol.atoms.length) { onCommit(cycleBond(mol, selected, ai)); onSelect(null); }
      else onSelect(ai);
    } else if (tool === 'erase') {
      if (ai >= 0) { onCommit(removeAtom(mol, ai)); onSelect(null); return; }
      const bi = hitBond(p);
      if (bi >= 0) onCommit({ ...mol, bonds: mol.bonds.filter((_, k) => k !== bi) });
    }
  };
  const move = (e: React.PointerEvent) => {
    if (drag.current === null) return;
    const p = point(e);
    const i = drag.current;
    onLive({ ...mol, atoms: mol.atoms.map((a, k) => (k === i ? { ...a, x: Math.max(14, Math.min(W - 14, p.x)), y: Math.max(14, Math.min(H - 14, p.y)) } : a)) });
  };
  const up = () => { drag.current = null; };

  const trim = (i: number) => (labelled(i) ? (text(i).length > 2 ? 15 : 11) : 1.5);

  return (
    <svg
      ref={svgRef}
      viewBox={`0 0 ${W} ${H}`}
      className="w-full rounded-xl bg-white"
      style={{ touchAction: 'none', cursor: tool === 'move' ? 'grab' : tool === 'erase' ? 'not-allowed' : 'crosshair', userSelect: 'none' }}
      onPointerDown={down} onPointerMove={move} onPointerUp={up} onPointerCancel={up}
      role="img" aria-label="Molecule drawing area. Use the tools above to add atoms and bonds."
    >
      <defs><pattern id="mol-grid" width="22" height="22" patternUnits="userSpaceOnUse"><circle cx="1" cy="1" r="0.8" fill="#e5e7eb" /></pattern></defs>
      <rect width={W} height={H} fill="url(#mol-grid)" />
      {mol.bonds.map((b, k) => {
        const A = mol.atoms[b.a], B = mol.atoms[b.b];
        const dx = B.x - A.x, dy = B.y - A.y, d = Math.hypot(dx, dy) || 1, ux = dx / d, uy = dy / d, nx = -uy, ny = ux;
        const ta = trim(b.a), tb = trim(b.b);
        const offs = b.order === 1 ? [0] : b.order === 2 ? [-3, 3] : [-4.5, 0, 4.5];
        return (
          <g key={k} stroke="#1f2937" strokeWidth={1.8} strokeLinecap="round">
            {offs.map((o, j) => (
              <line key={j} x1={A.x + ux * ta + nx * o} y1={A.y + uy * ta + ny * o} x2={B.x - ux * tb + nx * o} y2={B.y - uy * tb + ny * o} />
            ))}
          </g>
        );
      })}
      {mol.atoms.map((a, i) => {
        const sel = selected === i, isBad = badSet.has(i);
        const t = text(i);
        return (
          <g key={i}>
            {labelled(i) ? (
              <>
                <circle cx={a.x} cy={a.y} r={t.length > 2 ? 15 : 12} fill="#fff" stroke={isBad ? '#dc2626' : sel ? '#4f46e5' : 'none'} strokeWidth={2} />
                <text x={a.x} y={a.y} textAnchor="middle" dominantBaseline="central" fontSize={14} fontWeight={600} fill={isBad ? '#dc2626' : COLORS[a.el] ?? '#111827'}>{t}</text>
              </>
            ) : (
              <circle cx={a.x} cy={a.y} r={sel || isBad ? 7 : 2.5} fill={sel || isBad ? 'none' : '#1f2937'} stroke={isBad ? '#dc2626' : sel ? '#4f46e5' : 'none'} strokeWidth={2} />
            )}
          </g>
        );
      })}
      {mol.atoms.length === 0 && (
        <text x={W / 2} y={H / 2} textAnchor="middle" fontSize={14} fill="#9ca3af">Choose “Add atom”, tap here to place atoms, or load a molecule below.</text>
      )}
    </svg>
  );
}
FILEEOF

write_file src/app/chemistry/organic/page.tsx << 'FILEEOF'
'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { MoleculeEditor, H, type Tool } from '@/components/chemistry/MoleculeEditor';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import {
  ISOMER_SETS, LIBRARY, PALETTE, components, dbe, formulaText, functionalGroups, identify, loadPreset, massOf, parseSmiles,
  placeMol, toMolfile, toSmiles, valenceInfo, composition, type Mol,
} from '@/lib/chemistry/organic';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const TOOLS: { id: Tool; label: string; hint: string }[] = [
  { id: 'move', label: 'Move', hint: 'Drag atoms to rearrange the drawing.' },
  { id: 'atom', label: 'Add atom', hint: 'Tap empty space to place the chosen element. With “auto-bond” on, each new atom bonds to the last selected one, so you can draw chains quickly. Tap an atom with a different element chosen to change it.' },
  { id: 'bond', label: 'Bond', hint: 'Tap one atom, then another. Tap the same pair again to cycle single → double → triple → none.' },
  { id: 'erase', label: 'Erase', hint: 'Tap an atom or a bond to delete it.' },
];
const GROUPS = Array.from(new Set(LIBRARY.map(p => p.group)));

export default function OrganicPage() {
  const [width, setWidth] = useState(640);
  const [mol, setMol] = useState<Mol>(() => loadPreset('Ethanol') ?? { atoms: [], bonds: [] });
  const [undo, setUndo] = useState<Mol[]>([]);
  const [tool, setTool] = useState<Tool>('move');
  const [element, setElement] = useState('C');
  const [selected, setSelected] = useState<number | null>(null);
  const [autoBond, setAutoBond] = useState(true);
  const [skeletal, setSkeletal] = useState(false);
  const [smiles, setSmiles] = useState('');
  const [smilesError, setSmilesError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);

  const pickTool = (t: Tool) => { setTool(t); setSelected(null); };
  // Phones get a narrower drawing space so atoms and labels render at a readable size.
  useEffect(() => {
    const t = setTimeout(() => {
      if (window.innerWidth < 640) { setWidth(360); setMol(m => placeMol(m, 360, H)); }
    }, 0);
    return () => clearTimeout(t);
  }, []);
  const push = () => setUndo(u => [...u.slice(-29), mol]);
  const commit = (m: Mol) => { push(); setMol(m); setSaved(false); setCopied(false); };
  const doUndo = () => { setUndo(u => { if (!u.length) return u; setMol(u[u.length - 1]); setSelected(null); return u.slice(0, -1); }); setSaved(false); };
  const load = (m: Mol) => { push(); setMol(m); setSelected(null); setSmilesError(null); setSaved(false); setCopied(false); };
  const loadByName = (name: string) => { const m = loadPreset(name, width, H); if (m) load(m); };

  const n = mol.atoms.length;
  const { h, bad } = valenceInfo(mol);
  const totalH = h.reduce((s, x) => s + x, 0);
  const formula = n ? formulaText(mol) : '—';
  const mass = n ? massOf(mol) : 0;
  const unsat = n ? dbe(mol) : null;
  const groups = n ? functionalGroups(mol) : [];
  const id = identify(mol);
  const parts = components(mol);
  const smilesOut = n ? toSmiles(mol) : '';
  const valid = n > 0 && bad.length === 0 && parts === 1;

  const drawSmiles = () => {
    const r = parseSmiles(smiles);
    if (r.error || !r.mol) { setSmilesError(r.error ?? 'Could not read that SMILES.'); return; }
    load(placeMol(r.mol, width, H));
  };
  const onSave = () => {
    if (!n) return;
    saveCandidate({
      name: id.same ?? formula, kind: 'organic', formula, composition: composition(mol), molarMass: mass,
      chargeStatus: valid ? 'Valences satisfied' : 'Valence problem',
      organic: { atoms: mol.atoms, bonds: mol.bonds, smiles: smilesOut },
    });
    setSaved(true);
  };
  const onLoadCandidate = (c: Candidate) => { if (c.organic) load({ atoms: c.organic.atoms, bonds: c.organic.bonds }); };
  const tip = TOOLS.find(t => t.id === tool)!;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Organic molecules</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Draw atoms and bonds, or load a molecule. Hydrogens fill in automatically from valence. The tool reads the structure you drew — it tells you what the <span className="font-medium text-gray-700">graph</span> contains, not whether the molecule is stable or easy to make.</p>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.35fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <div className="mb-3 flex flex-wrap items-center gap-2">
                  <div className="flex overflow-hidden rounded-lg border border-gray-200" role="group" aria-label="Drawing tool">
                    {TOOLS.map(t => <button key={t.id} type="button" aria-pressed={tool === t.id} onClick={() => pickTool(t.id)} className={`px-3 py-1.5 text-xs font-medium ${tool === t.id ? 'bg-indigo-600 text-white' : 'bg-white text-gray-600 hover:bg-gray-50'}`}>{t.label}</button>)}
                  </div>
                  <button type="button" onClick={doUndo} disabled={!undo.length} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 enabled:hover:border-indigo-300 disabled:opacity-40">Undo</button>
                  <button type="button" onClick={() => { if (n) { push(); setMol({ atoms: [], bonds: [] }); setSelected(null); setSaved(false); } }} disabled={!n} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-600 enabled:hover:border-red-300 enabled:hover:text-red-600 disabled:opacity-40">Clear</button>
                </div>
                {/* Always rendered (hidden when unused) so the canvas never jumps when the tool changes. */}
                {(
                  <div className={`mb-3 flex flex-wrap items-center gap-1.5 ${tool === 'atom' ? '' : 'invisible'}`} role="group" aria-label="Element" aria-hidden={tool !== 'atom'}>
                    {PALETTE.map(el => <button key={el} type="button" tabIndex={tool === 'atom' ? 0 : -1} aria-pressed={element === el} onClick={() => setElement(el)} className={`h-8 min-w-8 rounded-md border px-2 text-xs font-semibold ${element === el ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-700 hover:border-indigo-300'}`}>{el}</button>)}
                    <label className="ml-2 flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={autoBond} onChange={e => setAutoBond(e.target.checked)} />Auto-bond</label>
                  </div>
                )}
                <MoleculeEditor mol={mol} tool={tool} element={element} selected={selected} autoBond={autoBond} skeletal={skeletal} width={width}
                  onLive={setMol} onCommit={commit} onSelect={setSelected} onDragStart={push} />
                <div className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1">
                  <p className="min-w-0 flex-1 text-[11px] text-gray-500">{tip.hint}</p>
                  <label className="flex items-center gap-1.5 text-xs text-gray-600"><input type="checkbox" checked={skeletal} onChange={e => setSkeletal(e.target.checked)} />Skeletal style</label>
                </div>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <h2 className="mb-2 text-sm font-semibold text-gray-900">Load a molecule</h2>
                <label className="sr-only" htmlFor="lib">Molecule library</label>
                <select id="lib" value="" onChange={e => e.target.value && loadByName(e.target.value)} className="h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  <option value="">Choose from the library ({LIBRARY.length} molecules)…</option>
                  {GROUPS.map(g => <optgroup key={g} label={g}>{LIBRARY.filter(p => p.group === g).map(p => <option key={p.name} value={p.name}>{p.name}</option>)}</optgroup>)}
                </select>
                <div className="mt-3 text-[11px] font-medium uppercase tracking-wide text-gray-400">Isomer sets — same formula, different structure</div>
                <div className="mt-1.5 space-y-1.5">
                  {ISOMER_SETS.map(s => (
                    <div key={s.formula} className="flex flex-wrap items-center gap-1.5">
                      <span className="w-14 text-xs font-medium text-gray-500">{s.formula}</span>
                      {s.names.map(nm => <button key={nm} type="button" onClick={() => loadByName(nm)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{nm.replace(/ \(.*\)/, '')}</button>)}
                    </div>
                  ))}
                </div>
                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Or type a SMILES string</div>
                <div className="mt-1.5 flex gap-2">
                  <label className="sr-only" htmlFor="smiles">SMILES</label>
                  <input id="smiles" value={smiles} onChange={e => { setSmiles(e.target.value); setSmilesError(null); }} onKeyDown={e => e.key === 'Enter' && drawSmiles()} spellCheck={false} autoCapitalize="off" placeholder="e.g. CC(=O)O or c1ccccc1" className="h-9 min-w-0 flex-1 rounded-md border border-gray-200 px-3 font-mono text-sm" />
                  <button type="button" onClick={drawSmiles} className="h-9 rounded-md bg-indigo-600 px-3 text-xs font-medium text-white hover:bg-indigo-700">Draw</button>
                </div>
                {smilesError && <p className="mt-1.5 rounded-lg bg-amber-50 px-3 py-2 text-xs text-amber-900">{smilesError}</p>}
                <p className="mt-1.5 text-[11px] text-gray-400">Supports C N O S P F Cl Br I, aromatic c n o s, branches ( ), rings, and = # bonds. Charges and stereochemistry are not modelled.</p>
              </div>
              <CandidatesPanel onLoad={onLoadCandidate} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Molecular formula</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{formula}</div>
                {n > 0 && (
                  <div className={`mt-1 text-sm ${id.same ? 'text-emerald-700' : 'text-gray-500'}`}>
                    {id.same ? `Matches ${id.same} in the library` : valid ? 'Not in the built-in library (that does not mean it doesn’t exist)' : ''}
                  </div>
                )}

                {n > 0 && (bad.length > 0 || parts > 1) && (
                  <ul className="mt-3 space-y-1 rounded-lg bg-red-50 px-3 py-2 text-xs text-red-800">
                    {bad.length > 0 && <li>{bad.length} atom{bad.length > 1 ? 's have' : ' has'} too many bonds for its valence (shown in red).</li>}
                    {parts > 1 && <li>The drawing has {parts} separate pieces; the numbers below treat them as one species.</li>}
                  </ul>
                )}

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Molar mass</dt><dd className="font-medium text-gray-900">{n ? `${mass.toFixed(3)} g/mol` : '—'}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Heavy atoms / bonds / H</dt><dd className="font-medium text-gray-900">{n} / {mol.bonds.length} / {totalH}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Degrees of unsaturation</dt><dd className="font-medium text-gray-900">{n ? (unsat ?? '—') : '—'}</dd></div>
                  <div className="flex justify-between gap-3 py-1.5"><dt className="text-gray-500">SMILES</dt><dd className="min-w-0 break-all text-right font-mono font-medium text-gray-900">{smilesOut || '—'}</dd></div>
                </dl>

                <div className="mt-3">
                  <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Functional groups found</div>
                  {groups.length ? (
                    <div className="mt-1.5 flex flex-wrap gap-1.5">{groups.map(g => <span key={g.label} className="rounded-full bg-indigo-50 px-2.5 py-1 text-[11px] font-medium text-indigo-800">{g.label}{g.count > 1 ? ` ×${g.count}` : ''}</span>)}</div>
                  ) : <p className="mt-1 text-xs text-gray-500">{n ? 'None of the recognised groups (an alkane-type framework, or an unusual arrangement).' : 'Draw or load a molecule.'}</p>}
                </div>

                {id.isomers.length > 0 && (
                  <div className="mt-4">
                    <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Library isomers of {formula}</div>
                    <div className="mt-1.5 flex flex-wrap gap-1.5">{id.isomers.map(nm => <button key={nm} type="button" onClick={() => loadByName(nm)} className="rounded-full border border-gray-200 px-2.5 py-1 text-[11px] text-gray-700 hover:border-indigo-300 hover:text-indigo-700">{nm}</button>)}</div>
                    <p className="mt-1.5 text-[11px] text-gray-400">Constitutional isomers: same atoms, connected differently. Their properties can differ a lot. Stereoisomers (cis/trans, mirror images) are not distinguished here.</p>
                  </div>
                )}

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} disabled={!n} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white enabled:hover:bg-indigo-700 disabled:opacity-40">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" disabled={!n} onClick={async () => { try { await navigator.clipboard.writeText(smilesOut); setCopied(true); } catch { /* clipboard blocked */ } }} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">{copied ? 'Copied ✓' : 'Copy SMILES'}</button>
                  <button type="button" disabled={!n} onClick={() => download(`${(id.same ?? formula).replace(/[^A-Za-z0-9]+/g, '_')}.mol`, toMolfile(mol, id.same ?? formula), 'chemical/x-mdl-molfile')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 enabled:hover:border-indigo-300 disabled:opacity-40">Download .mol</button>
                  {n > 0 && <Link href={`/chemistry/compound-builder?c=${Object.entries(composition(mol)).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>}
                </div>
              </div>

              <EvidencePanel
                candidate="You drew or loaded this structure. A valid-looking drawing does not mean the molecule is stable, isolable or easy to make."
                rule={{ label: n ? `${bad.length ? 'Valence rules violated. ' : 'Valences satisfied. '}Groups come from fixed pattern rules on the bond graph.` : 'Draw or load a molecule to run the checks.', ok: n ? valid : null }}
                database={{ state: id.same ? 'warn' : 'no', text: id.same ? `Matched to “${id.same}” in a small built-in library of ${LIBRARY.length} molecules — not a chemical database. Confirm identity in PubChem or similar.` : `Compared only against the built-in library of ${LIBRARY.length} molecules. Use PubChem, ChEBI or a similar database to look a structure up.` }}
                calculated={{ state: 'no', text: 'None. The 2D layout is only a drawing: no 3D geometry, energies, charges, pKa or spectra are calculated.' }}
              />
            </div>
          </div>
        </div>
      </main>
    </>
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
  { slug: 'crystal-builder', href: '/chemistry/crystal-builder', title: 'Crystal builder', icon: '🔷', topic: 'Materials', status: 'live',
    description: 'Pick a cubic prototype (rocksalt, CsCl, zincblende, fluorite, fcc, bcc, diamond…), assign elements and read computed coordination, density and packing.' },
  { slug: 'organic', href: '/chemistry/organic', title: 'Organic molecules', icon: '🧬', topic: 'Organic', status: 'live',
    description: 'Draw atoms and bonds or type a SMILES string; get the formula, functional groups and library isomers with the same formula.' },
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

echo ""
echo "Done. npm run dev, then open /chemistry/organic"
