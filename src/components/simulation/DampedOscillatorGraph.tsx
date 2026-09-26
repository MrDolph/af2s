'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateDampedData, dampedY, type DampedOscillatorParams } from '@/lib/physics/dampedOscillator';

const TMAX = 10;

interface Props extends DampedOscillatorParams {
  currentT?: number;
}

export function DampedOscillatorGraph({ gamma, omega0, y0, yp0, currentT = 0 }: Props) {
  // Memoized — regenerating 300 points every animation tick was wasted work;
  // the curve only changes when the physics parameters change.
  const data = useMemo(
    () => generateDampedData({ gamma, omega0, y0, yp0 }, TMAX),
    [gamma, omega0, y0, yp0]
  );

  const markerT = Math.min(currentT, TMAX);
  const liveY = dampedY(markerT, { gamma, omega0, y0, yp0 });

  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" domain={[0, TMAX]} tick={{ fontSize: 10 }}>
          <Label value="Time t (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="y(t)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey="envelope" stroke="#f59e0b" strokeWidth={1.2} strokeDasharray="4 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="envelopeNeg" stroke="#f59e0b" strokeWidth={1.2} strokeDasharray="4 3" dot={false} isAnimationActive={false} />
        <Line type="monotone" dataKey="y" stroke="#6366f1" strokeWidth={2.2} dot={false} isAnimationActive={false} />
        {markerT > 0 && (
          <>
            <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
            <ReferenceDot x={markerT} y={liveY} r={6} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          </>
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
