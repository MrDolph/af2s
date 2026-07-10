#!/bin/bash
# ============================================================
# A-Factor STEM Studio — source files only
# Run inside af2s/ folder: bash patch-src.sh
# ============================================================
set -e
echo "✍️  Writing A-Factor STEM Studio source files..."

# Create folders
mkdir -p src/app/api/ai
mkdir -p src/components/ai
mkdir -p src/components/simulation
mkdir -p src/components/ui
mkdir -p src/components/layout
mkdir -p src/lib/physics
mkdir -p src/lib/ai
mkdir -p src/lib/utils
mkdir -p src/store
mkdir -p src/types
mkdir -p src/hooks
mkdir -p src/constants

# --- src/types/simulation.ts ---
cat > src/types/simulation.ts << 'EOF'
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
EOF

# --- src/types/ai.ts ---
cat > src/types/ai.ts << 'EOF'
import type { SimulationType, SimulationParams } from './simulation';

export interface AIPromptRequest {
  prompt: string;
  language?: 'en' | 'yo' | 'ha' | 'ig' | 'fr' | 'ar';
}

export interface AIPromptResponse {
  simulationType: SimulationType;
  title: string;
  description: string;
  params: SimulationParams;
  explanation: string;
  suggestedFollowUps: string[];
}

export interface ConversationMessage {
  role: 'user' | 'assistant';
  content: string;
}
EOF

# --- src/constants/physics.ts ---
cat > src/constants/physics.ts << 'EOF'
export const PHYSICS_CONSTANTS = {
  GRAVITY: 9.81,
  AIR_DENSITY: 1.225,
  CANVAS_SCALE: 50,
} as const;

export const SIMULATION_TOPICS = {
  projectile_motion: {
    label: 'Projectile motion',
    defaultParams: { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 },
    paramLabels: {
      initialVelocity: { label: 'Initial velocity', unit: 'm/s', min: 1, max: 100 },
      angle: { label: 'Launch angle', unit: '°', min: 1, max: 89 },
      gravity: { label: 'Gravity', unit: 'm/s²', min: 1, max: 25 },
      mass: { label: 'Mass', unit: 'kg', min: 0.1, max: 100 },
    },
  },
  newtons_second_law: {
    label: "Newton's second law",
    defaultParams: { mass: 5, force: 20, friction: 0.1 },
    paramLabels: {
      mass: { label: 'Mass', unit: 'kg', min: 0.5, max: 50 },
      force: { label: 'Applied force', unit: 'N', min: 1, max: 200 },
      friction: { label: 'Friction coefficient', unit: '', min: 0, max: 1 },
    },
  },
} as const;

export const WAEC_TOPICS = [
  'Projectile motion',
  "Newton's laws of motion",
  'Simple harmonic motion',
  "Ohm's law and circuits",
  'Refraction and lenses',
  'Wave interference',
] as const;
EOF

# --- src/lib/utils/cn.ts ---
cat > src/lib/utils/cn.ts << 'EOF'
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}
EOF

# --- src/lib/utils/format.ts ---
cat > src/lib/utils/format.ts << 'EOF'
export function formatNumber(value: number, decimals = 2): string {
  return Number(value.toFixed(decimals)).toString();
}
export function formatTime(seconds: number): string {
  return `${formatNumber(seconds, 1)}s`;
}
export function degreesToRadians(degrees: number): number {
  return (degrees * Math.PI) / 180;
}
export function radiansToDegrees(radians: number): number {
  return (radians * 180) / Math.PI;
}
EOF

# --- src/lib/physics/projectile.ts ---
cat > src/lib/physics/projectile.ts << 'EOF'
import { degreesToRadians } from '@/lib/utils/format';
import type { ProjectileParams, GraphDataPoint } from '@/types/simulation';

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
EOF

# --- src/lib/ai/parse-prompt.ts ---
cat > src/lib/ai/parse-prompt.ts << 'EOF'
import Anthropic from '@anthropic-ai/sdk';
import type { AIPromptRequest, AIPromptResponse } from '@/types/ai';

const client = new Anthropic();

const SYSTEM_PROMPT = `You are the AI engine for A-Factor STEM Studio, a STEM simulation platform for African secondary schools (WAEC/NECO/JAMB curriculum).

When a user describes a physics concept or asks to simulate something, extract the simulation parameters and return a JSON object ONLY — no markdown, no explanation outside the JSON.

Supported simulation types: projectile_motion, newtons_second_law, circular_motion, simple_harmonic_motion, ohms_law, simple_circuit

Return this exact JSON shape:
{
  "simulationType": "<type>",
  "title": "<short title>",
  "description": "<one sentence>",
  "params": {},
  "explanation": "<2-3 sentence plain English explanation>",
  "suggestedFollowUps": ["<q1>", "<q2>", "<q3>"]
}

For projectile_motion params: initialVelocity (m/s), angle (degrees), gravity (m/s², default 9.81), mass (kg, default 1)
For newtons_second_law params: mass (kg), force (N), friction (0-1)

If the user writes in Yoruba, Hausa, or Igbo, respond with explanation in that language but keep JSON keys in English.`;

export async function parseSimulationPrompt(request: AIPromptRequest): Promise<AIPromptResponse> {
  const message = await client.messages.create({
    model: 'claude-sonnet-4-6',
    max_tokens: 1024,
    system: SYSTEM_PROMPT,
    messages: [{ role: 'user', content: request.prompt }],
  });
  const content = message.content[0];
  if (content.type !== 'text') throw new Error('Unexpected response type');
  const cleaned = content.text.replace(/```json|```/g, '').trim();
  return JSON.parse(cleaned) as AIPromptResponse;
}
EOF

# --- src/store/simulation-store.ts ---
cat > src/store/simulation-store.ts << 'EOF'
import { create } from 'zustand';
import type { SimulationScene, SimulationState, GraphDataPoint } from '@/types/simulation';

interface SimulationStore extends SimulationState {
  setScene: (scene: SimulationScene) => void;
  setRunning: (running: boolean) => void;
  setPaused: (paused: boolean) => void;
  updateElapsedTime: (time: number) => void;
  setGraphData: (data: GraphDataPoint[]) => void;
  reset: () => void;
}

const initialState: SimulationState = {
  isRunning: false, isPaused: false, elapsedTime: 0, graphData: [], currentScene: null,
};

export const useSimulationStore = create<SimulationStore>((set) => ({
  ...initialState,
  setScene: (scene) => set({ currentScene: scene, isRunning: false, elapsedTime: 0, graphData: [] }),
  setRunning: (isRunning) => set({ isRunning }),
  setPaused: (isPaused) => set({ isPaused }),
  updateElapsedTime: (elapsedTime) => set({ elapsedTime }),
  setGraphData: (graphData) => set({ graphData }),
  reset: () => set(initialState),
}));
EOF

# --- src/hooks/use-simulation.ts ---
cat > src/hooks/use-simulation.ts << 'EOF'
import { useCallback } from 'react';
import { useSimulationStore } from '@/store/simulation-store';
import type { AIPromptResponse } from '@/types/ai';
import type { SimulationScene } from '@/types/simulation';

export function useSimulation() {
  const store = useSimulationStore();

  const loadFromAIResponse = useCallback((response: AIPromptResponse) => {
    const scene: SimulationScene = {
      id: crypto.randomUUID(),
      type: response.simulationType,
      title: response.title,
      description: response.description,
      params: response.params,
      createdAt: new Date().toISOString(),
    };
    store.setScene(scene);
  }, [store]);

  return {
    scene: store.currentScene,
    isRunning: store.isRunning,
    isPaused: store.isPaused,
    elapsedTime: store.elapsedTime,
    graphData: store.graphData,
    loadFromAIResponse,
    start: useCallback(() => { store.setRunning(true); store.setPaused(false); }, [store]),
    pause: useCallback(() => { store.setPaused(!store.isPaused); }, [store]),
    reset: useCallback(() => { store.reset(); }, [store]),
  };
}
EOF

# --- src/components/ai/PromptBar.tsx ---
cat > src/components/ai/PromptBar.tsx << 'EOF'
'use client';
import { useState } from 'react';
import type { AIPromptResponse } from '@/types/ai';

interface PromptBarProps { onResult: (r: AIPromptResponse) => void; className?: string; }

const EXAMPLE_PROMPTS = [
  'Show projectile motion at 45° and 30 m/s',
  "Demonstrate Newton's second law with 10 kg and 50 N",
  'Ṣe afihan projectile ti o bẹrẹ ni 20 m/s',
];

export function PromptBar({ onResult, className }: PromptBarProps) {
  const [prompt, setPrompt] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleSubmit = async (text: string) => {
    if (!text.trim() || isLoading) return;
    setIsLoading(true); setError(null);
    try {
      const res = await fetch('/api/ai', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt: text }),
      });
      if (!res.ok) { const d = await res.json(); throw new Error(d.error || 'Error'); }
      onResult(await res.json());
      setPrompt('');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to generate simulation');
    } finally { setIsLoading(false); }
  };

  return (
    <div className={className}>
      <div className="flex gap-2">
        <input
          type="text" value={prompt}
          onChange={e => setPrompt(e.target.value)}
          onKeyDown={e => e.key === 'Enter' && handleSubmit(prompt)}
          placeholder="Describe what you want to simulate…"
          disabled={isLoading}
          className="flex-1 rounded-lg border border-gray-200 bg-white px-4 py-3 text-sm outline-none focus:border-indigo-400 focus:ring-2 focus:ring-indigo-100 disabled:opacity-50"
        />
        <button
          onClick={() => handleSubmit(prompt)}
          disabled={!prompt.trim() || isLoading}
          className="rounded-lg bg-indigo-600 px-5 py-3 text-sm font-medium text-white transition hover:bg-indigo-700 disabled:opacity-40"
        >
          {isLoading ? 'Generating…' : 'Generate'}
        </button>
      </div>
      {error && <p className="text-sm text-red-600 mt-2">{error}</p>}
      <div className="flex flex-wrap gap-2 mt-3">
        {EXAMPLE_PROMPTS.map(p => (
          <button key={p} onClick={() => handleSubmit(p)} disabled={isLoading}
            className="rounded-full border border-gray-200 bg-gray-50 px-3 py-1 text-xs text-gray-600 transition hover:border-indigo-300 hover:text-indigo-700 disabled:opacity-40">
            {p}
          </button>
        ))}
      </div>
    </div>
  );
}
EOF

# --- src/components/simulation/SimulationControls.tsx ---
cat > src/components/simulation/SimulationControls.tsx << 'EOF'
'use client';
interface SimulationControlsProps { isRunning: boolean; isPaused: boolean; onRun: () => void; onPause: () => void; onReset: () => void; }
export function SimulationControls({ isRunning, isPaused, onRun, onPause, onReset }: SimulationControlsProps) {
  return (
    <div className="flex items-center gap-2">
      {!isRunning ? (
        <button onClick={onRun} className="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white hover:bg-indigo-700">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><path d="M3 2.5l8 4.5-8 4.5V2.5z"/></svg>
          Run
        </button>
      ) : (
        <button onClick={onPause} className="flex items-center gap-2 rounded-lg bg-amber-500 px-5 py-2.5 text-sm font-medium text-white hover:bg-amber-600">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><rect x="2" y="2" width="4" height="10" rx="1"/><rect x="8" y="2" width="4" height="10" rx="1"/></svg>
          {isPaused ? 'Resume' : 'Pause'}
        </button>
      )}
      <button onClick={onReset} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-5 py-2.5 text-sm font-medium text-gray-600 hover:bg-gray-50">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 7a5 5 0 1 0 1-3H2V2"/></svg>
        Reset
      </button>
    </div>
  );
}
EOF

# --- src/components/simulation/SimulationStats.tsx ---
cat > src/components/simulation/SimulationStats.tsx << 'EOF'
'use client';
import { getProjectileAnalytics } from '@/lib/physics/projectile';
import type { ProjectileParams } from '@/lib/physics/projectile';

function StatCard({ label, value, unit, color = 'text-indigo-600' }: { label: string; value: string; unit: string; color?: string }) {
  return (
    <div className="flex flex-col items-center rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
      <span className="text-xs text-gray-400 mb-1">{label}</span>
      <span className={`text-lg font-semibold ${color}`}>{value}</span>
      <span className="text-xs text-gray-400">{unit}</span>
    </div>
  );
}

export function SimulationStats({ params, elapsedTime, currentHeight, currentSpeed }: { params: ProjectileParams; elapsedTime?: number; currentHeight?: number; currentSpeed?: number }) {
  const { timeOfFlight, maxRange, maxHeight } = getProjectileAnalytics(params);
  return (
    <div className="space-y-3">
      <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Calculated values</p>
      <div className="grid grid-cols-3 gap-3">
        <StatCard label="Time of flight" value={String(timeOfFlight)} unit="seconds" />
        <StatCard label="Max range" value={String(maxRange)} unit="metres" color="text-emerald-600" />
        <StatCard label="Max height" value={String(maxHeight)} unit="metres" color="text-amber-600" />
      </div>
      {elapsedTime !== undefined && elapsedTime > 0 && (
        <>
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400 pt-1">Live values</p>
          <div className="grid grid-cols-3 gap-3">
            <StatCard label="Elapsed" value={elapsedTime.toFixed(2)} unit="seconds" color="text-gray-700" />
            <StatCard label="Altitude" value={(currentHeight ?? 0).toFixed(1)} unit="metres" color="text-blue-600" />
            <StatCard label="Speed" value={(currentSpeed ?? 0).toFixed(1)} unit="m/s" color="text-rose-500" />
          </div>
        </>
      )}
    </div>
  );
}
EOF

# --- src/components/simulation/ParamControls.tsx ---
cat > src/components/simulation/ParamControls.tsx << 'EOF'
'use client';
import type { ProjectileParams } from '@/lib/physics/projectile';

function Slider({ label, unit, value, min, max, step = 0.5, onChange, disabled, color = '#6366f1' }: { label: string; unit: string; value: number; min: number; max: number; step?: number; onChange: (v: number) => void; disabled?: boolean; color?: string }) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-500">{label}</span>
        <span className="text-xs font-medium text-gray-800 tabular-nums">{value} <span className="text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} disabled={disabled}
        onChange={e => onChange(Number(e.target.value))}
        className="w-full disabled:opacity-40" style={{ accentColor: color }} />
      <div className="flex justify-between text-[10px] text-gray-300"><span>{min}{unit}</span><span>{max}{unit}</span></div>
    </div>
  );
}

export function ParamControls({ params, onChange, disabled }: { params: ProjectileParams; onChange: (p: ProjectileParams) => void; disabled?: boolean }) {
  const update = (key: keyof ProjectileParams) => (value: number) => onChange({ ...params, [key]: value });
  return (
    <div className="space-y-4 rounded-xl border border-gray-100 bg-gray-50 p-4">
      <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Adjust parameters</p>
      <Slider label="Initial velocity" unit="m/s" value={params.initialVelocity} min={1} max={100} step={1} onChange={update('initialVelocity')} disabled={disabled} color="#6366f1" />
      <Slider label="Launch angle" unit="°" value={params.angle} min={1} max={89} step={1} onChange={update('angle')} disabled={disabled} color="#f59e0b" />
      <Slider label="Gravity" unit="m/s²" value={params.gravity} min={1} max={25} step={0.1} onChange={update('gravity')} disabled={disabled} color="#10b981" />
      <Slider label="Mass" unit="kg" value={params.mass} min={0.1} max={100} step={0.1} onChange={update('mass')} disabled={disabled} color="#8b5cf6" />
      {disabled && <p className="text-xs text-gray-400 italic text-center">Reset to adjust parameters</p>}
    </div>
  );
}
EOF

# --- src/components/simulation/ProjectileCanvas.tsx ---
cat > src/components/simulation/ProjectileCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useCallback } from 'react';
import { getInitialProjectileState, stepProjectile, getProjectileAnalytics, generateTrajectoryPath } from '@/lib/physics/projectile';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

interface ProjectileCanvasProps { params: ProjectileParams; isRunning: boolean; isPaused: boolean; onTick?: (s: ProjectileState) => void; onComplete?: (path: GraphDataPoint[]) => void; width?: number; height?: number; }

const GROUND_HEIGHT = 48, PADDING = 48, DT = 0.016, BALL_RADIUS = 8;

function getScale(cW: number, cH: number, maxR: number, maxH: number) {
  return Math.min((cW - PADDING * 2) / (maxR * 1.1), (cH - GROUND_HEIGHT - PADDING * 2) / (maxH * 1.2));
}
function toCanvas(x: number, y: number, scale: number, cH: number): [number, number] {
  return [PADDING + x * scale, cH - GROUND_HEIGHT - y * scale];
}
function drawBackground(ctx: CanvasRenderingContext2D, w: number, h: number) {
  const sky = ctx.createLinearGradient(0, 0, 0, h - GROUND_HEIGHT);
  sky.addColorStop(0, '#dbeafe'); sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky; ctx.fillRect(0, 0, w, h - GROUND_HEIGHT);
  ctx.fillStyle = '#e2e8f0'; ctx.fillRect(0, h - GROUND_HEIGHT, w, GROUND_HEIGHT);
  ctx.beginPath(); ctx.moveTo(0, h - GROUND_HEIGHT); ctx.lineTo(w, h - GROUND_HEIGHT);
  ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2; ctx.stroke();
}
function drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number, scale: number, maxR: number, maxH: number) {
  ctx.save();
  ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1; ctx.fillStyle = '#94a3b8'; ctx.font = '11px system-ui';
  const xStep = Math.ceil(maxR / 6 / 5) * 5 || 1;
  ctx.textAlign = 'center';
  for (let x = 0; x <= maxR * 1.1; x += xStep) {
    const [cx] = toCanvas(x, 0, scale, h);
    ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(cx, PADDING); ctx.lineTo(cx, h - GROUND_HEIGHT); ctx.stroke();
    ctx.setLineDash([]); ctx.fillText(`${x}m`, cx, h - GROUND_HEIGHT + 16);
  }
  ctx.textAlign = 'right';
  const yStep = Math.ceil(maxH / 4 / 5) * 5 || 1;
  for (let y = 0; y <= maxH * 1.2; y += yStep) {
    const [, cy] = toCanvas(0, y, scale, h);
    if (cy < PADDING) continue;
    ctx.beginPath(); ctx.setLineDash([3, 4]); ctx.moveTo(PADDING, cy); ctx.lineTo(w - PADDING, cy); ctx.stroke();
    ctx.setLineDash([]); ctx.fillText(`${y}m`, PADDING - 6, cy + 4);
  }
  ctx.restore();
}
function drawGhostTrajectory(ctx: CanvasRenderingContext2D, path: GraphDataPoint[], scale: number, h: number) {
  if (path.length < 2) return;
  ctx.save(); ctx.beginPath();
  const [x0, y0] = toCanvas(path[0].x, path[0].y, scale, h); ctx.moveTo(x0, y0);
  path.slice(1).forEach(p => { const [cx, cy] = toCanvas(p.x, p.y, scale, h); ctx.lineTo(cx, cy); });
  ctx.strokeStyle = 'rgba(99,102,241,0.15)'; ctx.lineWidth = 2; ctx.setLineDash([6, 4]); ctx.stroke();
  ctx.setLineDash([]); ctx.restore();
}
function drawLiveTrail(ctx: CanvasRenderingContext2D, trail: [number, number][]) {
  if (trail.length < 2) return;
  ctx.save();
  for (let i = 1; i < trail.length; i++) {
    const alpha = i / trail.length;
    ctx.beginPath(); ctx.moveTo(trail[i-1][0], trail[i-1][1]); ctx.lineTo(trail[i][0], trail[i][1]);
    ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`; ctx.lineWidth = 2.5; ctx.stroke();
  }
  ctx.restore();
}
function drawBall(ctx: CanvasRenderingContext2D, cx: number, cy: number, cH: number) {
  ctx.save();
  ctx.beginPath(); ctx.ellipse(cx, cH - GROUND_HEIGHT + 6, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.12)'; ctx.fill();
  const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, BALL_RADIUS * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS * 2.5, 0, Math.PI * 2); ctx.fillStyle = glow; ctx.fill();
  const ball = ctx.createRadialGradient(cx - 2, cy - 2, 1, cx, cy, BALL_RADIUS);
  ball.addColorStop(0, '#818cf8'); ball.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS, 0, Math.PI * 2); ctx.fillStyle = ball; ctx.fill();
  ctx.restore();
}
function drawVelocityVector(ctx: CanvasRenderingContext2D, cx: number, cy: number, vx: number, vy: number, scale: number) {
  const speed = Math.sqrt(vx * vx + vy * vy);
  if (speed < 0.5) return;
  const len = Math.min(speed * scale * 0.25, 60), angle = Math.atan2(-vy, vx);
  const ex = cx + Math.cos(angle) * len, ey = cy + Math.sin(angle) * len;
  ctx.save();
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(ex, ey);
  ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2; ctx.stroke();
  const hL = 8, hA = 0.4;
  ctx.beginPath(); ctx.moveTo(ex, ey);
  ctx.lineTo(ex - hL * Math.cos(angle - hA), ey - hL * Math.sin(angle - hA));
  ctx.lineTo(ex - hL * Math.cos(angle + hA), ey - hL * Math.sin(angle + hA));
  ctx.closePath(); ctx.fillStyle = '#f59e0b'; ctx.fill();
  ctx.restore();
}
function drawHUD(ctx: CanvasRenderingContext2D, state: ProjectileState, w: number) {
  const speed = Math.sqrt(state.vx ** 2 + state.vy ** 2);
  const lines = [`t = ${state.time.toFixed(2)}s`, `v = ${speed.toFixed(1)} m/s`, `h = ${Math.max(0, state.y).toFixed(1)}m`, `x = ${state.x.toFixed(1)}m`];
  const bx = w - 122, by = 12, bW = 110, bH = lines.length * 18 + 14;
  ctx.save();
  ctx.fillStyle = 'rgba(255,255,255,0.85)';
  ctx.beginPath(); ctx.roundRect(bx, by, bW, bH, 8); ctx.fill();
  ctx.strokeStyle = 'rgba(99,102,241,0.2)'; ctx.lineWidth = 1; ctx.stroke();
  ctx.fillStyle = '#1e293b'; ctx.font = '12px monospace'; ctx.textAlign = 'left';
  lines.forEach((l, i) => ctx.fillText(l, bx + 10, by + 20 + i * 18));
  ctx.restore();
}
function drawPeakMarker(ctx: CanvasRenderingContext2D, px: number, py: number, maxH: number, h: number) {
  ctx.save();
  ctx.beginPath(); ctx.setLineDash([4, 3]); ctx.moveTo(px, py); ctx.lineTo(px, h - GROUND_HEIGHT);
  ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
  ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${maxH.toFixed(1)}m`, px, py - 10); ctx.restore();
}
function drawLandingMarker(ctx: CanvasRenderingContext2D, lx: number, h: number, range: number) {
  ctx.save();
  ctx.beginPath(); ctx.arc(lx, h - GROUND_HEIGHT, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#10b981'; ctx.fill();
  ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${range.toFixed(1)}m`, lx, h - GROUND_HEIGHT + 32); ctx.restore();
}

export function ProjectileCanvas({ params, isRunning, isPaused, onTick, onComplete, width = 720, height = 380 }: ProjectileCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const stateRef = useRef<ProjectileState>(getInitialProjectileState(params));
  const trailRef = useRef<[number, number][]>([]);
  const completedRef = useRef(false);

  const analytics = getProjectileAnalytics(params);
  const fullPath = generateTrajectoryPath(params);
  const scale = getScale(width, height, analytics.maxRange, analytics.maxHeight);

  const draw = useCallback((state: ProjectileState) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const w = canvas.width, h = canvas.height;
    ctx.clearRect(0, 0, w, h);
    drawBackground(ctx, w, h);
    drawGrid(ctx, w, h, scale, analytics.maxRange, analytics.maxHeight);
    drawGhostTrajectory(ctx, fullPath, scale, h);
    const [pCx, pCy] = toCanvas(analytics.maxRange / 2, analytics.maxHeight, scale, h);
    drawPeakMarker(ctx, pCx, pCy, analytics.maxHeight, h);
    const [lCx] = toCanvas(analytics.maxRange, 0, scale, h);
    drawLandingMarker(ctx, lCx, h, analytics.maxRange);
    drawLiveTrail(ctx, trailRef.current);
    const [cx, cy] = toCanvas(state.x, Math.max(0, state.y), scale, h);
    drawBall(ctx, cx, cy, h);
    drawVelocityVector(ctx, cx, cy, state.vx, state.vy, scale);
    if (isRunning || state.time > 0) drawHUD(ctx, state, w);
  }, [scale, analytics, fullPath, isRunning]);

  useEffect(() => {
    cancelAnimationFrame(rafRef.current);
    stateRef.current = getInitialProjectileState(params);
    trailRef.current = []; completedRef.current = false;
    draw(stateRef.current);
  }, [params, draw]);

  useEffect(() => {
    if (!isRunning || isPaused || completedRef.current) return;
    let lastTime: number | null = null;
    const loop = (timestamp: number) => {
      if (lastTime === null) lastTime = timestamp;
      const elapsed = (timestamp - lastTime) / 1000; lastTime = timestamp;
      const steps = Math.ceil(elapsed / DT);
      for (let i = 0; i < steps; i++) {
        stateRef.current = stepProjectile(stateRef.current, params, DT);
        const [cx, cy] = toCanvas(stateRef.current.x, Math.max(0, stateRef.current.y), scale, height);
        trailRef.current.push([cx, cy]);
        if (trailRef.current.length > 120) trailRef.current.shift();
        if (stateRef.current.y < 0 || stateRef.current.time > 100) {
          completedRef.current = true; onComplete?.(fullPath); draw(stateRef.current); return;
        }
      }
      onTick?.(stateRef.current); draw(stateRef.current);
      rafRef.current = requestAnimationFrame(loop);
    };
    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  }, [isRunning, isPaused, params, scale, height, fullPath, draw, onTick, onComplete]);

  return (
    <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
      <canvas ref={canvasRef} width={width} height={height} className="w-full" style={{ display: 'block' }} />
      {!isRunning && stateRef.current.time === 0 && (
        <div className="absolute inset-0 flex items-center justify-center bg-white/60 backdrop-blur-[2px]">
          <p className="text-sm font-medium text-gray-400">Press <span className="rounded bg-gray-100 px-2 py-0.5 font-mono text-xs">Run</span> to launch</p>
        </div>
      )}
    </div>
  );
}
EOF

# --- src/app/api/ai/route.ts ---
cat > src/app/api/ai/route.ts << 'EOF'
import { NextRequest, NextResponse } from 'next/server';
import { parseSimulationPrompt } from '@/lib/ai/parse-prompt';
import type { AIPromptRequest } from '@/types/ai';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as AIPromptRequest;
    if (!body.prompt || typeof body.prompt !== 'string')
      return NextResponse.json({ error: 'Prompt is required' }, { status: 400 });
    if (body.prompt.length > 500)
      return NextResponse.json({ error: 'Prompt too long' }, { status: 400 });
    const result = await parseSimulationPrompt(body);
    return NextResponse.json(result);
  } catch (error) {
    console.error('[AI Route Error]', error);
    return NextResponse.json({ error: 'Failed to process prompt.' }, { status: 500 });
  }
}
EOF

# --- src/app/page.tsx ---
cat > src/app/page.tsx << 'EOF'
'use client';
import { useState, useCallback } from 'react';
import { PromptBar } from '@/components/ai/PromptBar';
import { ProjectileCanvas } from '@/components/simulation/ProjectileCanvas';
import { SimulationStats } from '@/components/simulation/SimulationStats';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ParamControls } from '@/components/simulation/ParamControls';
import type { AIPromptResponse } from '@/types/ai';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

const DEFAULT_PARAMS: ProjectileParams = { initialVelocity: 20, angle: 45, gravity: 9.81, mass: 1 };

export default function HomePage() {
  const [params, setParams] = useState<ProjectileParams>(DEFAULT_PARAMS);
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [liveState, setLiveState] = useState<ProjectileState | null>(null);
  const [isComplete, setIsComplete] = useState(false);
  const [lastResponse, setLastResponse] = useState<AIPromptResponse | null>(null);

  const handleAIResult = useCallback((response: AIPromptResponse) => {
    setLastResponse(response);
    if (response.simulationType === 'projectile_motion') {
      const p = response.params as ProjectileParams;
      setParams({ initialVelocity: Number(p.initialVelocity) || 20, angle: Number(p.angle) || 45, gravity: Number(p.gravity) || 9.81, mass: Number(p.mass) || 1 });
    }
    setIsRunning(false); setIsPaused(false); setLiveState(null); setIsComplete(false);
  }, []);

  const handleRun = () => { setIsRunning(true); setIsPaused(false); setIsComplete(false); };
  const handlePause = () => setIsPaused(p => !p);
  const handleReset = () => { setIsRunning(false); setIsPaused(false); setLiveState(null); setIsComplete(false); };
  const handleParamChange = (next: ProjectileParams) => { setParams(next); handleReset(); };
  const handleTick = useCallback((s: ProjectileState) => setLiveState(s), []);
  const handleComplete = useCallback((_: GraphDataPoint[]) => { setIsRunning(false); setIsComplete(true); }, []);
  const currentSpeed = liveState ? Math.sqrt(liveState.vx ** 2 + liveState.vy ** 2) : undefined;

  return (
    <main className="min-h-screen bg-gray-50">
      <header className="border-b border-gray-200 bg-white px-6 py-4">
        <div className="mx-auto flex max-w-6xl items-center justify-between">
          <div>
            <h1 className="text-xl font-semibold text-gray-900">A-Factor</h1>
            <p className="text-xs text-gray-400">STEM Simulation Studio</p>
          </div>
          <span className="rounded-full bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600">
            Phase 1 · Projectile motion
          </span>
        </div>
      </header>
      <div className="mx-auto max-w-6xl px-6 py-8 space-y-6">
        <div className="rounded-2xl border border-gray-200 bg-white p-6 shadow-sm">
          <h2 className="mb-1 text-sm font-medium text-gray-900">Describe your simulation</h2>
          <p className="mb-4 text-xs text-gray-400">Type in English, Yoruba, Hausa, or Igbo — AI generates simulation parameters instantly.</p>
          <PromptBar onResult={handleAIResult} />
        </div>
        {lastResponse && (
          <div className="rounded-2xl border border-indigo-100 bg-indigo-50 px-6 py-4">
            <p className="text-xs font-medium text-indigo-400 mb-1 uppercase tracking-wide">{lastResponse.title}</p>
            <p className="text-sm text-indigo-800 leading-relaxed">{lastResponse.explanation}</p>
            {lastResponse.suggestedFollowUps?.length > 0 && (
              <div className="mt-3 flex flex-wrap gap-2">
                {lastResponse.suggestedFollowUps.map(q => (
                  <span key={q} className="rounded-full border border-indigo-200 bg-white px-3 py-1 text-xs text-indigo-600">{q}</span>
                ))}
              </div>
            )}
          </div>
        )}
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-[1fr_280px]">
          <div className="space-y-4">
            <ProjectileCanvas params={params} isRunning={isRunning} isPaused={isPaused} onTick={handleTick} onComplete={handleComplete} width={720} height={380} />
            <div className="flex items-center justify-between">
              <SimulationControls isRunning={isRunning} isPaused={isPaused} onRun={handleRun} onPause={handlePause} onReset={handleReset} />
              {isComplete && <span className="text-xs font-medium text-emerald-600">✓ Simulation complete</span>}
            </div>
            <SimulationStats params={params} elapsedTime={liveState?.time} currentHeight={liveState ? Math.max(0, liveState.y) : undefined} currentSpeed={currentSpeed} />
          </div>
          <div>
            <ParamControls params={params} onChange={handleParamChange} disabled={isRunning} />
          </div>
        </div>
      </div>
    </main>
  );
}
EOF

# --- .env.local ---
cat > .env.local << 'EOF'
ANTHROPIC_API_KEY=your_api_key_here
NEXT_PUBLIC_APP_NAME=A-Factor STEM Studio
NEXT_PUBLIC_APP_URL=http://localhost:3000
EOF

# --- .env.example ---
cat > .env.example << 'EOF'
ANTHROPIC_API_KEY=
NEXT_PUBLIC_APP_NAME=A-Factor STEM Studio
NEXT_PUBLIC_APP_URL=http://localhost:3000
EOF

echo ""
echo "✅ All source files written!"
echo ""
echo "Next steps:"
echo "  1. npm install @anthropic-ai/sdk zustand clsx tailwind-merge"
echo "  2. Edit .env.local — replace 'your_api_key_here' with your real key"
echo "  3. npm run dev"
echo "  4. Open http://localhost:3000"
