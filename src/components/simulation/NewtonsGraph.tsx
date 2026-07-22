'use client';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceDot } from 'recharts';

interface DataPoint { t: number; v: number; a: number; x: number; }

interface Props {
  data: DataPoint[];
  show: 'v' | 'a' | 'x';
  liveT: number;    // current simulation time (0 = not started yet)
  liveValue: number; // the actual live value of whichever series is selected
}

const CONFIG = {
  v: { color: '#6366f1', label: 'Velocity (m/s)', yLabel: 'v (m/s)' },
  a: { color: '#f59e0b', label: 'Acceleration (m/s²)', yLabel: 'a (m/s²)' },
  x: { color: '#10b981', label: 'Displacement (m)', yLabel: 'x (m)' },
};

// Shows the FULL predicted curve immediately (computed up front from the
// current parameters), with a live dot riding along it as the simulation
// plays — the same "ghost path + live marker" pattern used for projectile
// motion, SHM, and radioactive decay elsewhere in this app. This is what
// makes "v = constant" visibly a flat line across the whole graph the
// moment you touch a slider, rather than something that only appears after
// the animation has had time to draw it point by point.
export function NewtonsGraph({ data, show, liveT, liveValue }: Props) {
  const cfg = CONFIG[show];
  const tMax = data.length > 0 ? data[data.length - 1].t : 0;
  return (
    <ResponsiveContainer width="100%" height={180}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }} domain={[0, tMax]}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={cfg.yLabel} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <Line type="monotone" dataKey={show} stroke={cfg.color} strokeWidth={2} dot={false} isAnimationActive={false} name={cfg.label} />
        {liveT > 0 && (
          <ReferenceDot x={Math.min(liveT, tMax)} y={liveValue} r={5} fill={cfg.color} stroke="#fff" strokeWidth={2} />
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
