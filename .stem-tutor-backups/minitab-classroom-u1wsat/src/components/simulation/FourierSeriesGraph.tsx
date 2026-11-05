'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label } from 'recharts';
import { generateSeriesData, type FourierTarget } from '@/lib/physics/fourierSeries';

interface Props { target: FourierTarget; n: number; }

export function FourierSeriesGraph({ target, n }: Props) {
  const data = useMemo(() => generateSeriesData(target, n), [target, n]);

  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }}>
          <Label value="x" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }} domain={[-1.4, 1.4]}>
          <Label value="f(x)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} />
        <Line type="monotone" dataKey="target" name="target" stroke="#94a3b8" strokeWidth={2} strokeDasharray="5 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="approx" name={`N=${n} terms`} stroke="#059669" strokeWidth={2.2} dot={false} isAnimationActive={false} />
      </LineChart>
    </ResponsiveContainer>
  );
}
