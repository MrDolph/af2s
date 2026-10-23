#!/bin/bash
# A-Factor STEM Studio — Chemistry playground: mobile fixes (v79)
# Run inside af2s/ (the project ROOT) AFTER patch-v76, v77 and v78:
#     bash patches/patch-v79-chemistry-mobile.sh
#
# PROBLEM  The periodic table was a fixed 640px-wide grid inside single-column page grids, so on
#          phones the whole page stretched and scrolled sideways.
# FIXES
#   - PeriodicTable: phones (< md) get a search box, category chips and a grid of large tap targets;
#     md and up keep the 18-column table, now sized to fit the container (no horizontal scrolling)
#   - Periodic table page: element details open as a bottom sheet on phones (beside the table on desktop)
#   - Compound builder: sticky bottom bar on phones (formula, molar mass, "Review" button)
#   - All chemistry pages: grid-cols-1 + min-w-0 so wide children can never stretch the page
#   - Perovskite lab: smaller atoms so large anions no longer hide the B-site cation; plain +1/-2 charge labels
#   - Heusler: page now opens on the template that matches its TiNiSn preset (Ni on 4c); larger labelled atoms;
#     legend note says atom size shows period only
#   - Nuclear: numbers print with proper superscripts (4.468 x 10^9 shown as 4.468 × 10⁹)
# Overwritten files get a one-time .bak copy. No new npm packages.

set -e
if [ ! -f package.json ] || [ ! -d src ]; then echo "ERROR: run from the project root (package.json + src/)."; exit 1; fi
if [ ! -f src/lib/chemistry/nuclear.ts ]; then echo "ERROR: apply patch-v76, v77 and v78 first."; exit 1; fi

echo "Applying Chemistry mobile fixes (v79)..."
write_file() {
  mkdir -p "$(dirname "$1")"; tmp="$(mktemp)"; cat > "$tmp"
  if [ -f "$1" ]; then
    if cmp -s "$1" "$tmp"; then echo "  unchanged $1"; rm -f "$tmp"; return; fi
    [ -f "$1.bak" ] || cp "$1" "$1.bak"
  fi
  mv "$tmp" "$1"; echo "  wrote $1"
}

write_file src/components/chemistry/PeriodicTable.tsx << 'FILEEOF'
'use client';
import { useMemo, useState } from 'react';
import { ELEMENTS, CATEGORY_STYLE, CATEGORY_LABEL, type Element, type Category } from '@/lib/chemistry/elements';

interface Props {
  onPick: (el: Element) => void;
  /** Symbol shown with a ring (the element being inspected). */
  selected?: string | null;
  /** Atom counts to show as small badges (compound builder). */
  counts?: Record<string, number>;
  /** Hide element names in the wide table cells. */
  compact?: boolean;
  showLegend?: boolean;
  /** Max height of the phone list before it scrolls internally. */
  listMaxHeight?: string;
}

const CATS: Category[] = ['alkali', 'alkaline', 'transition', 'post-transition', 'metalloid', 'nonmetal', 'halogen', 'noble', 'lanthanide', 'actinide'];

/**
 * Two layouts of the same data:
 *  • ≥ md: the familiar 18-column table, sized to fit the container (no horizontal scrolling).
 *  • < md: a searchable, filterable grid of large tap targets, because 18 columns cannot be
 *    tapped reliably on a phone.
 */
export function PeriodicTable({ onPick, selected, counts, compact, showLegend = true, listMaxHeight = '60vh' }: Props) {
  const [query, setQuery] = useState('');
  const [cat, setCat] = useState<Category | 'all'>('all');

  const filtered = useMemo(() => {
    const q = query.trim().toLowerCase();
    return ELEMENTS.filter(e => {
      if (cat !== 'all' && e.category !== cat) return false;
      if (!q) return true;
      return e.symbol.toLowerCase() === q || e.name.toLowerCase().includes(q) || String(e.z) === q || e.symbol.toLowerCase().startsWith(q);
    });
  }, [query, cat]);

  const cell = (e: Element) => {
    const col = e.group ?? (e.z >= 57 && e.z <= 71 ? e.z - 57 + 3 : e.z - 89 + 3);
    const row = e.group ? e.period : e.period === 6 ? 9 : 10;
    const count = counts?.[e.symbol];
    return (
      <button
        key={e.z}
        type="button"
        onClick={() => onPick(e)}
        aria-label={`${e.name}, atomic number ${e.z}`}
        aria-pressed={selected === e.symbol}
        style={{ gridColumn: col, gridRow: row }}
        className={`relative aspect-square min-w-0 rounded-md border text-center leading-none transition ${CATEGORY_STYLE[e.category]} ${selected === e.symbol ? 'ring-2 ring-indigo-600 ring-offset-1' : ''} ${count ? 'outline outline-2 outline-indigo-500' : ''}`}
      >
        <span className="absolute left-0.5 top-0.5 text-[8px] opacity-60">{e.z}</span>
        {count ? <span className="absolute right-0.5 top-0.5 rounded-full bg-indigo-600 px-1 text-[8px] font-semibold text-white">{count}</span> : null}
        <span className="block pt-2.5 text-xs font-semibold lg:text-sm">{e.symbol}</span>
        {!compact && <span className="mt-0.5 hidden truncate px-0.5 text-[7px] opacity-70 xl:block">{e.name}</span>}
      </button>
    );
  };

  const tile = (e: Element) => {
    const count = counts?.[e.symbol];
    return (
      <button
        key={e.z}
        type="button"
        onClick={() => onPick(e)}
        aria-label={`${e.name}, atomic number ${e.z}`}
        aria-pressed={selected === e.symbol}
        className={`relative flex min-h-[68px] min-w-0 flex-col items-center justify-center rounded-xl border px-1 py-1.5 text-center leading-none transition active:scale-95 ${CATEGORY_STYLE[e.category]} ${selected === e.symbol ? 'ring-2 ring-indigo-600 ring-offset-1' : ''} ${count ? 'outline outline-2 outline-indigo-500' : ''}`}
      >
        <span className="absolute left-1.5 top-1 text-[9px] opacity-60">{e.z}</span>
        {count ? <span className="absolute right-1 top-1 rounded-full bg-indigo-600 px-1.5 py-0.5 text-[9px] font-semibold text-white">×{count}</span> : null}
        <span className="mt-1 text-lg font-semibold">{e.symbol}</span>
        <span className="mt-1 w-full truncate text-[9px] opacity-75">{e.name}</span>
      </button>
    );
  };

  return (
    <div className="min-w-0">
      {/* ── Phone / small tablet: search + category chips + tap grid ── */}
      <div className="md:hidden">
        <label className="sr-only" htmlFor="pt-search">Search elements</label>
        <input
          id="pt-search"
          type="search"
          inputMode="search"
          value={query}
          onChange={e => setQuery(e.target.value)}
          placeholder="Search by name, symbol or number"
          className="h-11 w-full rounded-xl border border-gray-200 bg-white px-3 text-base text-gray-900 placeholder:text-gray-400"
        />
        <div className="scrollbar-hide -mx-1 mt-2 flex gap-1.5 overflow-x-auto px-1 pb-1" role="group" aria-label="Filter by category">
          {(['all', ...CATS] as const).map(c => (
            <button
              key={c}
              type="button"
              onClick={() => setCat(c)}
              aria-pressed={cat === c}
              className={`shrink-0 whitespace-nowrap rounded-full border px-3 py-1.5 text-xs font-medium ${cat === c ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 bg-white text-gray-600'}`}
            >
              {c === 'all' ? 'All' : CATEGORY_LABEL[c]}
            </button>
          ))}
        </div>
        <div className="mt-1 text-[11px] text-gray-400" aria-live="polite">{filtered.length} element{filtered.length === 1 ? '' : 's'}</div>
        <div className="mt-2 overflow-y-auto overscroll-contain rounded-xl" style={{ maxHeight: listMaxHeight }}>
          {filtered.length ? (
            <div className="grid grid-cols-4 gap-1.5 pb-1 min-[420px]:grid-cols-5 sm:grid-cols-6">{filtered.map(tile)}</div>
          ) : (
            <p className="rounded-xl bg-gray-50 px-3 py-6 text-center text-sm text-gray-500">No element matches “{query}”.</p>
          )}
        </div>
      </div>

      {/* ── md and up: the classic 18-column table, fitted to the width ── */}
      <div className="hidden md:block">
        <div className="grid w-full gap-[3px]" style={{ gridTemplateColumns: 'repeat(18, minmax(0, 1fr))' }}>
          {ELEMENTS.map(cell)}
          <div style={{ gridColumn: 3, gridRow: 6 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">57–71</div>
          <div style={{ gridColumn: 3, gridRow: 7 }} className="flex items-center justify-center text-[9px] text-gray-400" aria-hidden="true">89–103</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 9 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Lanthanides</div>
          <div style={{ gridColumn: '1 / span 2', gridRow: 10 }} className="flex items-center justify-end pr-1 text-[9px] text-gray-400" aria-hidden="true">Actinides</div>
          <div style={{ gridColumn: '1 / span 18', gridRow: 8, height: 6 }} aria-hidden="true" />
        </div>
        {showLegend && (
          <div className="mt-3 flex flex-wrap gap-x-3 gap-y-1">
            {CATS.map(c => (
              <span key={c} className="flex items-center gap-1 text-[10px] text-gray-500">
                <span className={`inline-block h-2.5 w-2.5 rounded-sm border ${CATEGORY_STYLE[c].split(' ').slice(0, 3).join(' ')}`} />
                {CATEGORY_LABEL[c]}
              </span>
            ))}
          </div>
        )}
      </div>
    </div>
  );
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
  /** Multiplier on drawn atom radius (default 0.55). Lower it when large anions hide small cations. */
  sizeScale?: number;
  /** Short note under the legend explaining what atom size means. */
  sizeNote?: string;
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

export function CrystalViewer({ atoms, extent, styles, bondDist, bondMode = 'bx', siteNames, sizeScale = 0.55, sizeNote = 'sizes ∝ Shannon radii', showBonds, showCell, showA }: Props) {
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
        const r = Math.max(3, st.radius * scale * p.persp * sizeScale);
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
  }, [atoms, extent, styles, bonds, showBonds, showCell, showA, width, height, zoom, auto, tick, sizeScale]);

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
        <span className="text-[11px] text-gray-400">Drag to rotate · {sizeNote}</span>
      </div>
    </div>
  );
}
FILEEOF

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

const SUP_CH: Record<string, string> = { '0': '⁰', '1': '¹', '2': '²', '3': '³', '4': '⁴', '5': '⁵', '6': '⁶', '7': '⁷', '8': '⁸', '9': '⁹', '-': '⁻' };

export function fmtNum(x: number, digits = 4): string {
  if (!Number.isFinite(x)) return '—';
  if (x === 0) return '0';
  const ax = Math.abs(x);
  if (ax >= 0.01 && ax < 1e5) return String(Number(x.toPrecision(digits)));
  const [mant, exp] = x.toExponential(digits - 1).split('e');
  return `${mant} × 10${String(parseInt(exp, 10)).split('').map(c => SUP_CH[c] ?? c).join('')}`;
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

write_file src/app/chemistry/periodic-table/page.tsx << 'FILEEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PeriodicTable } from '@/components/chemistry/PeriodicTable';
import { ElementDetails } from '@/components/chemistry/ElementDetails';
import { BY_SYMBOL, type Element } from '@/lib/chemistry/elements';

export default function PeriodicTablePage() {
  const [sel, setSel] = useState<Element>(BY_SYMBOL['Na']);
  const [sheet, setSheet] = useState(false);
  const pick = (e: Element) => { setSel(e); setSheet(true); };
  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Periodic table</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Select an element to see its configuration and oxidation states.</p>
          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1fr)_320px]">
            <div className="min-w-0 rounded-2xl border border-gray-200 bg-white p-3 sm:p-4"><PeriodicTable onPick={pick} selected={sel.symbol} listMaxHeight="calc(100vh - 21rem)" /></div>
            {/* Large screens: details beside the table */}
            <div className="hidden min-w-0 lg:block"><ElementDetails el={sel} /></div>
          </div>
        </div>

        {/* Small screens: details slide up as a sheet so they are never off-screen */}
        {sheet && (
          <div className="fixed inset-0 z-40 lg:hidden" role="dialog" aria-modal="true" aria-label={`${sel.name} details`}>
            <button type="button" className="absolute inset-0 bg-black/30" onClick={() => setSheet(false)} aria-label="Close details" />
            <div className="absolute inset-x-0 bottom-0 max-h-[78vh] overflow-y-auto rounded-t-3xl bg-white p-3 pb-6 shadow-2xl" style={{ paddingBottom: 'max(1.5rem, env(safe-area-inset-bottom))' }}>
              <div className="mx-auto mb-2 h-1 w-10 rounded-full bg-gray-300" />
              <ElementDetails el={sel} />
              <button type="button" onClick={() => setSheet(false)} className="mt-3 h-11 w-full rounded-xl border border-gray-200 text-sm font-medium text-gray-700">Close</button>
            </div>
          </div>
        )}
      </main>
    </>
  );
}
FILEEOF

write_file src/app/chemistry/compound-builder/page.tsx << 'FILEEOF'
'use client';
import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { PeriodicTable } from '@/components/chemistry/PeriodicTable';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { BY_SYMBOL, type Element } from '@/lib/chemistry/elements';
import {
  chargeBalance, cleanComposition, formulaOf, formulaPlain, massFractions, molarMass, orderedSymbols, reduce, type Composition,
} from '@/lib/chemistry/compound';
import { fmtCharge } from '@/lib/chemistry/perovskite';
import { saveCandidate, type Candidate } from '@/lib/chemistry/candidates';

const PRESETS: { label: string; c: Composition }[] = [
  { label: 'NaMgBr₃', c: { Na: 1, Mg: 1, Br: 3 } },
  { label: 'NaCl', c: { Na: 1, Cl: 1 } },
  { label: 'H₂O', c: { H: 2, O: 1 } },
  { label: 'Fe₂O₃', c: { Fe: 2, O: 3 } },
  { label: 'CsPbBr₃', c: { Cs: 1, Pb: 1, Br: 3 } },
  { label: 'C₆H₁₂O₆', c: { C: 6, H: 12, O: 6 } },
];

function parseComp(s: string): Composition {
  const out: Composition = {};
  for (const part of s.split(',')) {
    const [sym, n] = part.split(':');
    if (BY_SYMBOL[sym]) out[sym] = Math.max(1, Math.min(999, parseInt(n ?? '1', 10) || 1));
  }
  return out;
}

export default function CompoundBuilderPage() {
  const [comp, setComp] = useState<Composition>({});
  const [last, setLast] = useState<Element | null>(null);
  const [saved, setSaved] = useState(false);
  const [copied, setCopied] = useState(false);

  // Accept ?add=Na (from the periodic table) or ?c=Na:1,Mg:1,Br:3.
  useEffect(() => {
    // Deferred one tick: the URL is an external system read after hydration.
    const t = setTimeout(() => {
      const q = new URLSearchParams(window.location.search);
      const c = q.get('c'), add = q.get('add');
      if (c) setComp(parseComp(c));
      else if (add && BY_SYMBOL[add]) setComp({ [add]: 1 });
    }, 0);
    return () => clearTimeout(t);
  }, []);

  const clean = useMemo(() => cleanComposition(comp), [comp]);
  const syms = orderedSymbols(clean);
  const mass = molarMass(clean);
  const reduced = reduce(clean);
  const balance = useMemo(() => chargeBalance(clean), [clean]);
  const fractions = massFractions(clean);
  const empirical = formulaOf(reduced);
  const touch = () => { setSaved(false); setCopied(false); };

  const add = (el: Element) => { setLast(el); touch(); setComp(c => ({ ...c, [el.symbol]: Math.min(999, (c[el.symbol] ?? 0) + 1) })); };
  const setCount = (s: string, n: number) => { touch(); setComp(c => { const next = { ...c }; if (n <= 0 || !Number.isFinite(n)) delete next[s]; else next[s] = Math.min(999, Math.round(n)); return next; }); };

  const perovskiteLink = useMemo(() => {
    if (syms.length !== 3) return null;
    const byEn = [...syms].sort((a, b) => (BY_SYMBOL[a].en ?? 9) - (BY_SYMBOL[b].en ?? 9));
    return `/chemistry/perovskite-lab?A=${byEn[0]}&B=${byEn[1]}&X=${byEn[2]}`;
  }, [syms]);

  const chargeLabel = balance.status === 'balanced' ? 'Balanced (rule of thumb)' : balance.status === 'unbalanced' ? 'No balance found' : balance.message;

  const onSave = () => {
    if (!syms.length) return;
    saveCandidate({ name: formulaPlain(clean), kind: 'composition', formula: formulaPlain(clean), composition: clean, molarMass: mass, chargeStatus: chargeLabel });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => { setComp(c.composition); touch(); };

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50 pb-24 lg:pb-0">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Compound builder</h1>
          <p className="mb-5 mt-1 text-sm text-gray-500">Click elements to add atoms. The result is a <span className="font-medium text-gray-700">candidate composition</span>, not a claim that it exists.</p>

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.5fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <PeriodicTable onPick={add} counts={clean} compact showLegend={false} />
                {last && <p className="mt-2 text-[11px] text-gray-400">Added {last.name} ({last.symbol}).</p>}
              </div>
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Presets</div>
                <div className="mt-2 flex flex-wrap gap-2">
                  {PRESETS.map(p => (
                    <button key={p.label} type="button" onClick={() => { touch(); setComp(p.c); }} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{p.label}</button>
                  ))}
                </div>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="min-w-0 space-y-5">
              <div id="composition-result" className="scroll-mt-20 rounded-2xl border border-gray-200 bg-white p-5">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-[11px] font-medium uppercase tracking-wide text-gray-400">Formula</div>
                    <div className="mt-0.5 min-h-[2.5rem] text-3xl font-semibold text-gray-900" aria-live="polite">{syms.length ? formulaOf(clean) : '—'}</div>
                  </div>
                  {syms.length > 0 && <button type="button" onClick={() => { touch(); setComp({}); }} className="text-xs text-gray-400 hover:text-red-600">Clear</button>}
                </div>

                {syms.length === 0 ? (
                  <p className="mt-3 text-xs text-gray-500">Pick an element from the table to begin.</p>
                ) : (
                  <>
                    <ul className="mt-3 divide-y divide-gray-100">
                      {syms.map(s => (
                        <li key={s} className="flex items-center gap-2 py-2">
                          <span className="w-8 text-sm font-semibold text-gray-900">{s}</span>
                          <span className="flex-1 truncate text-xs text-gray-500">{BY_SYMBOL[s].name}</span>
                          <button type="button" onClick={() => setCount(s, clean[s] - 1)} className="h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:border-indigo-300" aria-label={`Remove one ${s}`}>−</button>
                          <input type="number" min={0} max={999} value={clean[s]} onChange={e => setCount(s, Number(e.target.value))} className="h-7 w-14 rounded-md border border-gray-200 text-center text-sm" aria-label={`${s} atom count`} />
                          <button type="button" onClick={() => setCount(s, clean[s] + 1)} className="h-7 w-7 rounded-md border border-gray-200 text-gray-600 hover:border-indigo-300" aria-label={`Add one ${s}`}>+</button>
                        </li>
                      ))}
                    </ul>

                    <dl className="mt-3 grid grid-cols-2 gap-3 text-xs">
                      <div><dt className="text-gray-400">Molar mass</dt><dd className="text-base font-semibold text-gray-900">{mass.toFixed(3)} g/mol</dd></div>
                      <div><dt className="text-gray-400">Empirical formula</dt><dd className="text-base font-semibold text-gray-900">{empirical}</dd></div>
                    </dl>

                    <div className="mt-3">
                      <div className="mb-1 text-[11px] text-gray-400">Mass percentage</div>
                      <div className="flex h-2 overflow-hidden rounded-full bg-gray-100">
                        {fractions.map((f, i) => <div key={f.symbol} style={{ width: `${f.fraction * 100}%` }} className={['bg-indigo-500', 'bg-emerald-500', 'bg-amber-500', 'bg-rose-500', 'bg-sky-500', 'bg-violet-500'][i % 6]} title={`${f.symbol} ${(f.fraction * 100).toFixed(1)}%`} />)}
                      </div>
                      <div className="mt-1 flex flex-wrap gap-x-3 text-[11px] text-gray-600">
                        {fractions.map(f => <span key={f.symbol}>{f.symbol} {(f.fraction * 100).toFixed(2)}%</span>)}
                      </div>
                    </div>

                    <div className={`mt-4 rounded-xl px-3 py-2.5 text-xs ${balance.status === 'balanced' ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}>
                      <div className="font-medium">Charge balance: {chargeLabel}</div>
                      <p className="mt-0.5 opacity-90">{balance.message}</p>
                      {balance.solutions.length > 0 && (
                        <ul className="mt-1.5 space-y-0.5">
                          {balance.solutions.slice(0, 3).map((s, i) => (
                            <li key={i} className="font-mono text-[11px]">
                              {Object.entries(s.states).map(([el, q]) => `${el}${fmtCharge(q)}`).join('  ')}
                              {s.unusual > 0 && <span className="ml-2 font-sans text-amber-700">(less-common state)</span>}
                            </li>
                          ))}
                        </ul>
                      )}
                    </div>

                    <div className="mt-4 flex flex-wrap gap-2">
                      <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                      <button type="button" onClick={async () => { try { await navigator.clipboard.writeText(formulaPlain(clean)); setCopied(true); } catch { /* clipboard blocked */ } }} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">{copied ? 'Copied ✓' : 'Copy formula'}</button>
                      {perovskiteLink && <Link href={perovskiteLink} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in perovskite lab →</Link>}
                    </div>
                  </>
                )}
              </div>
              {syms.length > 0 && <EvidencePanel rule={{ label: balance.status === 'balanced' ? 'Charge can balance with tabulated oxidation states.' : balance.message, ok: balance.status === 'balanced' ? true : balance.status === 'unbalanced' ? false : null }} />}
            </div>
          </div>
        </div>

        {syms.length > 0 && (
          <div className="fixed inset-x-0 bottom-0 z-30 border-t border-gray-200 bg-white/95 px-4 py-2.5 backdrop-blur lg:hidden" style={{ paddingBottom: 'max(0.625rem, env(safe-area-inset-bottom))' }}>
            <div className="mx-auto flex max-w-7xl items-center gap-3">
              <div className="min-w-0 flex-1">
                <div className="truncate text-lg font-semibold leading-tight text-gray-900">{formulaOf(clean)}</div>
                <div className="truncate text-[11px] text-gray-500">{mass.toFixed(2)} g/mol · charge {balance.status === 'balanced' ? 'can balance' : balance.status === 'unbalanced' ? 'no balance found' : 'n/a'}</div>
              </div>
              <button type="button" onClick={() => document.getElementById('composition-result')?.scrollIntoView({ behavior: 'smooth', block: 'start' })} className="h-10 shrink-0 rounded-xl bg-indigo-600 px-4 text-sm font-medium text-white">Review</button>
            </div>
          </div>
        )}
      </main>
    </>
  );
}
FILEEOF

write_file src/app/chemistry/perovskite-lab/page.tsx << 'FILEEOF'
'use client';
import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { CrystalViewer, type SiteStyle } from '@/components/chemistry/CrystalViewer';
import { EvidencePanel } from '@/components/chemistry/EvidencePanel';
import { CandidatesPanel } from '@/components/chemistry/CandidatesPanel';
import { ELEMENTS, BY_SYMBOL } from '@/lib/chemistry/elements';
import { molarMass, formulaOf, formulaPlain } from '@/lib/chemistry/compound';
import {
  MODELS, RADII_A_XII, RADII_B_VI, RADII_X_VI, analyseModel, availableStates, density, key,
  toCif, withBoundaryImages, type ModelId, type Site, type ModelSites,
} from '@/lib/chemistry/perovskite';
import { saveCandidate, download, type Candidate } from '@/lib/chemistry/candidates';

type SiteKey = 'A' | 'B' | 'B2' | 'X';
type Pick = { symbol: string; charge: number };
type Sites = Record<SiteKey, Pick>;

const TABLE: Record<SiteKey, Record<string, number>> = { A: RADII_A_XII, B: RADII_B_VI, B2: RADII_B_VI, X: RADII_X_VI };
const SITE_NAME: Record<SiteKey, string> = { A: 'A site (12-coordinate)', B: 'B site (octahedral)', B2: 'B′ site (octahedral)', X: 'X site (anion)' };
const COLORS: Record<SiteKey, string> = { A: '#f59e0b', B: '#818cf8', B2: '#2dd4bf', X: '#f87171' };

interface Preset { label: string; model: ModelId; sites: Sites; note: string }
const p = (symbol: string, charge: number): Pick => ({ symbol, charge });
const PRESETS: Preset[] = [
  { label: 'NaMgBr₃', model: 'cubic', sites: { A: p('Na', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('Br', -1) },
    note: 'Your research candidate. Assembling the formula asserts nothing about stability; the geometric factors below are only a first screen.' },
  { label: 'CsPbBr₃', model: 'cubic', sites: { A: p('Cs', 1), B: p('Pb', 2), B2: p('Ag', 1), X: p('Br', -1) },
    note: 'Well-studied halide perovskite; reported cubic only at elevated temperature, distorted (orthorhombic) at room temperature. Verify in the literature.' },
  { label: 'CsSnI₃', model: 'cubic', sites: { A: p('Cs', 1), B: p('Sn', 2), B2: p('Ag', 1), X: p('I', -1) },
    note: 'Reported perovskite with tin(II), which oxidises readily; distorted at room temperature. Verify in the literature.' },
  { label: 'SrTiO₃', model: 'cubic', sites: { A: p('Sr', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'The textbook cubic oxide perovskite at room temperature — a good sanity check for t ≈ 1.' },
  { label: 'BaTiO₃', model: 'cubic', sites: { A: p('Ba', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'Cubic only above its Curie temperature; ferroelectric and non-cubic at room temperature.' },
  { label: 'CaTiO₃', model: 'cubic', sites: { A: p('Ca', 2), B: p('Ti', 4), B2: p('Ag', 1), X: p('O', -2) },
    note: 'The mineral perovskite: a tilted orthorhombic structure, so the cubic model here is only the idealised parent.' },
  { label: 'KMgF₃', model: 'cubic', sites: { A: p('K', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('F', -1) },
    note: 'Fluoroperovskite reported with a cubic structure; a useful comparison for NaMgBr₃ (same B cation, different A and X).' },
  { label: 'NaMgF₃', model: 'cubic', sites: { A: p('Na', 1), B: p('Mg', 2), B2: p('Ag', 1), X: p('F', -1) },
    note: 'Reported as a tilted orthorhombic perovskite; compare its t with NaMgBr₃ to see the effect of swapping F for Br.' },
  { label: 'Cs₂AgBiBr₆', model: 'double', sites: { A: p('Cs', 1), B: p('Ag', 1), B2: p('Bi', 3), X: p('Br', -1) },
    note: 'Lead-free double perovskite reported in the literature, with rock-salt B/B′ ordering.' },
];

function fromQuery(): Partial<Sites> | null {
  const q = new URLSearchParams(window.location.search);
  const out: Partial<Sites> = {};
  (['A', 'B', 'X'] as const).forEach(k => {
    const sym = q.get(k);
    if (sym && BY_SYMBOL[sym]) {
      const tab = availableStates(sym, k);
      const e = BY_SYMBOL[sym];
      const fallback = k === 'X' ? e.common.find(v => v < 0) : e.common.find(v => v > 0);
      out[k] = { symbol: sym, charge: tab[0] ?? fallback ?? (k === 'X' ? -1 : 1) };
    }
  });
  return Object.keys(out).length ? out : null;
}

function SitePicker({ site, value, onChange }: { site: SiteKey; value: Pick; onChange: (v: Pick) => void }) {
  const kind: 'A' | 'B' | 'X' = site === 'B2' ? 'B' : site;
  const withData = ELEMENTS.filter(e => availableStates(e.symbol, kind).length > 0);
  const others = ELEMENTS.filter(e => availableStates(e.symbol, kind).length === 0);
  const el = BY_SYMBOL[value.symbol];
  const wantNeg = kind === 'X';
  const states = Array.from(new Set([
    ...availableStates(value.symbol, kind),
    ...[...el.common, ...el.other].filter(v => (wantNeg ? v < 0 : v > 0)),
  ])).sort((a, b) => b - a);
  const r = TABLE[site][key(value.symbol, value.charge)];
  const pickEl = (sym: string) => {
    const e = BY_SYMBOL[sym];
    const tab = availableStates(sym, kind);
    const fb = (wantNeg ? e.common.find(v => v < 0) : e.common.find(v => v > 0)) ?? (wantNeg ? -1 : 1);
    onChange({ symbol: sym, charge: tab.includes(value.charge) ? value.charge : tab[0] ?? fb });
  };
  return (
    <div className="rounded-xl border border-gray-200 p-3">
      <div className="flex items-center gap-1.5 text-[11px] font-medium text-gray-500">
        <span className="inline-block h-2.5 w-2.5 rounded-full" style={{ background: COLORS[site] }} />{SITE_NAME[site]}
      </div>
      <div className="mt-2 flex gap-2">
        <select value={value.symbol} onChange={e => pickEl(e.target.value)} className="h-8 min-w-0 flex-1 rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${SITE_NAME[site]} element`}>
          <optgroup label="Radius data available">
            {withData.map(e => <option key={e.symbol} value={e.symbol}>{e.symbol} — {e.name}</option>)}
          </optgroup>
          <optgroup label="No radius data (factors unavailable)">
            {others.map(e => <option key={e.symbol} value={e.symbol}>{e.symbol} — {e.name}</option>)}
          </optgroup>
        </select>
        <select value={value.charge} onChange={e => onChange({ ...value, charge: Number(e.target.value) })} className="h-8 w-20 rounded-md border border-gray-200 bg-white px-2 text-sm" aria-label={`${SITE_NAME[site]} charge`}>
          {(states.length ? states : [value.charge]).map(q => <option key={q} value={q}>{q > 0 ? '+' : '−'}{Math.abs(q)}</option>)}
        </select>
      </div>
      <div className="mt-1.5 text-[11px] text-gray-400">{r != null ? `Shannon radius ${r.toFixed(3)} Å` : 'No tabulated radius for this ion/site'}</div>
    </div>
  );
}

export default function PerovskiteLabPage() {
  const [model, setModel] = useState<ModelId>('cubic');
  const [sites, setSites] = useState<Sites>(PRESETS[0].sites);
  const [presetNote, setPresetNote] = useState<string | null>(PRESETS[0].note);
  const [n, setN] = useState(1);
  const [aMode, setAMode] = useState<'BX' | 'AX' | 'custom'>('BX');
  const [aCustom, setACustom] = useState(5.0);
  const [bonds, setBonds] = useState(true);
  const [cell, setCell] = useState(true);
  const [showA, setShowA] = useState(true);
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    const t = setTimeout(() => {
      const q = fromQuery();
      if (q) {
        setSites(s => ({ ...s, ...q }));
        setPresetNote('Pre-filled from the compound builder (A = most electropositive, X = most electronegative). Check the assignment and oxidation states.');
      }
    }, 0);
    return () => clearTimeout(t);
  }, []);

  const double = model === 'double';
  const modelDef = MODELS[model];
  const modelSites: ModelSites = { A: sites.A, B: sites.B, B2: double ? sites.B2 : undefined, X: sites.X };
  const report = useMemo(() => analyseModel(model, modelSites),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [model, sites, double]);

  const a = aMode === 'custom' ? aCustom : aMode === 'AX' ? report.aAX ?? aCustom : report.aBX ?? aCustom;
  const elements: Record<Site, string | undefined> = { A: sites.A.symbol, B: sites.B.symbol, B2: double ? sites.B2.symbol : undefined, X: sites.X.symbol };
  const dens = density(modelDef, a, elements);
  const mass = molarMass(report.composition);
  const chargeOk = Math.abs(report.chargeSum) < 1e-9;

  const atoms = useMemo(() => withBoundaryImages(modelDef.atoms, n), [modelDef, n]);
  const styles = useMemo(() => {
    const edge = a * modelDef.cellFactor;
    const mk = (k: SiteKey): SiteStyle => {
      const r = TABLE[k][key(sites[k].symbol, sites[k].charge)] ?? 0.9;
      return { label: sites[k].symbol, color: COLORS[k], radius: r / edge };
    };
    const out: Partial<Record<Site, SiteStyle>> = { A: mk('A'), B: mk('B'), X: mk('X') };
    if (double) out.B2 = mk('B2');
    return out;
  }, [sites, a, modelDef, double]);

  const setSite = (k: SiteKey, v: Pick) => { setSites(s => ({ ...s, [k]: v })); setSaved(false); setPresetNote(null); };
  const loadPreset = (pr: Preset) => { setModel(pr.model); setSites(pr.sites); setPresetNote(pr.note); setSaved(false); };

  const onSave = () => {
    saveCandidate({
      name: formulaPlain(report.composition) + (double ? ' (double)' : ''),
      kind: 'perovskite', formula: formulaPlain(report.composition), composition: report.composition, molarMass: mass,
      chargeStatus: chargeOk ? 'Charges sum to zero' : `Charge sum ${report.chargeSum > 0 ? '+' : ''}${report.chargeSum}`,
      perovskite: { model, sites: { A: sites.A, B: sites.B, B2: double ? sites.B2 : undefined, X: sites.X }, a, tolerance: report.tolerance, octahedral: report.octahedral, density: dens },
      note: presetNote ?? undefined,
    });
    setSaved(true);
  };
  const onLoad = (c: Candidate) => {
    if (c.perovskite) {
      setModel(c.perovskite.model);
      setSites(s => ({ ...s, ...(c.perovskite!.sites as Partial<Sites>) }));
      setAMode('custom'); setACustom(c.perovskite.a); setPresetNote(c.note ?? null);
    }
  };

  const fmt = (v: number | null, d = 3) => (v == null ? '—' : v.toFixed(d));

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6">
          <Link href="/chemistry" className="text-xs text-gray-400 transition hover:text-indigo-600">← Chemistry</Link>
          <h1 className="mt-1 text-xl font-semibold text-gray-900 sm:text-2xl">Perovskite lab</h1>
          <p className="mb-4 mt-1 text-sm text-gray-500">Assign A, B and X sites, check the geometry, and inspect an idealised model. Idealised models are proposals — not relaxed or confirmed structures.</p>

          <div className="mb-5 flex flex-wrap gap-2">
            {PRESETS.map(pr => (
              <button key={pr.label} type="button" onClick={() => loadPreset(pr)} className="rounded-full border border-gray-200 bg-white px-3 py-1 text-xs text-gray-700 transition hover:border-indigo-300 hover:text-indigo-700">{pr.label}</button>
            ))}
          </div>
          {presetNote && <p className="mb-5 rounded-xl border border-indigo-100 bg-indigo-50 px-3 py-2 text-xs text-indigo-900">{presetNote} <span className="opacity-70">Reference notes are summaries — check the primary literature before citing.</span></p>}

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} bondDist={0.5 / modelDef.cellFactor} sizeScale={0.36} showBonds={bonds} showCell={cell} showA={showA} />
                <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-2 border-t border-gray-100 pt-3 text-xs text-gray-600">
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={bonds} onChange={e => setBonds(e.target.checked)} />B–X bonds</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={cell} onChange={e => setCell(e.target.checked)} />Cell edges</label>
                  <label className="flex items-center gap-1.5"><input type="checkbox" checked={showA} onChange={e => setShowA(e.target.checked)} />A atoms</label>
                  <span className="ml-auto flex items-center gap-1.5">Cells
                    {[1, 2].map(v => <button key={v} type="button" onClick={() => setN(v)} className={`rounded-md border px-2 py-0.5 ${n === v ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 hover:border-indigo-300'}`}>{v}×{v}×{v}</button>)}
                  </span>
                </div>
                <p className="mt-2 text-[11px] text-gray-400">{modelDef.label} · space group {modelDef.spaceGroup}. {modelDef.note}</p>
              </div>
              <CandidatesPanel onLoad={onLoad} />
            </div>

            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-5">
                <div className="flex gap-2">
                  {(Object.keys(MODELS) as ModelId[]).map(id => (
                    <button key={id} type="button" onClick={() => { setModel(id); setSaved(false); }} className={`flex-1 rounded-lg border px-2 py-1.5 text-xs font-medium ${model === id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-600 hover:border-indigo-300'}`}>{id === 'cubic' ? 'ABX₃' : 'A₂BB′X₆'}</button>
                  ))}
                </div>
                <div className="mt-3 grid gap-3 sm:grid-cols-2">
                  {(['A', 'B', ...(double ? ['B2'] : []), 'X'] as SiteKey[]).map(k => <SitePicker key={k} site={k} value={sites[k]} onChange={v => setSite(k, v)} />)}
                </div>

                <div className="mt-4 text-[11px] font-medium uppercase tracking-wide text-gray-400">Candidate</div>
                <div className="text-3xl font-semibold text-gray-900" aria-live="polite">{formulaOf(report.composition)}</div>
                <div className="text-xs text-gray-500">{mass.toFixed(2)} g/mol per formula unit</div>

                <dl className="mt-3 divide-y divide-gray-100 text-xs">
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Charge sum</dt><dd className={`font-medium ${chargeOk ? 'text-emerald-700' : 'text-red-600'}`}>{chargeOk ? '0 (balanced)' : `${report.chargeSum > 0 ? '+' : ''}${report.chargeSum} — not balanced`}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Tolerance factor t</dt><dd className="font-medium text-gray-900">{fmt(report.tolerance)}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Octahedral factor μ</dt><dd className="font-medium text-gray-900">{fmt(report.octahedral)}</dd></div>
                  <div className="flex justify-between py-1.5"><dt className="text-gray-500">Estimated a (B–X contact / A–X contact)</dt><dd className="font-medium text-gray-900">{fmt(report.aBX, 2)} / {fmt(report.aAX, 2)} Å</dd></div>
                </dl>
                {report.missing.length > 0 && <p className="mt-2 rounded-lg bg-amber-50 px-3 py-2 text-[11px] text-amber-800">No tabulated radius for {report.missing.join('; ')} — factors can’t be computed.</p>}
                {report.tolerance != null && (
                  <div className="mt-3 space-y-1.5 text-[11px] leading-relaxed text-gray-600">
                    <p><span className="font-medium text-gray-900">t:</span> {report.toleranceVerdict}</p>
                    <p><span className="font-medium text-gray-900">μ:</span> {report.octahedralVerdict}</p>
                  </div>
                )}

                <div className="mt-4 border-t border-gray-100 pt-3">
                  <div className="text-[11px] font-medium text-gray-500">Lattice parameter a used for the model</div>
                  <div className="mt-1.5 flex flex-wrap items-center gap-2 text-xs">
                    {([['BX', 'B–X contact'], ['AX', 'A–X contact'], ['custom', 'Custom']] as const).map(([id, lab]) => (
                      <button key={id} type="button" onClick={() => setAMode(id)} className={`rounded-md border px-2 py-1 ${aMode === id ? 'border-indigo-600 bg-indigo-600 text-white' : 'border-gray-200 text-gray-600 hover:border-indigo-300'}`}>{lab}</button>
                    ))}
                    {aMode === 'custom' && <input type="number" step={0.01} min={2} max={12} value={aCustom} onChange={e => setACustom(Number(e.target.value) || 5)} className="h-7 w-20 rounded-md border border-gray-200 px-2" aria-label="Custom lattice parameter in angstroms" />}
                    <span className="text-gray-500">a = {a.toFixed(3)} Å{dens != null && ` · ρ ≈ ${dens.toFixed(2)} g/cm³`}</span>
                  </div>
                  <p className="mt-1 text-[11px] text-gray-400">An ionic-radius estimate, not a relaxed value. If t ≠ 1 the two contact estimates disagree — that mismatch is why real structures tilt or distort.</p>
                </div>

                <div className="mt-4 flex flex-wrap gap-2">
                  <button type="button" onClick={onSave} className="rounded-lg bg-indigo-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-indigo-700">{saved ? 'Saved ✓' : 'Save candidate'}</button>
                  <button type="button" onClick={() => download(`${formulaPlain(report.composition)}-${model}-proposed.cif`, toCif({ title: formulaPlain(report.composition), a, model: modelDef, elements }), 'chemical/x-cif')} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Download CIF (proposed)</button>
                  <Link href={`/chemistry/compound-builder?c=${Object.entries(report.composition).map(([s, c]) => `${s}:${c}`).join(',')}`} className="rounded-lg border border-gray-200 px-3 py-1.5 text-xs text-gray-700 hover:border-indigo-300">Open in builder →</Link>
                </div>
              </div>
              <EvidencePanel
                rule={{ label: report.tolerance == null ? 'Geometric factors unavailable (missing radii).' : `Charge ${chargeOk ? 'balances' : 'does not balance'}; t = ${report.tolerance.toFixed(3)}, μ = ${report.octahedral!.toFixed(3)}. Heuristics only.`, ok: report.tolerance == null ? null : chargeOk && report.tolerance >= 0.8 && report.tolerance <= 1.06 && report.octahedral! >= 0.414 }}
                extra={`${double ? 'double perovskite' : 'cubic'} model`}
              />
            </div>
          </div>
        </div>
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
  const [tid, setTid] = useState<TemplateId>(PRESETS[0].template);
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

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.3fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <CrystalViewer atoms={atoms} extent={n} styles={styles} siteNames={siteNames} bondDist={NN_DIST} bondMode="nn" sizeScale={0.62} sizeNote="atom size shows period only" showBonds={bonds} showCell={cell} showA />
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

            <div className="min-w-0 space-y-5">
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

          <div className="grid grid-cols-1 gap-5 lg:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-5">
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

            <div className="min-w-0 space-y-5">
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
echo "Done. npm run dev, then open /chemistry/periodic-table on a phone or a 390px-wide browser window."
