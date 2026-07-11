'use client';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ReferenceDot, ResponsiveContainer, Label, Legend,
} from 'recharts';
import {
  boyleCurve, charlesCurve, pressureLawCurve,
  compressibilityCurve, pvIsotherm,
} from '@/lib/physics/gas-laws';

interface GasLawGraphProps {
  law: 'boyle' | 'charles' | 'pressure' | 'ideal' | 'real';
  currentV: number;
  currentP: number;
  currentT: number;
  moles: number;
  selectedGas?: string;
}

export function GasLawGraph({ law, currentV, currentP, currentT, moles, selectedGas = 'CO2' }: GasLawGraphProps) {
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

  if (law === 'pressure') {
    const data = pressureLawCurve(moles, currentV);
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
          <ReferenceDot x={currentT} y={+(pressureLawCurve(moles, currentV, currentT, currentT, 1)[0]?.p ?? 0)} r={6} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (law === 'ideal') {
    // Show multiple isotherms for different mole counts
    const t1 = boyleCurve(0.05, currentT).map(d => ({ v: d.v, p1: d.p }));
    const t2 = boyleCurve(0.1,  currentT).map(d => ({ v: d.v, p2: d.p }));
    const t3 = boyleCurve(0.2,  currentT).map(d => ({ v: d.v, p3: d.p }));
    const data = t1.map((d, i) => ({ ...d, ...t2[i], ...t3[i] }));
    return (
      <ResponsiveContainer width="100%" height={220}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="v" type="number" domain={[0.5, 10]} tick={{ fontSize: 10 }}>
            <Label value="Volume (L)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Pressure (kPa)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
          </YAxis>
          <Tooltip formatter={(v) => [`${Number(v).toFixed(1)} kPa`]} labelFormatter={(v) => `V = ${v} L`} />
          <Legend wrapperStyle={{ fontSize: 10 }} />
          <Line type="monotone" dataKey="p1" stroke="#c7d2fe" strokeWidth={1.5} dot={false} name="n = 0.05 mol" />
          <Line type="monotone" dataKey="p2" stroke="#6366f1" strokeWidth={2} dot={false} name="n = 0.1 mol" />
          <Line type="monotone" dataKey="p3" stroke="#3730a3" strokeWidth={2.5} dot={false} name="n = 0.2 mol" />
        </LineChart>
      </ResponsiveContainer>
    );
  }

  // Real gas — compressibility factor Z vs P
  const data = compressibilityCurve(moles, currentT, selectedGas);
  return (
    <ResponsiveContainer width="100%" height={220}>
      <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="p" type="number" tick={{ fontSize: 10 }}>
          <Label value="Pressure (kPa)" position="insideBottom" offset={-18} style={{ fontSize: 11, fill: '#64748b' }} />
        </XAxis>
        <YAxis domain={[0.5, 1.5]} tick={{ fontSize: 10 }}>
          <Label value="Z = PV/nRT" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 11, fill: '#64748b' }} />
        </YAxis>
        <Tooltip formatter={(v) => [Number(v).toFixed(3)]} labelFormatter={(p) => `P = ${p} kPa`} />
        <Legend wrapperStyle={{ fontSize: 10 }} />
        <Line type="monotone" dataKey="zIdeal" stroke="#94a3b8" strokeWidth={1.5} dot={false} strokeDasharray="5 4" name="Ideal (Z=1)" />
        <Line type="monotone" dataKey="z" stroke="#ef4444" strokeWidth={2} dot={false} name={`${selectedGas} (real)`} />
      </LineChart>
    </ResponsiveContainer>
  );
}
