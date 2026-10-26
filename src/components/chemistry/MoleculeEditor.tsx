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
