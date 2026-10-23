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
