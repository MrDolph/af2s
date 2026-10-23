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
