'use client';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label } from 'recharts';

interface DataPoint { t: number; v: number; a: number; x: number; }

interface Props {
  data: DataPoint[];
  show: 'v' | 'a' | 'x';
}

const CONFIG = {
  v: { color: '#6366f1', label: 'Velocity (m/s)', yLabel: 'v (m/s)' },
  a: { color: '#f59e0b', label: 'Acceleration (m/s²)', yLabel: 'a (m/s²)' },
  x: { color: '#10b981', label: 'Displacement (m)', yLabel: 'x (m)' },
};

export function NewtonsGraph({ data, show }: Props) {
  const cfg = CONFIG[show];
  return (
    <ResponsiveContainer width="100%" height={180}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={['dataMin', 'dataMax']}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={cfg.yLabel} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <Line type="monotone" dataKey={show} stroke={cfg.color} strokeWidth={2} dot={false} name={cfg.label} />
      </LineChart>
    </ResponsiveContainer>
  );
}
