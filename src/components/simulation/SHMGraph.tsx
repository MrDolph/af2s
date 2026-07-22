'use client';
import { useMemo } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Label, ReferenceLine, ReferenceDot } from 'recharts';
import { generateSHMData, shmDisplacement, shmVelocity, shmAcceleration, shmKE, shmPE } from '@/lib/physics/shm';

const CYCLES = 3;

type GraphMode = 'displacement' | 'velocity' | 'acceleration' | 'energy' | 'phase';

interface Props {
  A: number; omega: number; m: number; k: number;
  mode: GraphMode; currentT?: number;
}

export function SHMGraph({ A, omega, m, k, mode, currentT = 0 }: Props) {
  // Memoized — regenerating 200 points on every animation tick was wasted
  // work; the curve only changes when the physics parameters change.
  const data = useMemo(() => generateSHMData(A, omega, m, k, CYCLES), [A, omega, m, k]);

  // The graph shows exactly CYCLES periods. SHM is periodic, so wrap the
  // live time marker back onto the visible window instead of letting it
  // run off the right edge and vanish (which looked like the graph had
  // fallen out of sync with the animation).
  const totalTime = CYCLES * (2 * Math.PI) / omega;
  const markerT = currentT > 0 ? currentT % totalTime : 0;

  // Live values at the marker time — computed from the SAME closed-form
  // equations that drive both the canvas animation and the plotted curve,
  // so the moving dot sits exactly ON the curve, perfectly in sync with
  // the mass/bob, at any frame rate.
  const liveX = shmDisplacement(A, omega, markerT);
  const liveV = shmVelocity(A, omega, markerT);
  const liveA = shmAcceleration(A, omega, markerT);
  const liveKE = shmKE(m, liveV);
  const livePE = shmPE(k, liveX);

  if (mode === 'phase') {
    // Phase space: v vs x. Two things matter here:
    // 1. type="linear" (NOT "monotone") — monotone interpolation assumes x is
    //    strictly increasing; a phase ellipse doubles back on itself, the
    //    interpolator produces NaN, and Recharts silently drops the entire
    //    path (the "missing line" bug).
    // 2. One single closed period, not 3 overlapping loops — the last point
    //    is appended equal to the first so the ellipse visibly closes.
    const period = Math.floor(data.length / CYCLES) + 1;
    const phaseData = [...data.slice(0, period), data[0]];
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={phaseData} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="x" type="number" tick={{ fontSize: 10 }} domain={[-A * 1.1, A * 1.1]}>
            <Label value="Displacement x (m)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Velocity v (m/s)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(3)]} />
          <Line type="linear" dataKey="v" stroke="#6366f1" strokeWidth={2} dot={false} isAnimationActive={false} />
          <ReferenceLine x={0} stroke="#e2e8f0" />
          <ReferenceLine y={0} stroke="#e2e8f0" />
          {markerT > 0 && (
            <ReferenceDot x={liveX} y={liveV} r={6} fill="#ef4444" stroke="#fff" strokeWidth={2} />
          )}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (mode === 'energy') {
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
            <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Energy (J)" angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4), '']} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
          <Legend wrapperStyle={{ fontSize: 10 }} />
          <Line type="monotone" dataKey="ke" stroke="#f59e0b" strokeWidth={2} dot={false} name="KE" />
          <Line type="monotone" dataKey="pe" stroke="#6366f1" strokeWidth={2} dot={false} name="PE" />
          <Line type="monotone" dataKey="te" stroke="#10b981" strokeWidth={1.5} dot={false} strokeDasharray="5 3" name="Total E" />
          {markerT > 0 && <>
            <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
            <ReferenceDot x={markerT} y={liveKE} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
            <ReferenceDot x={markerT} y={livePE} r={5} fill="#6366f1" stroke="#fff" strokeWidth={2} />
          </>}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  const keyMap = { displacement: 'x', velocity: 'v', acceleration: 'a' };
  const colorMap = { displacement: '#6366f1', velocity: '#10b981', acceleration: '#f59e0b' };
  const labelMap = { displacement: 'Displacement (m)', velocity: 'Velocity (m/s)', acceleration: 'Acceleration (m/s²)' };
  const dataKey = keyMap[mode as keyof typeof keyMap];
  const color = colorMap[mode as keyof typeof colorMap];

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data} margin={{ top: 8, right: 16, left: 10, bottom: 28 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
          <Label value="Time (s)" position="insideBottom" offset={-16} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value={labelMap[mode as keyof typeof labelMap]} angle={-90} position="insideLeft" offset={12} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [Number(v).toFixed(4)]} labelFormatter={t => `t=${Number(t).toFixed(2)}s`} />
        <ReferenceLine y={0} stroke="#e2e8f0" />
        <Line type="monotone" dataKey={dataKey} stroke={color} strokeWidth={2} dot={false} />
        {markerT > 0 && <>
          <ReferenceLine x={markerT} stroke="#ef4444" strokeDasharray="3 3" />
          <ReferenceDot
            x={markerT}
            y={mode === 'displacement' ? liveX : mode === 'velocity' ? liveV : liveA}
            r={6} fill={color} stroke="#fff" strokeWidth={2} 
          />
        </>}
      </LineChart>
    </ResponsiveContainer>
  );
}
