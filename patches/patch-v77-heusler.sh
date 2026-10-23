#!/bin/bash
# A-Factor STEM Studio — Chemistry playground, part 2: Heusler alloys
# Run inside af2s/ (the project ROOT) AFTER patch-v76-chemistry-playground.sh:
#     bash patches/patch-v77-heusler.sh
#
# ADDS   /chemistry/heusler
#   - Half-Heusler XYZ (F-43m) with the three site arrangements (X, Y or Z on the 4c site, 4d vacant)
#   - Full-Heusler X2YZ: regular L2_1 (Fm-3m) and inverse XA (F-43m)
#   - Rotatable model on the four fcc sublattices, nearest-neighbour bonds, 1x1x1 / 2x2x2 cells
#   - Valence-electron screening (8/18/24 closed-shell counts) and a Slater-Pauling estimate
#   - Presets (TiNiSn, NiMnSb, Co2MnSi, Co2FeSi, Fe2VAl, Ni2MnGa, Mn2CoAl), saved candidates, CIF export
# UPDATES (small, backwards compatible)
#   - CrystalViewer: optional bondMode / siteNames props (perovskite lab behaves as before)
#   - candidates.ts: candidate kind 'heusler'
#   - /chemistry hub: Heusler card switched from "Coming soon" to Live
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -d src ]; then echo "ERROR: run from the project root (package.json + src/)."; exit 1; fi
if [ ! -f src/lib/chemistry/perovskite.ts ]; then echo "ERROR: apply patch-v76-chemistry-playground.sh first."; exit 1; fi

echo "Applying Heusler module (v77)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/lib/chemistry/heusler.ts << 'FILEEOF'
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
  kind: 'composition' | 'perovskite' | 'heusler';
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

write_file src/components/chemistry/CrystalViewer.tsx << 'FILEEOF'
'use client';
import { useEffect, useMemo, useRef, useState } from 'react';
import type { Site } from '@/lib/chemistry/perovskite';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

export interface ViewerAtom { site: Site; pos: [number, number, number] }

export interface SiteStyle { label: string; color: string; radius: number /* in cell units */ }

interface Props {
  atoms: ViewerAtom[];
  /** Edge length of the drawn block, in the same units as `pos` (the supercell count). */
  extent: number;
  styles: Partial<Record<Site, SiteStyle>>;
  /** B–X distance in `pos` units; bonds are drawn between B/B2 and X atoms at this distance. */
  bondDist: number;
  /** 'bx' (default): bonds between B/B′ and X. 'nn': bonds between any two atoms at `bondDist`. */
  bondMode?: 'bx' | 'nn';
  /** Optional legend names per site key (defaults to the perovskite A/B/B′/X naming). */
  siteNames?: Partial<Record<Site, string>>;
  showBonds: boolean;
  showCell: boolean;
  showA: boolean;
}

type V3 = [number, number, number];
const VIEWS: Record<string, { yaw: number; pitch: number }> = {
  Isometric: { yaw: 0.6, pitch: 0.5 },
  Front: { yaw: 0, pitch: 0 },
  Top: { yaw: 0, pitch: Math.PI / 2 - 0.001 },
};

export function CrystalViewer({ atoms, extent, styles, bondDist, bondMode = 'bx', siteNames, showBonds, showCell, showA }: Props) {
  const boxRef = useRef<HTMLDivElement>(null);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const { width, height } = useResponsiveCanvasSize(boxRef, 640, 440, 900);
  const rot = useRef({ yaw: 0.6, pitch: 0.5 });
  const drag = useRef<{ x: number; y: number } | null>(null);
  const [zoom, setZoom] = useState(1);
  const [auto, setAuto] = useState(false);
  const [tick, setTick] = useState(0); // forces a redraw after pointer moves

  const bonds = useMemo(() => {
    const out: [number, number][] = [];
    const eps = 1e-3;
    const dist = (u: V3, v: V3) => Math.hypot(u[0] - v[0], u[1] - v[1], u[2] - v[2]);
    if (bondMode === 'nn') {
      for (let i = 0; i < atoms.length; i++) for (let j = i + 1; j < atoms.length; j++) {
        if (Math.abs(dist(atoms[i].pos, atoms[j].pos) - bondDist) < eps) out.push([i, j]);
      }
      return out;
    }
    atoms.forEach((b, i) => {
      if (b.site !== 'B' && b.site !== 'B2') return;
      atoms.forEach((x, j) => {
        if (x.site !== 'X') return;
        if (Math.abs(dist(b.pos, x.pos) - bondDist) < eps) out.push([i, j]);
      });
    });
    return out;
  }, [atoms, bondDist, bondMode]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    let raf = 0;
    let last = performance.now();

    const draw = (now: number) => {
      const dt = (now - last) / 1000;
      last = now;
      if (auto && !drag.current) rot.current.yaw += dt * 0.5;

      const dpr = window.devicePixelRatio || 1;
      canvas.width = width * dpr; canvas.height = height * dpr;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(0, 0, width, height);

      const { yaw, pitch } = rot.current;
      const cy = Math.cos(yaw), sy = Math.sin(yaw), cp = Math.cos(pitch), sp = Math.sin(pitch);
      const c = extent / 2;
      const scale = (Math.min(width, height) / (extent * 1.9)) * zoom;
      const project = (p: V3) => {
        const x = p[0] - c, y = p[1] - c, z = p[2] - c;
        const x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
        const y2 = y * cp - z1 * sp, z2 = y * sp + z1 * cp;
        const persp = 1 / (1 - z2 * 0.08 / extent);
        return { sx: width / 2 + x1 * scale * persp, sy: height / 2 - y2 * scale * persp, depth: z2, persp };
      };

      if (showCell) {
        ctx.strokeStyle = 'rgba(148,163,184,0.55)'; ctx.lineWidth = 1;
        const e = extent;
        const corners: V3[] = [[0, 0, 0], [e, 0, 0], [e, e, 0], [0, e, 0], [0, 0, e], [e, 0, e], [e, e, e], [0, e, e]];
        const edges = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]];
        ctx.beginPath();
        for (const [a, b] of edges) {
          const pa = project(corners[a]), pb = project(corners[b]);
          ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy);
        }
        ctx.stroke();
      }

      if (showBonds) {
        ctx.strokeStyle = 'rgba(165,180,252,0.45)'; ctx.lineWidth = 1.2;
        ctx.beginPath();
        for (const [i, j] of bonds) {
          const pa = project(atoms[i].pos), pb = project(atoms[j].pos);
          ctx.moveTo(pa.sx, pa.sy); ctx.lineTo(pb.sx, pb.sy);
        }
        ctx.stroke();
      }

      const drawn = atoms
        .filter(a => showA || a.site !== 'A')
        .map(a => ({ a, p: project(a.pos) }))
        .sort((u, v) => u.p.depth - v.p.depth);

      for (const { a, p } of drawn) {
        const st = styles[a.site];
        if (!st) continue;
        const r = Math.max(3, st.radius * scale * p.persp * 0.55);
        const grad = ctx.createRadialGradient(p.sx - r * 0.3, p.sy - r * 0.3, r * 0.1, p.sx, p.sy, r);
        grad.addColorStop(0, '#ffffff55'); grad.addColorStop(0.25, st.color); grad.addColorStop(1, st.color);
        ctx.fillStyle = grad;
        ctx.beginPath(); ctx.arc(p.sx, p.sy, r, 0, Math.PI * 2); ctx.fill();
        if (r > 9) {
          ctx.fillStyle = '#0f172a'; ctx.font = `600 ${Math.min(14, r * 0.85)}px system-ui, sans-serif`;
          ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
          ctx.fillText(st.label, p.sx, p.sy + 0.5);
        }
      }

      if (auto) raf = requestAnimationFrame(draw);
    };

    raf = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(raf);
  }, [atoms, extent, styles, bonds, showBonds, showCell, showA, width, height, zoom, auto, tick]);

  const onDown = (e: React.PointerEvent) => { drag.current = { x: e.clientX, y: e.clientY }; (e.target as Element).setPointerCapture(e.pointerId); };
  const onMove = (e: React.PointerEvent) => {
    if (!drag.current) return;
    const dx = e.clientX - drag.current.x, dy = e.clientY - drag.current.y;
    drag.current = { x: e.clientX, y: e.clientY };
    rot.current.yaw += dx * 0.01;
    rot.current.pitch = Math.max(-Math.PI / 2 + 0.001, Math.min(Math.PI / 2 - 0.001, rot.current.pitch + dy * 0.01));
    setTick(t => t + 1);
  };
  const onUp = () => { drag.current = null; };
  const setView = (name: string) => { rot.current = { ...VIEWS[name] }; setTick(t => t + 1); };

  const legend = (['A', 'B', 'B2', 'X'] as Site[]).filter(s => styles[s]);

  return (
    <div>
      <div ref={boxRef} className="overflow-hidden rounded-xl">
        <canvas
          ref={canvasRef}
          width={width} height={height}
          style={{ width, height, touchAction: 'pan-y', cursor: 'grab' }}
          onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}
          role="img" aria-label="Rotatable 3D view of the proposed crystal model. Drag to rotate."
        />
      </div>
      <div className="mt-2 flex flex-wrap items-center gap-2">
        {Object.keys(VIEWS).map(v => (
          <button key={v} type="button" onClick={() => setView(v)} className="rounded-md border border-gray-200 bg-white px-2.5 py-1 text-[11px] text-gray-600 hover:border-indigo-300 hover:text-indigo-700">{v}</button>
        ))}
        <button type="button" onClick={() => setAuto(a => !a)} className={`rounded-md border px-2.5 py-1 text-[11px] ${auto ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300'}`}>{auto ? 'Stop spin' : 'Spin'}</button>
        <label className="ml-auto flex items-center gap-2 text-[11px] text-gray-500">
          Zoom
          <input type="range" min={0.6} max={2} step={0.05} value={zoom} onChange={e => setZoom(Number(e.target.value))} className="w-24" />
        </label>
      </div>
      <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1">
        {legend.map(s => (
          <span key={s} className="flex items-center gap-1.5 text-[11px] text-gray-600">
            <span className="inline-block h-3 w-3 rounded-full" style={{ background: styles[s]!.color }} />
            {siteNames?.[s] ?? `${s === 'B2' ? 'B′' : s}-site`}: {styles[s]!.label}
          </span>
        ))}
        <span className="text-[11px] text-gray-400">Drag to rotate · sizes ∝ Shannon radii</span>
      </div>
    </div>
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
  { slug: 'nuclear', href: '#', title: 'Nuclear playground', icon: '☢️', topic: 'Nuclear', status: 'coming',
    description: 'Choose isotopes and explore decay modes, half-life and conservation in nuclear equations.' },
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

write_file src/app/chemistry/heusler/page.tsx << 'FILEEOF'
'use client';
import { useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass } from '@/lib/chemistry/compound';
import { withBoundaryImages, type Site } from '@/lib/chemistry/perovskite';
import {
  TEMPLATES, SUB_SITE, SUB_NAME, NN_DIST, analyseHeusler, heuslerAtoms, heuslerCif, heuslerDensity, roleCount,
  type Role, type Sub, type TemplateId,
} from '@/lib/chemistry/heusler';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

const ROLE_COLOR: Record<Role, string> = { X: '#f59e0b', Y: '#818cf8', Z: '#2dd4bf' };
type Els = Record<Role, string>;

interface Preset { label: string; template: TemplateId; el: Els; a: number; note: string }
const PRESETS: Preset[] = [
  { label: 'TiNiSn', template: 'half-Y4c', el: { X: 'Ti', Y: 'Ni', Z: 'Sn' }, a: 5.94,
    note: 'Half-Heusler with 18 valence electrons — the standard example of a closed-shell, semiconducting count (thermoelectric studies).' },
  { label: 'NiMnSb', template: 'half-X4c', el: { X: 'Ni', Y: 'Mn', Z: 'Sb' }, a: 5.92,
    note: 'The classic half-metallic half-Heusler. N_v = 22 gives the Slater–Pauling moment of 4 μB, which matches what is reported.' },
  { label: 'Co₂MnSi', template: 'full-L21', el: { X: 'Co', Y: 'Mn', Z: 'Si' }, a: 5.65,
    note: 'Regular L2₁ full-Heusler studied for half-metallicity; N_v = 29 gives the reported 5 μB.' },
  { label: 'Co₂FeSi', template: 'full-L21', el: { X: 'Co', Y: 'Fe', Z: 'Si' }, a: 5.64,
    note: 'Regular L2₁ full-Heusler with N_v = 30, i.e. a Slater–Pauling moment of 6 μB.' },
  { label: 'Fe₂VAl', template: 'full-L21', el: { X: 'Fe', Y: 'V', Z: 'Al' }, a: 5.76,
    note: 'N_v = 24: the closed-shell count of a non-magnetic full-Heusler (semimetal/narrow-gap candidate).' },
  { label: 'Ni₂MnGa', template: 'full-L21', el: { X: 'Ni', Y: 'Mn', Z: 'Ga' }, a: 5.83,
    note: 'Magnetic shape-memory alloy; the cubic L2₁ phase here is the high-temperature austenite, and the real material transforms martensitically.' },
  { label: 'Mn₂CoAl', template: 'full-inverse', el: { X: 'Mn', Y: 'Co', Z: 'Al' }, a: 5.80,
    note: 'Inverse (XA) full-Heusler discussed as a spin-gapless / ferrimagnetic candidate; N_v = 26 gives 2 μB.' },
];

function ElementSelect({ role, value, onChange }: { role: Role; value: string; onChange: (s: string) => void }) {
  const e = BY_SYMBOL[value];
  return (
    <div className="rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500">
        <span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: ROLE_COLOR[role] }} />{role} element
      </div>
      <select value={value} onChange={ev => onChange(ev.target.value)} className="mt-2 h-8 w-full rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${role} element`}>
        {ELEMENTS.filter(x => x.z <= 103).map(x => <option key={x.symbol} value={x.symbol}>{x.symbol} — {x.name}</option>)}
      </select>
      <div className="mt-1.5 text-[11px] text-gray-400">Valence electrons counted: {e.group == null ? '3 (f-block, approx.)' : e.group <= 12 ? e.group : e.group - 10}</div>
    </div>
  );
}

export default function HeuslerPage() {
  const [tid, setTid] = useState<TemplateId>('half-X4c');
  const [el, setEl] = useState<Els>(PRESETS[0].el);
  const [a, setA] = useState(PRESETS[0].a);
  const [note, setNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [saved, setSaved] = useState(false);

  const t = TEMPLATES[tid];
  const report = useMemo(() => analyseHeusler(t, el), [t, el]);
  const atoms = useMemo(() => withBoundaryImages(heuslerAtoms(t), n), [t, n]);
  const mass = molarMass(report.composition);
  const dens = heuslerDensity(t, a, el);

  const styles = useMemo(() => {
    const out: Partial<Record<Site, SiteStyle>> = {};
    (Object.keys(t.layout) as Sub[]).forEach(sub => {
      const role = t.layout[sub];
      if (!role) return;
      out[SUB_SITE[sub]] = { label: el[role], color: ROLE_COLOR[role], radius: 0.075 + 0.012 * BY_SYMBOL[el[role]].period };
    });
    return out;
  }, [t, el]);
  const siteNames = useMemo(() => Object.fromEntries((Object.keys(SUB_NAME) as Sub[]).map(s => [SUB_SITE[s], SUB_NAME[s]])) as Partial<Record<Site, string>>, []);

  const roles: Role[] = ['X', 'Y', 'Z'];
  const loadPreset = (p: Preset) => { setTid(p.template); setEl(p.el); setA(p.a); setNote(p.note); setSaved(false); };
  const setRole = (r: Role, s: string) => { setEl(e => ({ ...e, [r]: s })); setNote(null); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: `${report.formula} (${t.family === 'half' ? 'half' : 'full'}, ${t.id.split('-')[1]})`,
      kind: 'heusler', formula: report.formula, composition: report.composition, molarMass: mass,
      chargeStatus: `N_v = ${report.nv}`,
      heusler: { template: t.id, elements: el, a, valenceElectrons: report.nv, slaterPauling: report.moment },
      note: note ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.heusler) {
      setTid(c.heusler.template as TemplateId);
      setEl(c.heusler.elements as Els);
      setA(c.heusler.a);
      setNote(c.note ?? null);
    }
  };

  const tone = { good: 'bg-emerald-50 text-emerald-900', info: 'bg-gray-50 text-gray-700', warn: 'bg-amber-50 text-amber-900' } as const;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Heusler alloys</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Place X, Y and Z on the four fcc sublattices, compare site arrangements, and check valence-electron rules. The model is a <span className="font-medium text-gray-700">proposed ordering</span>, not a relaxed or confirmed structure.</p>

          <div className="mb-4 flex flex-wrap gap-2">
            {PRESETS.map(p => (
              <button key={p.label} type="button" onClick={() => loadPreset(p)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>
            ))}
          </div>
          {note && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{note} <span className="opacity-70">Reference notes and lattice parameters are approximate summaries — check the primary literature before citing.</span></p>}

          <div className="grid gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} siteNames={siteNames} bondDist={NN_DIST} bondMode="nn" showBonds={bonds} showCell={cell} showA />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />Nearest-neighbour bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{t.label} · {t.spaceGroup}. {t.note} Atom sizes show period only, not ionic or atomic radii.{t.family === 'half' && ' The 4d site is vacant.'}</p>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <label className="text-[11px] font-medium uppercase tracking-wide text-gray-400" htmlFor="template">Template / arrangement</label>
                <select id="template" value={tid} onChange={e => { setTid(e.target.value as TemplateId); setSaved(false); }} className="mt-1 h-9 w-full rounded-md border border-gray-200 bg-white px-2 text-sm">
                  <optgroup label="Half-Heusler XYZ (three arrangements)">
                    {(['half-X4c', 'half-Y4c', 'half-Z4c'] as TemplateId[]).map(id => <option key={id} value={id}>{TEMPLATES[id].label}</option>)}
                  </optgroup>
                  <optgroup label="Full-Heusler X₂YZ">
                    {(['full-L21', 'full-inverse'] as TemplateId[]).map(id => <option key={id} value={id}>{TEMPLATES[id].label}</option>)}
                  </optgroup>
                </select>
                <p className="mt-1 text-[11px] text-gray-400">Labels (e.g. “Type I/II/III”) vary between papers, so arrangements are named here by site.</p>

                <div className="mt-3 grid gap-3 sm:grid-cols-3">
                  {roles.filter(r => roleCount(t, r) > 0).map(r => <ElementSelect key={r} role={r} value={el[r]} onChange={s => setRole(r, s)} />)}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{report.display}</div>
                <div className="text-xs text-gray-500">{mass.toFixed(2)} g/mol per formula unit</div>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Valence electrons N_v</dt><dd className="font-medium text-gray-900">{report.nv}{report.approx && ' (approx.)'}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Slater–Pauling M = N_v − {t.family === 'half' ? 18 : 24}</dt><dd className="font-medium text-gray-900">{report.moment == null ? '0 (closed shell)' : `${report.moment > 0 ? '+' : ''}${report.moment} μB / f.u.`}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Nearest-neighbour distance</dt><dd className="font-medium text-gray-900">{(a * NN_DIST).toFixed(3)} Å</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Density at this a</dt><dd className="font-medium text-gray-900">{dens.toFixed(2)} g/cm³</dd></div>
                </dl>

                <div className="mt-3 space-y-1.5">
                  {report.checks.map(c => (
                    <div key={c.label} className={`rounded-lg px-3 py-2 text-[11px] leading-relaxed ${tone[c.tone]}`}><span className="font-medium">{c.label}.</span> {c.text}</div>
                  ))}
                </div>

                <div className="mt-4 border-t border-gray-100 pt-3">
                  <label className="text-[11px] font-medium text-gray-500" htmlFor="a">Lattice parameter a (Å)</label>
                  <div className="mt-1 flex items-center gap-2">
                    <input id="a" type="number" step={0.01} min={3} max={9} value={a} onChange={e => { setA(Number(e.target.value) || 5.8); setSaved(false); }} className="h-8 w-24 rounded-md border border-gray-200 px-2 text-sm" />
                    <span className="text-[11px] text-gray-400">Preset values are approximate literature numbers; for new compositions this is a placeholder you should replace, not a prediction.</span>
                  </div>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${report.formula}-${t.id}-proposed.cif`, heuslerCif({ title: report.formula, a, t, el }), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(report.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: `N_v = ${report.nv} against the ${t.family === 'half' ? '8/18' : '24'}-electron closed-shell counts, plus a Slater–Pauling estimate. Counting rules only.`, ok: report.nv === (t.family === 'half' ? 18 : 24) || (t.family === 'half' && report.nv === 8) ? true : null }}
                extra={`${t.label}`}
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
echo "Done. npm run dev, then open /chemistry/heusler"
