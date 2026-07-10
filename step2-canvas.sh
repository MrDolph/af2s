#!/bin/bash
# ============================================================
# A-Factor STEM Studio — Step 2: ProjectileCanvas patch
# Run inside your af2s/ folder: bash step2-canvas.sh
# ============================================================
set -e
echo "🎨 Adding ProjectileCanvas and simulation UI..."

mkdir -p src/components/simulation

# ── Fix: export ProjectileParams from physics file ───────────────────────────
# (replace the import line in projectile.ts)
sed -i 's/^import type { ProjectileParams, GraphDataPoint } from .*/import type { ProjectileParams, GraphDataPoint } from "@\/types\/simulation";\nexport type { ProjectileParams };/' src/lib/physics/projectile.ts

# ── SimulationStats ───────────────────────────────────────────────────────────
cat > src/components/simulation/SimulationStats.tsx << 'EOF'
'use client';
import { getProjectileAnalytics } from '@/lib/physics/projectile';
import type { ProjectileParams } from '@/lib/physics/projectile';

interface StatCardProps { label: string; value: string; unit: string; color?: string; }
function StatCard({ label, value, unit, color = 'text-indigo-600' }: StatCardProps) {
  return (
    <div className="flex flex-col items-center rounded-xl border border-gray-100 bg-gray-50 px-4 py-3">
      <span className="text-xs text-gray-400 mb-1">{label}</span>
      <span className={`text-lg font-semibold ${color}`}>{value}</span>
      <span className="text-xs text-gray-400">{unit}</span>
    </div>
  );
}
interface SimulationStatsProps { params: ProjectileParams; elapsedTime?: number; currentHeight?: number; currentSpeed?: number; }
export function SimulationStats({ params, elapsedTime, currentHeight, currentSpeed }: SimulationStatsProps) {
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

# ── SimulationControls ────────────────────────────────────────────────────────
cat > src/components/simulation/SimulationControls.tsx << 'EOF'
'use client';
interface SimulationControlsProps { isRunning: boolean; isPaused: boolean; onRun: () => void; onPause: () => void; onReset: () => void; }
export function SimulationControls({ isRunning, isPaused, onRun, onPause, onReset }: SimulationControlsProps) {
  return (
    <div className="flex items-center gap-2">
      {!isRunning ? (
        <button onClick={onRun} className="flex items-center gap-2 rounded-lg bg-indigo-600 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-indigo-700">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><path d="M3 2.5l8 4.5-8 4.5V2.5z" /></svg>
          Run
        </button>
      ) : (
        <button onClick={onPause} className="flex items-center gap-2 rounded-lg bg-amber-500 px-5 py-2.5 text-sm font-medium text-white transition hover:bg-amber-600">
          <svg width="14" height="14" viewBox="0 0 14 14" fill="currentColor"><rect x="2" y="2" width="4" height="10" rx="1" /><rect x="8" y="2" width="4" height="10" rx="1" /></svg>
          {isPaused ? 'Resume' : 'Pause'}
        </button>
      )}
      <button onClick={onReset} className="flex items-center gap-2 rounded-lg border border-gray-200 bg-white px-5 py-2.5 text-sm font-medium text-gray-600 transition hover:bg-gray-50">
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"><path d="M2 7a5 5 0 1 0 1-3H2V2" /></svg>
        Reset
      </button>
    </div>
  );
}
EOF

# ── ParamControls ─────────────────────────────────────────────────────────────
cat > src/components/simulation/ParamControls.tsx << 'EOF'
'use client';
import type { ProjectileParams } from '@/lib/physics/projectile';
interface SliderProps { label: string; unit: string; value: number; min: number; max: number; step?: number; onChange: (v: number) => void; disabled?: boolean; color?: string; }
function Slider({ label, unit, value, min, max, step = 0.5, onChange, disabled, color = '#6366f1' }: SliderProps) {
  return (
    <div className="space-y-1.5">
      <div className="flex items-center justify-between">
        <span className="text-xs text-gray-500">{label}</span>
        <span className="text-xs font-medium text-gray-800 tabular-nums">{value} <span className="text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value} disabled={disabled} onChange={e => onChange(Number(e.target.value))} className="w-full disabled:opacity-40" style={{ accentColor: color }} />
      <div className="flex justify-between text-[10px] text-gray-300"><span>{min}{unit}</span><span>{max}{unit}</span></div>
    </div>
  );
}
interface ParamControlsProps { params: ProjectileParams; onChange: (p: ProjectileParams) => void; disabled?: boolean; }
export function ParamControls({ params, onChange, disabled }: ParamControlsProps) {
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

# ── ProjectileCanvas (full file) ──────────────────────────────────────────────
cat > src/components/simulation/ProjectileCanvas.tsx << 'EOF'
'use client';
import { useEffect, useRef, useCallback } from 'react';
import { getInitialProjectileState, stepProjectile, getProjectileAnalytics, generateTrajectoryPath } from '@/lib/physics/projectile';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

interface ProjectileCanvasProps { params: ProjectileParams; isRunning: boolean; isPaused: boolean; onTick?: (s: ProjectileState) => void; onComplete?: (path: GraphDataPoint[]) => void; width?: number; height?: number; }

const GROUND_HEIGHT = 48;
const PADDING = 48;
const DT = 0.016;
const BALL_RADIUS = 8;

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
  ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
  ctx.fillStyle = '#94a3b8'; ctx.font = '11px system-ui, sans-serif';
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
  ctx.save();
  ctx.beginPath();
  const [x0, y0] = toCanvas(path[0].x, path[0].y, scale, h);
  ctx.moveTo(x0, y0);
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
  ctx.beginPath();
  ctx.ellipse(cx, cH - GROUND_HEIGHT + 6, 10, 4, 0, 0, Math.PI * 2);
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
  const arrowLen = Math.min(speed * scale * 0.25, 60);
  const angle = Math.atan2(-vy, vx);
  const ex = cx + Math.cos(angle) * arrowLen;
  const ey = cy + Math.sin(angle) * arrowLen;
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
  ctx.fillText(`${maxH.toFixed(1)}m`, px, py - 10);
  ctx.restore();
}

function drawLandingMarker(ctx: CanvasRenderingContext2D, lx: number, h: number, range: number) {
  ctx.save();
  ctx.beginPath(); ctx.arc(lx, h - GROUND_HEIGHT, 5, 0, Math.PI * 2);
  ctx.fillStyle = '#10b981'; ctx.fill();
  ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
  ctx.fillText(`${range.toFixed(1)}m`, lx, h - GROUND_HEIGHT + 32);
  ctx.restore();
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
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
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
    trailRef.current = [];
    completedRef.current = false;
    draw(stateRef.current);
  }, [params, draw]);

  useEffect(() => {
    if (!isRunning || isPaused || completedRef.current) return;
    let lastTime: number | null = null;
    const loop = (timestamp: number) => {
      if (lastTime === null) lastTime = timestamp;
      const elapsed = (timestamp - lastTime) / 1000;
      lastTime = timestamp;
      const steps = Math.ceil(elapsed / DT);
      for (let i = 0; i < steps; i++) {
        stateRef.current = stepProjectile(stateRef.current, params, DT);
        const [cx, cy] = toCanvas(stateRef.current.x, Math.max(0, stateRef.current.y), scale, height);
        trailRef.current.push([cx, cy]);
        if (trailRef.current.length > 120) trailRef.current.shift();
        if (stateRef.current.y < 0 || stateRef.current.time > 100) {
          completedRef.current = true;
          onComplete?.(fullPath);
          draw(stateRef.current);
          return;
        }
      }
      onTick?.(stateRef.current);
      draw(stateRef.current);
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

# ── Updated page.tsx ──────────────────────────────────────────────────────────
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
          <span className="rounded-full bg-indigo-50 px-3 py-1 text-xs font-medium text-indigo-600">Phase 1 · Projectile motion</span>
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
                {lastResponse.suggestedFollowUps.map(q => <span key={q} className="rounded-full border border-indigo-200 bg-white px-3 py-1 text-xs text-indigo-600">{q}</span>)}
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

echo ""
echo "✅ Step 2 complete! New files added:"
echo "   src/components/simulation/ProjectileCanvas.tsx"
echo "   src/components/simulation/SimulationStats.tsx"
echo "   src/components/simulation/SimulationControls.tsx"
echo "   src/components/simulation/ParamControls.tsx"
echo "   src/app/page.tsx  (updated)"
echo ""
echo "Run: npm run dev → http://localhost:3000"
