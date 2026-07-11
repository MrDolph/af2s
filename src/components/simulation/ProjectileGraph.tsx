'use client';
import {
  LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip,
  ReferenceDot, ResponsiveContainer, Label, Legend,
} from 'recharts';
import { generateTrajectoryPath, getProjectileAnalytics } from '@/lib/physics/projectile';
import type { ProjectileParams } from '@/lib/physics/projectile';

type GraphType = 'trajectory' | 'height-time' | 'velocity-time';

interface ProjectileGraphProps {
  params: ProjectileParams;
  graphType: GraphType;
  elapsedTime?: number;
  currentHeight?: number;
  currentSpeed?: number;
  currentVx?: number;
  currentVy?: number;
}

export function ProjectileGraph({
  params, graphType, elapsedTime = 0, currentHeight = 0,
  currentSpeed = 0, currentVx = 0, currentVy = 0,
}: ProjectileGraphProps) {
  const analytics = getProjectileAnalytics(params);
  const path = generateTrajectoryPath(params);

  if (graphType === 'trajectory') {
    const data = path.map(p => ({ x: +p.x.toFixed(2), y: +p.y.toFixed(2) }));
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="x" type="number" domain={[0, analytics.maxRange * 1.05]} tick={{ fontSize: 10 }}>
            <Label value="Horizontal distance (m)" position="insideBottom" offset={-18} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Height (m)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [`${Number(v).toFixed(2)} m`, 'Height']} labelFormatter={v => `Distance: ${Number(v).toFixed(2)} m`} />
          <Line type="monotone" dataKey="y" stroke="#6366f1" strokeWidth={2} dot={false} name="Height" />
          {elapsedTime > 0 && (
            <ReferenceDot x={+path.find(p => p.y >= 0 && p.x <= (elapsedTime * params.initialVelocity * Math.cos(params.angle * Math.PI / 180)))?.x?.toFixed(2) ?? 0}
              y={+Math.max(0, currentHeight).toFixed(2)} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
          )}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  if (graphType === 'height-time') {
    const dt = analytics.timeOfFlight / 80;
    const data = Array.from({ length: 81 }, (_, i) => {
      const t = i * dt;
      const vy0 = params.initialVelocity * Math.sin(params.angle * Math.PI / 180);
      const h = Math.max(0, vy0 * t - 0.5 * params.gravity * t * t);
      return { t: +t.toFixed(2), h: +h.toFixed(2) };
    });
    return (
      <ResponsiveContainer width="100%" height={200}>
        <LineChart data={data} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
          <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
          <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
            <Label value="Time (s)" position="insideBottom" offset={-18} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </XAxis>
          <YAxis tick={{ fontSize: 10 }}>
            <Label value="Height (m)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 10, fill: '#94a3b8' }} />
          </YAxis>
          <Tooltip formatter={(v: unknown) => [`${Number(v).toFixed(2)} m`, 'Height']} labelFormatter={v => `t = ${v}s`} />
          <Line type="monotone" dataKey="h" stroke="#10b981" strokeWidth={2} dot={false} />
          {elapsedTime > 0 && (
            <ReferenceDot x={+elapsedTime.toFixed(2)} y={+Math.max(0, currentHeight).toFixed(2)} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
          )}
        </LineChart>
      </ResponsiveContainer>
    );
  }

  // velocity-time
  const dt2 = analytics.timeOfFlight / 80;
  const vy0 = params.initialVelocity * Math.sin(params.angle * Math.PI / 180);
  const vx0 = params.initialVelocity * Math.cos(params.angle * Math.PI / 180);
  const data2 = Array.from({ length: 81 }, (_, i) => {
    const t = i * dt2;
    const vy = vy0 - params.gravity * t;
    const speed = Math.sqrt(vx0 * vx0 + vy * vy);
    return { t: +t.toFixed(2), speed: +speed.toFixed(2), vx: +vx0.toFixed(2), vy: +vy.toFixed(2) };
  });

  return (
    <ResponsiveContainer width="100%" height={200}>
      <LineChart data={data2} margin={{ top: 10, right: 20, left: 10, bottom: 30 }}>
        <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
        <XAxis dataKey="t" type="number" tick={{ fontSize: 10 }}>
          <Label value="Time (s)" position="insideBottom" offset={-18} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </XAxis>
        <YAxis tick={{ fontSize: 10 }}>
          <Label value="Velocity (m/s)" angle={-90} position="insideLeft" offset={10} style={{ fontSize: 10, fill: '#94a3b8' }} />
        </YAxis>
        <Tooltip formatter={(v: unknown) => [`${Number(v).toFixed(2)} m/s`]} labelFormatter={v => `t = ${v}s`} />
        <Legend wrapperStyle={{ fontSize: 10 }} />
        <Line type="monotone" dataKey="speed" stroke="#6366f1" strokeWidth={2} dot={false} name="|v|" />
        <Line type="monotone" dataKey="vx" stroke="#10b981" strokeWidth={1.5} dot={false} strokeDasharray="4 3" name="vx" />
        <Line type="monotone" dataKey="vy" stroke="#ef4444" strokeWidth={1.5} dot={false} strokeDasharray="4 3" name="vy" />
        {elapsedTime > 0 && (
          <ReferenceDot x={+elapsedTime.toFixed(2)} y={+currentSpeed.toFixed(2)} r={5} fill="#f59e0b" stroke="#fff" strokeWidth={2} />
        )}
      </LineChart>
    </ResponsiveContainer>
  );
}
