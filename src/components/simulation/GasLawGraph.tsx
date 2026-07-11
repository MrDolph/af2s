'use client';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ReferenceDot, ResponsiveContainer, Label,
} from 'recharts';
import { boyleCurve, charlesCurve, pressureLawCurve } from '@/lib/physics/gas-laws';

interface GasLawGraphProps {
  law: 'boyle' | 'charles' | 'pressure';
  currentV: number;
  currentP: number;
  currentT: number;
  moles: number;
}

export function GasLawGraph({ law, currentV, currentP, currentT, moles }: GasLawGraphProps) {
  if (law === 'boyle') {
    const data = boyleCurve(moles, currentT);
    return (
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="v" type="number" domain={[0.5, 10]} tick={{ fontSize: 11 }}>
            <Label value="Volume (L)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 11 }}>
            <Label value="Pressure (kPa)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
          </YAxis>
          <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} kPa`, 'Pressure']} labelFormatter={(v) => `Volume: ${v} L`} />
          <Line type="monotone" dataKey="p" stroke="#6366f1" strokeWidth={2} dot={false} />
          <ReferenceDot x={+currentV.toFixed(2)} y={+currentP.toFixed(2)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (law === 'charles') {
    const data = charlesCurve(moles, currentP);
    return (
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" domain={[100, 600]} tick={{ fontSize: 11 }}>
            <Label value="Temperature (K)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 11 }}>
            <Label value="Volume (L)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
          </YAxis>
          <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} L`, 'Volume']} labelFormatter={(t) => `Temp: ${t} K`} />
          <Line type="monotone" dataKey="v" stroke="#10b981" strokeWidth={2} dot={false} />
          <ReferenceDot x={currentT} y={+(charlesCurve(moles, currentP, currentT, currentT, 1)[0]?.v ?? 0)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  // Pressure Law: P vs T
  const data = pressureLawCurve(moles, currentV);
  const currentPonCurve = +(data.find(d => d.t === currentT)?.p ?? currentP).toFixed(2);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" domain={[100, 600]} tick={{ fontSize: 11 }}>
          <Label value="Temperature (K)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 11 }}>
          <Label value="Pressure (kPa)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
        </YAxis>
        <Tooltip formatter={(v) => [`${Number(v).toFixed(2)} kPa`, 'Pressure']} labelFormatter={(t) => `Temp: ${t} K`} />
        <Line type="monotone" dataKey="p" stroke="#ef4444" strokeWidth={2} dot={false} />
        <ReferenceDot x={currentT} y={currentPonCurve} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
      </LineChart>
    </ResponsiveContainer>
  );
}
