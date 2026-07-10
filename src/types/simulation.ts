export type SimulationType =
  | 'projectile_motion'
  | 'newtons_second_law'
  | 'circular_motion'
  | 'simple_harmonic_motion'
  | 'ohms_law'
  | 'simple_circuit';

export interface SimulationParams {
  [key: string]: number | string | boolean;
}

export interface SimulationScene {
  id: string;
  type: SimulationType;
  title: string;
  description: string;
  params: SimulationParams;
  createdAt: string;
}

export interface ProjectileParams extends SimulationParams {
  initialVelocity: number;
  angle: number;
  gravity: number;
  mass: number;
}

export interface GraphDataPoint {
  x: number;
  y: number;
  label?: string;
}

export interface SimulationState {
  isRunning: boolean;
  isPaused: boolean;
  elapsedTime: number;
  graphData: GraphDataPoint[];
  currentScene: SimulationScene | null;
}
