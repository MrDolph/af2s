'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Label } from 'recharts';
import { generatePairData, generateTransformData, type TransformPair } from '@/lib/physics/fourierTransform';

interface Props { pair: TransformPair; a: number; }

export function FourierTransformGraph({ pair, a }: Props) {
  const xmaxSpace = Math.max(6, 4 * a + 2);
  const xmaxFreq = Math.max(6, 6 / a);

  const { data: spaceData } = useMemo(() => generatePairData(pair, a, xmaxSpace), [pair, a, xmaxSpace]);
  const { data: freqData } = useMemo(() => generateTransformData(pair, a, xmaxFreq), [pair, a, xmaxFreq]);

  return (
    <div className="space-y-4">
      <div>
        <p className="text-[11px] font-mono text-gray-400 mb-1">f(x) — position space</p>
        <ResponsiveContainer width="100%" height={150}>
          <LineChart data={spaceData} margin={{ top: 4, right: 16, left: 10, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="x" type="number" domain={[-xmaxSpace, xmaxSpace]} tick={{ fontSize: 9 }} />
            <YAxis tick={{ fontSize: 9 }} domain={[-1.1, 1.1]} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
            <Line type="monotone" dataKey="y" stroke="#2563eb" strokeWidth={2} dot={false} isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
      <div>
        <p className="text-[11px] font-mono text-gray-400 mb-1">F(k) — frequency space</p>
        <ResponsiveContainer width="100%" height={150}>
          <LineChart data={freqData} margin={{ top: 4, right: 16, left: 10, bottom: 4 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="x" type="number" domain={[-xmaxFreq, xmaxFreq]} tick={{ fontSize: 9 }} />
            <YAxis tick={{ fontSize: 9 }} domain={[-1.1, 1.1]} />
            <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
            <Line type="monotone" dataKey="y" stroke="#059669" strokeWidth={2} dot={false} isAnimationActive={false} />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
