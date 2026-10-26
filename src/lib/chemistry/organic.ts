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
