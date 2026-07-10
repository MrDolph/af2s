import { degreesToRadians } from '@/lib/utils/format';
import type { ProjectileParams, GraphDataPoint } from "@/types/simulation";
export type { ProjectileParams };

export type { ProjectileParams };

export interface ProjectileState {
  x: number;
  y: number;
  vx: number;
  vy: number;
  time: number;
}

export function getInitialProjectileState(params: ProjectileParams): ProjectileState {
  const angleRad = degreesToRadians(params.angle);
  return {
    x: 0, y: 0,
    vx: params.initialVelocity * Math.cos(angleRad),
    vy: params.initialVelocity * Math.sin(angleRad),
    time: 0,
  };
}

export function stepProjectile(state: ProjectileState, params: ProjectileParams, dt: number): ProjectileState {
  return {
    x: state.x + state.vx * dt,
    y: state.y + state.vy * dt - 0.5 * params.gravity * dt * dt,
    vx: state.vx,
    vy: state.vy - params.gravity * dt,
    time: state.time + dt,
  };
}

export function getProjectileAnalytics(params: ProjectileParams) {
  const a = degreesToRadians(params.angle);
  const v = params.initialVelocity, g = params.gravity;
  return {
    timeOfFlight: Number(((2 * v * Math.sin(a)) / g).toFixed(2)),
    maxRange: Number(((v * v * Math.sin(2 * a)) / g).toFixed(2)),
    maxHeight: Number(((v * v * Math.sin(a) ** 2) / (2 * g)).toFixed(2)),
  };
}

export function generateTrajectoryPath(params: ProjectileParams): GraphDataPoint[] {
  const points: GraphDataPoint[] = [];
  let state = getInitialProjectileState(params);
  const dt = 0.02;
  while (state.y >= 0 && state.time < 100) {
    points.push({ x: Number(state.x.toFixed(3)), y: Number(state.y.toFixed(3)) });
    state = stepProjectile(state, params, dt);
  }
  return points;
}
