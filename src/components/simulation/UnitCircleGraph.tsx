'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceDot, ReferenceLine } from 'recharts';
import { generateTrigCurve, deg2rad } from '@/lib/physics/unitCircle';

interface Props {
  angleDeg: number;
}

export function UnitCircleGraph({ angleDeg }: Props) {
  const data = useMemo(() => generateTrigCurve(), []);
  const rad = deg2rad(angleDeg);
  const sinVal = Math.sin(rad), cosVal = Math.cos(rad);

  return (
    <div className="space-y-3">
      <div>
        <p className="text-[11px] font-medium text-rose-600 mb-1">sin θ</p>
        <ResponsiveContainer width="100%" height={110}>
          <LineChart data={data} margin={{ top: 4, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="deg" type="number" domain={[0, 360]} ticks={[0, 90, 180, 270, 360]} tick={{ fontSize: 9 }} />
            <YAxis domain={[-1, 1]} ticks={[-1, 0, 1]} tick={{ fontSize: 9 }} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={d => `${d}°`} />
            <ReferenceLine y={0} stroke="#e2e8f0" />
            <Line type="monotone" dataKey="sin" stroke="#ef4444" strokeWidth={2} dot={false} isAnimationActive={false} />
            <ReferenceLine x={angleDeg} stroke="#94a3b8" strokeDasharray="3 3" />
            <ReferenceDot x={angleDeg} y={sinVal} r={5} fill="#ef4444" stroke="#fff" strokeWidth={1.5} />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <div>
        <p className="text-[11px] font-medium text-amber-600 mb-1">cos θ</p>
        <ResponsiveContainer width="100%" height={110}>
          <LineChart data={data} margin={{ top: 4, right: 12, left: 0, bottom: 0 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="deg" type="number" domain={[0, 360]} ticks={[0, 90, 180, 270, 360]} tick={{ fontSize: 9 }} />
            <YAxis domain={[-1, 1]} ticks={[-1, 0, 1]} tick={{ fontSize: 9 }} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} labelFormatter={d => `${d}°`} />
            <ReferenceLine y={0} stroke="#e2e8f0" />
            <Line type="monotone" dataKey="cos" stroke="#eab308" strokeWidth={2} dot={false} isAnimationActive={false} />
            <ReferenceLine x={angleDeg} stroke="#94a3b8" strokeDasharray="3 3" />
            <ReferenceDot x={angleDeg} y={cosVal} r={5} fill="#eab308" stroke="#fff" strokeWidth={1.5} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
