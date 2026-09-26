'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label } from 'recharts';
import { generateHermiteCurve, generateLaguerreCurve, testFn, pulse } from '@/lib/physics/hermiteLaguerreDelta';

const COLORS = ['#2563eb', '#059669', '#d97706', '#7c3aed', '#dc2626', '#0891b2', '#65a30d'];

interface CurveProps { mode: 'hermite' | 'laguerre'; shown: number[]; }

export function HermiteLaguerreGraph({ mode, shown }: CurveProps) {
  const isH = mode === 'hermite';
  const maxOrder = isH ? 6 : 5;

  const merged = useMemo(() => {
    const curves = Array.from({ length: maxOrder + 1 }, (_, n) => isH ? generateHermiteCurve(n) : generateLaguerreCurve(n));
    const points = curves[0].length;
    const out: Record<string, number>[] = [];
    for (let i = 0; i < points; i++) {
      const row: Record<string, number> = { x: curves[0][i].x };
      curves.forEach((c, n) => { row[`n${n}`] = c[i].y; });
      out.push(row);
    }
    return out;
  }, [isH, maxOrder]);

  return (
    <ResponsiveContainer width="100%" height={340}>
      <LineChart data={merged} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={isH ? [-2.6, 2.6] : [0, 10]}>
          <Label value="x" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={[-13, 13]}>
          <Label value={isH ? 'Hₙ(x)' : 'Lₙ(x)'} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
        {Array.from({ length: maxOrder + 1 }, (_, n) => n).filter(n => shown.includes(n)).map(n => (
          <Line key={n} type="monotone" dataKey={`n${n}`} name={`${isH ? 'H' : 'L'}${n}`}
            stroke={COLORS[n % COLORS.length]} strokeWidth={2} dot={false} isAnimationActive={false} />
        ))}
      </LineChart>
    </ResponsiveContainer>
  );
}

interface DeltaProps { eps: number; fname: string; }

export function DiracDeltaGraph({ eps, fname }: DeltaProps) {
  const data = useMemo(() => {
    const xmin = -6, xmax = 6, N = 300;
    const out: { x: number; f: number; delta: number }[] = [];
    for (let i = 0; i <= N; i++) {
      const x = xmin + (i / N) * (xmax - xmin);
      out.push({ x, f: testFn(fname, x), delta: Math.min(pulse(eps, x), 19) });
    }
    return out;
  }, [eps, fname]);

  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="x" type="number" domain={[-6, 6]} tick={{ fontSize: 10 }}>
          <Label value="x" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={[0, 20]}>
          <Label value="value" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
        <Line type="monotone" dataKey="f" name="f(x)" stroke="#d97706" strokeWidth={2} strokeDasharray="4 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="delta" name="δ_ε(x)" stroke="#2563eb" strokeWidth={2.4} dot={false} isAnimationActive={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}
