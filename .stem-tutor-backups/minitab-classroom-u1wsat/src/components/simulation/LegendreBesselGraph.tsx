'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label } from 'recharts';
import { generateLegendreCurve, generateBesselCurve } from '@/lib/physics/legendreBessel';

const COLORS = ['#2563eb', '#059669', '#d97706', '#7c3aed', '#dc2626', '#0891b2', '#65a30d'];

interface Props {
  mode: 'legendre' | 'bessel';
  shown: number[];
}

export function LegendreBesselGraph({ mode, shown }: Props) {
  const isLeg = mode === 'legendre';
  const maxOrder = isLeg ? 6 : 6;

  const merged = useMemo(() => {
    const curves = Array.from({ length: maxOrder + 1 }, (_, n) =>
      isLeg ? generateLegendreCurve(n) : generateBesselCurve(n)
    );
    const points = curves[0].length;
    const out: Record<string, number>[] = [];
    for (let i = 0; i < points; i++) {
      const row: Record<string, number> = { x: curves[0][i].x };
      curves.forEach((c, n) => { row[`n${n}`] = c[i].y; });
      out.push(row);
    }
    return out;
  }, [isLeg, maxOrder]);

  return (
    <ResponsiveContainer width="100%" height={340}>
      <LineChart data={merged} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={isLeg ? [-1, 1] : [0, 15]}>
          <Label value="x" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={isLeg ? [-1.1, 1.1] : [-0.5, 1.05]}>
          <Label value={isLeg ? 'Pₙ(x)' : 'Jₙ(x)'} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} />
        {Array.from({ length: maxOrder + 1 }, (_, n) => n)
          .filter(n => shown.includes(n))
          .map(n => (
            <Line key={n} type="monotone" dataKey={`n${n}`} name={`${isLeg ? 'P' : 'J'}${n}`}
              stroke={COLORS[n % COLORS.length]} strokeWidth={2} dot={false} isAnimationActive={false} />
          ))}
      </LineChart>
    </ResponsiveContainer>
  );
}
