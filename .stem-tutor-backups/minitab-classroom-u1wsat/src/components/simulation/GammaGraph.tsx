'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateGammaBranch, gamma, factorial } from '@/lib/physics/gammaFunction';

interface Props {
  x: number;
  showNegative: boolean;
}

export function GammaGraph({ x, showNegative }: Props) {
  const positiveData = useMemo(() => generateGammaBranch(0.05, 6, 400), []);
  const neg1 = useMemo(() => generateGammaBranch(-0.98, -0.02, 150), []);
  const neg2 = useMemo(() => generateGammaBranch(-1.98, -1.02, 150), []);
  const neg3 = useMemo(() => generateGammaBranch(-2.98, -2.02, 150), []);

  // Merge all branches into one dataset, keyed by x, so Recharts can share one XAxis.
  const merged = useMemo(() => {
    const all = showNegative ? [...neg3, ...neg2, ...neg1, ...positiveData] : positiveData;
    return all.map(d => ({ x: d.x, gamma: d.gamma }));
  }, [positiveData, neg1, neg2, neg3, showNegative]);

  const factorialMarks = useMemo(() => {
    const marks: { x: number; y: number }[] = [];
    for (let n = 0; n <= 5; n++) {
      const val = factorial(n);
      if (val <= 24) marks.push({ x: n + 1, y: val });
    }
    return marks;
  }, []);

  const gx = gamma(x);
  const xmin = showNegative ? -4.5 : 0;

  return (
    <ResponsiveContainer width="100%" height={320}>
      <LineChart data={merged} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="x" type="number" domain={[xmin, 6]} tick={{ fontSize: 10 }}>
          <Label value="x" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis domain={[-12, 24]} tick={{ fontSize: 10 }}>
          <Label value="Γ(x)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [v === null ? '—' : Number(v).toFixed(4)]} labelFormatter={v => `x=${Number(v).toFixed(2)}`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        {showNegative && [0, -1, -2, -3, -4].map(n => (
          <ReferenceLine key={n} x={n} stroke="#f59e0b" strokeDasharray="3 3" opacity={0.5} />
        ))}
        <Line type="monotone" dataKey="gamma" stroke="#6366f1" strokeWidth={2.2} dot={false} connectNulls={false} isAnimationActive={false} />
        {factorialMarks.map(m => (
          <ReferenceDot key={m.x} x={m.x} y={m.y} r={4} fill="#10b981" stroke="none" />
        ))}
        {isFinite(gx) && Math.abs(gx) < 30 && (
          <ReferenceDot x={x} y={gx} r={6} fill="#6366f1" stroke="#fff" strokeWidth={2} />
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
