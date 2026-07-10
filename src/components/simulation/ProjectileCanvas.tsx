'use client';
import { useEffect, useRef, useState } from 'react';
import {
  getInitialProjectileState,
  stepProjectile,
  getProjectileAnalytics,
  generateTrajectoryPath,
} from '@/lib/physics/projectile';
import type { ProjectileParams, ProjectileState } from '@/lib/physics/projectile';
import type { GraphDataPoint } from '@/types/simulation';

interface ProjectileCanvasProps {
  params: ProjectileParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (s: ProjectileState) => void;
  onComplete?: (path: GraphDataPoint[]) => void;
  width?: number;
  height?: number;
}

interface CanvasToggles {
  ghostTrajectory: boolean;
  velocityVector: boolean;
  vxComponent: boolean;
  vyComponent: boolean;
  peakMarker: boolean;
  landingMarker: boolean;
  grid: boolean;
  hud: boolean;
  trail: boolean;
}

const DEFAULT_TOGGLES: CanvasToggles = {
  ghostTrajectory: true,
  velocityVector: true,
  vxComponent: true,
  vyComponent: true,
  peakMarker: true,
  landingMarker: true,
  grid: true,
  hud: true,
  trail: true,
};

const TOGGLE_LABELS: Record<keyof CanvasToggles, string> = {
  ghostTrajectory: 'Ghost path',
  velocityVector: 'Velocity (v)',
  vxComponent: 'Horizontal (vx)',
  vyComponent: 'Vertical (vy)',
  peakMarker: 'Peak marker',
  landingMarker: 'Landing marker',
  grid: 'Grid',
  hud: 'Live HUD',
  trail: 'Trail',
};

// Speed slider steps — frames to skip per animation frame (higher = slower)
const SPEED_STEPS = [
  { label: '0.25×', stepsPerFrame: 1, dt: 0.012 },
  { label: '0.5×',  stepsPerFrame: 1, dt: 0.025 },
  { label: '1×',    stepsPerFrame: 2, dt: 0.025 },
  { label: '2×',    stepsPerFrame: 4, dt: 0.025 },
  { label: '4×',    stepsPerFrame: 8, dt: 0.025 },
];

const GROUND_HEIGHT = 48;
const PADDING = 48;
const BALL_RADIUS = 8;

function getScale(cW: number, cH: number, maxR: number, maxH: number) {
  return Math.min(
    (cW - PADDING * 2) / (maxR * 1.1),
    (cH - GROUND_HEIGHT - PADDING * 2) / (maxH * 1.2)
  );
}

function toCanvas(x: number, y: number, scale: number, cH: number): [number, number] {
  return [PADDING + x * scale, cH - GROUND_HEIGHT - y * scale];
}

function drawArrow(
  ctx: CanvasRenderingContext2D,
  fromX: number, fromY: number,
  toX: number, toY: number,
  color: string,
  label: string
) {
  const dx = toX - fromX;
  const dy = toY - fromY;
  const len = Math.sqrt(dx * dx + dy * dy);
  if (len < 4) return;

  const angle = Math.atan2(dy, dx);
  ctx.save();
  ctx.beginPath();
  ctx.moveTo(fromX, fromY);
  ctx.lineTo(toX, toY);
  ctx.strokeStyle = color;
  ctx.lineWidth = 2.5;
  ctx.stroke();

  // Arrowhead
  const hL = 9, hA = 0.4;
  ctx.beginPath();
  ctx.moveTo(toX, toY);
  ctx.lineTo(toX - hL * Math.cos(angle - hA), toY - hL * Math.sin(angle - hA));
  ctx.lineTo(toX - hL * Math.cos(angle + hA), toY - hL * Math.sin(angle + hA));
  ctx.closePath();
  ctx.fillStyle = color;
  ctx.fill();

  // Label beside midpoint
  const midX = (fromX + toX) / 2;
  const midY = (fromY + toY) / 2;
  ctx.fillStyle = color;
  ctx.font = 'bold 10px system-ui';
  ctx.textAlign = 'center';
  // Offset label perpendicular to arrow so it doesn't overlap the line
  const perpX = -Math.sin(angle) * 13;
  const perpY =  Math.cos(angle) * 13;
  ctx.fillText(label, midX + perpX, midY + perpY);
  ctx.restore();
}

function drawScene(
  canvas: HTMLCanvasElement,
  state: ProjectileState,
  trail: [number, number][],
  fullPath: GraphDataPoint[],
  scale: number,
  analytics: { maxRange: number; maxHeight: number },
  toggles: CanvasToggles,
  showHUD: boolean
) {
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const w = canvas.width;
  const h = canvas.height;

  ctx.clearRect(0, 0, w, h);

  // Sky gradient
  const sky = ctx.createLinearGradient(0, 0, 0, h - GROUND_HEIGHT);
  sky.addColorStop(0, '#dbeafe');
  sky.addColorStop(1, '#f0f6ff');
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, w, h - GROUND_HEIGHT);

  // Ground
  ctx.fillStyle = '#e2e8f0';
  ctx.fillRect(0, h - GROUND_HEIGHT, w, GROUND_HEIGHT);
  ctx.beginPath();
  ctx.moveTo(0, h - GROUND_HEIGHT);
  ctx.lineTo(w, h - GROUND_HEIGHT);
  ctx.strokeStyle = '#94a3b8';
  ctx.lineWidth = 2;
  ctx.stroke();

  // Grid
  if (toggles.grid) {
    ctx.save();
    ctx.strokeStyle = '#e2e8f0';
    ctx.lineWidth = 1;
    ctx.fillStyle = '#94a3b8';
    ctx.font = '11px system-ui, sans-serif';
    const xStep = Math.ceil(analytics.maxRange / 6 / 5) * 5 || 1;
    ctx.textAlign = 'center';
    for (let x = 0; x <= analytics.maxRange * 1.1; x += xStep) {
      const [cx] = toCanvas(x, 0, scale, h);
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(cx, PADDING); ctx.lineTo(cx, h - GROUND_HEIGHT); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${x}m`, cx, h - GROUND_HEIGHT + 16);
    }
    ctx.textAlign = 'right';
    const yStep = Math.ceil(analytics.maxHeight / 4 / 5) * 5 || 1;
    for (let y = 0; y <= analytics.maxHeight * 1.2; y += yStep) {
      const [, cy] = toCanvas(0, y, scale, h);
      if (cy < PADDING) continue;
      ctx.beginPath(); ctx.setLineDash([3, 4]);
      ctx.moveTo(PADDING, cy); ctx.lineTo(w - PADDING, cy); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillText(`${y}m`, PADDING - 6, cy + 4);
    }
    ctx.restore();
  }

  // Ghost trajectory
  if (toggles.ghostTrajectory && fullPath.length > 1) {
    ctx.save();
    ctx.beginPath();
    const [x0, y0] = toCanvas(fullPath[0].x, fullPath[0].y, scale, h);
    ctx.moveTo(x0, y0);
    fullPath.slice(1).forEach(p => {
      const [cx, cy] = toCanvas(p.x, p.y, scale, h);
      ctx.lineTo(cx, cy);
    });
    ctx.strokeStyle = 'rgba(99,102,241,0.18)';
    ctx.lineWidth = 2;
    ctx.setLineDash([6, 4]);
    ctx.stroke();
    ctx.setLineDash([]);
    ctx.restore();
  }

  // Peak marker
  if (toggles.peakMarker) {
    const [pCx, pCy] = toCanvas(analytics.maxRange / 2, analytics.maxHeight, scale, h);
    ctx.save();
    ctx.beginPath(); ctx.setLineDash([4, 3]);
    ctx.moveTo(pCx, pCy); ctx.lineTo(pCx, h - GROUND_HEIGHT);
    ctx.strokeStyle = 'rgba(99,102,241,0.4)'; ctx.lineWidth = 1.5; ctx.stroke();
    ctx.setLineDash([]);
    ctx.fillStyle = '#6366f1'; ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${analytics.maxHeight.toFixed(1)}m`, pCx, pCy - 10);
    ctx.restore();
  }

  // Landing marker
  if (toggles.landingMarker) {
    const [lCx] = toCanvas(analytics.maxRange, 0, scale, h);
    ctx.save();
    ctx.beginPath(); ctx.arc(lCx, h - GROUND_HEIGHT, 5, 0, Math.PI * 2);
    ctx.fillStyle = '#10b981'; ctx.fill();
    ctx.fillStyle = '#10b981'; ctx.font = 'bold 11px system-ui';
    ctx.textAlign = 'center';
    ctx.fillText(`${analytics.maxRange.toFixed(1)}m`, lCx, h - GROUND_HEIGHT + 32);
    ctx.restore();
  }

  // Trail
  if (toggles.trail && trail.length > 1) {
    ctx.save();
    for (let i = 1; i < trail.length; i++) {
      const alpha = i / trail.length;
      ctx.beginPath();
      ctx.moveTo(trail[i - 1][0], trail[i - 1][1]);
      ctx.lineTo(trail[i][0], trail[i][1]);
      ctx.strokeStyle = `rgba(99,102,241,${alpha * 0.8})`;
      ctx.lineWidth = 2.5;
      ctx.stroke();
    }
    ctx.restore();
  }

  // Ball position
  const [cx, cy] = toCanvas(state.x, Math.max(0, state.y), scale, h);

  // Shadow
  ctx.save();
  ctx.beginPath();
  ctx.ellipse(cx, h - GROUND_HEIGHT + 6, 10, 4, 0, 0, Math.PI * 2);
  ctx.fillStyle = 'rgba(0,0,0,0.12)'; ctx.fill();

  // Glow
  const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, BALL_RADIUS * 2.5);
  glow.addColorStop(0, 'rgba(79,70,229,0.3)'); glow.addColorStop(1, 'transparent');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS * 2.5, 0, Math.PI * 2);
  ctx.fillStyle = glow; ctx.fill();

  // Ball body
  const ballG = ctx.createRadialGradient(cx - 2, cy - 2, 1, cx, cy, BALL_RADIUS);
  ballG.addColorStop(0, '#818cf8'); ballG.addColorStop(1, '#4f46e5');
  ctx.beginPath(); ctx.arc(cx, cy, BALL_RADIUS, 0, Math.PI * 2);
  ctx.fillStyle = ballG; ctx.fill();
  ctx.restore();

  // ── Velocity vectors ───────────────────────────────────────────────────────
  const speed = Math.sqrt(state.vx * state.vx + state.vy * state.vy);
  const ARROW_SCALE = Math.min(scale * 0.6, 4); // pixels per m/s

  // Resultant velocity vector (v)
  if (toggles.velocityVector && speed > 0.5) {
    const angle = Math.atan2(-state.vy, state.vx);
    const arrowLen = Math.min(speed * ARROW_SCALE, 70);
    drawArrow(
      ctx,
      cx, cy,
      cx + Math.cos(angle) * arrowLen,
      cy + Math.sin(angle) * arrowLen,
      '#f59e0b',
      `v=${speed.toFixed(1)}`
    );
  }

  // Horizontal component (vx) — drawn from ball rightward
  if (toggles.vxComponent && Math.abs(state.vx) > 0.1) {
    const vxLen = Math.min(Math.abs(state.vx) * ARROW_SCALE, 60);
    drawArrow(
      ctx,
      cx, cy,
      cx + vxLen, cy,        // always horizontal
      '#10b981',
      `vx=${state.vx.toFixed(1)}`
    );
  }

  // Vertical component (vy) — drawn from ball upward/downward
  if (toggles.vyComponent && Math.abs(state.vy) > 0.1) {
    const vyLen = Math.min(Math.abs(state.vy) * ARROW_SCALE, 60);
    const vyDir = state.vy > 0 ? -1 : 1; // canvas y is inverted
    drawArrow(
      ctx,
      cx, cy,
      cx, cy + vyDir * vyLen,
      '#ef4444',
      `vy=${state.vy.toFixed(1)}`
    );
  }

  // HUD
  if (toggles.hud && showHUD) {
    const lines = [
      `t  = ${state.time.toFixed(2)}s`,
      `v  = ${speed.toFixed(1)} m/s`,
      `vx = ${state.vx.toFixed(1)} m/s`,
      `vy = ${state.vy.toFixed(1)} m/s`,
      `h  = ${Math.max(0, state.y).toFixed(1)}m`,
      `x  = ${state.x.toFixed(1)}m`,
    ];
    const bx = w - 138, by = 12, bW = 126, bH = lines.length * 18 + 14;
    ctx.save();
    ctx.fillStyle = 'rgba(255,255,255,0.92)';
    ctx.beginPath(); ctx.roundRect(bx, by, bW, bH, 8); ctx.fill();
    ctx.strokeStyle = 'rgba(99,102,241,0.25)'; ctx.lineWidth = 1; ctx.stroke();
    ctx.fillStyle = '#1e293b'; ctx.font = '11px monospace'; ctx.textAlign = 'left';
    lines.forEach((l, i) => ctx.fillText(l, bx + 10, by + 20 + i * 18));
    ctx.restore();
  }
}

export function ProjectileCanvas({
  params,
  isRunning,
  isPaused,
  onTick,
  onComplete,
  width = 720,
  height = 380,
}: ProjectileCanvasProps) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const [toggles, setToggles] = useState<CanvasToggles>(DEFAULT_TOGGLES);
  const [showToggles, setShowToggles] = useState(false);
  const [speedIndex, setSpeedIndex] = useState(1); // default 0.5×

  const sim = useRef({
    state: getInitialProjectileState(params),
    trail: [] as [number, number][],
    completed: false,
    analytics: getProjectileAnalytics(params),
    fullPath: generateTrajectoryPath(params),
    scale: 1,
    params, isRunning, isPaused, onTick, onComplete,
    toggles, width, height,
    speedIndex,
  });

  // Keep mirrors fresh every render
  sim.current.params      = params;
  sim.current.isRunning   = isRunning;
  sim.current.isPaused    = isPaused;
  sim.current.onTick      = onTick;
  sim.current.onComplete  = onComplete;
  sim.current.toggles     = toggles;
  sim.current.width       = width;
  sim.current.height      = height;
  sim.current.speedIndex  = speedIndex;
  sim.current.scale       = getScale(width, height, sim.current.analytics.maxRange, sim.current.analytics.maxHeight);

  // Initialise on mount (key={resetKey} in parent guarantees fresh mount on Reset)
  useEffect(() => {
    const s = sim.current;
    s.analytics = getProjectileAnalytics(params);
    s.fullPath  = generateTrajectoryPath(params);
    s.scale     = getScale(width, height, s.analytics.maxRange, s.analytics.maxHeight);
    s.state     = getInitialProjectileState(params);
    s.trail     = [];
    s.completed = false;
    const canvas = canvasRef.current;
    if (canvas) {
      drawScene(canvas, s.state, [], s.fullPath, s.scale, s.analytics, s.toggles, false);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Single persistent RAF loop
  useEffect(() => {
    const loop = () => {
      const s = sim.current;
      const { stepsPerFrame, dt } = SPEED_STEPS[s.speedIndex];

      if (s.isRunning && !s.isPaused && !s.completed) {
        for (let i = 0; i < stepsPerFrame; i++) {
          s.state = stepProjectile(s.state, s.params, dt);
          const [bx, by] = toCanvas(s.state.x, Math.max(0, s.state.y), s.scale, s.height);
          s.trail.push([bx, by]);
          if (s.trail.length > 180) s.trail.shift();
          if (s.state.y < 0 || s.state.time > 100) {
            s.completed = true;
            s.onComplete?.(s.fullPath);
            break;
          }
        }
        s.onTick?.(s.state);
      }

      const canvas = canvasRef.current;
      if (canvas) {
        drawScene(
          canvas, s.state, s.trail, s.fullPath,
          s.scale, s.analytics, s.toggles,
          s.isRunning || s.state.time > 0
        );
      }
      rafRef.current = requestAnimationFrame(loop);
    };

    rafRef.current = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(rafRef.current);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const toggleItem = (key: keyof CanvasToggles) =>
    setToggles(prev => ({ ...prev, [key]: !prev[key] }));

  return (
    <div className="space-y-2">
      {/* Toolbar */}
      <div className="flex items-center gap-2 flex-wrap">
        {/* Overlays toggle */}
        <button
          onClick={() => setShowToggles(v => !v)}
          className="flex items-center gap-1.5 rounded-lg border border-gray-200 bg-white px-3 py-1.5 text-xs font-medium text-gray-600 hover:bg-gray-50 transition"
        >
          <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
            <circle cx="6" cy="6" r="2"/>
            <path d="M6 1v1M6 10v1M1 6h1M10 6h1"/>
          </svg>
          Overlays
        </button>

        {/* Speed control */}
        <div className="flex items-center gap-1 rounded-lg border border-gray-200 bg-white px-2 py-1">
          <span className="text-[10px] text-gray-400 mr-1">Speed</span>
          {SPEED_STEPS.map((s, i) => (
            <button
              key={s.label}
              onClick={() => setSpeedIndex(i)}
              className={`rounded px-2 py-0.5 text-[11px] font-medium transition ${
                speedIndex === i
                  ? 'bg-indigo-600 text-white'
                  : 'text-gray-500 hover:bg-gray-100'
              }`}
            >
              {s.label}
            </button>
          ))}
        </div>

        {/* Vector legend */}
        <div className="flex items-center gap-2 ml-auto text-[10px] font-medium">
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-amber-400 rounded"/>
            <span className="text-gray-500">v</span>
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-emerald-500 rounded"/>
            <span className="text-gray-500">vx</span>
          </span>
          <span className="flex items-center gap-1">
            <span className="inline-block w-3 h-0.5 bg-red-400 rounded"/>
            <span className="text-gray-500">vy</span>
          </span>
        </div>
      </div>

      {/* Overlay pills */}
      {showToggles && (
        <div className="flex flex-wrap gap-2">
          {(Object.keys(DEFAULT_TOGGLES) as (keyof CanvasToggles)[]).map(key => (
            <button
              key={key}
              onClick={() => toggleItem(key)}
              className={`rounded-full px-3 py-1 text-xs font-medium border transition ${
                toggles[key]
                  ? 'bg-indigo-600 text-white border-indigo-600'
                  : 'bg-white text-gray-400 border-gray-200 hover:border-gray-300'
              }`}
            >
              {TOGGLE_LABELS[key]}
            </button>
          ))}
        </div>
      )}

      {/* Canvas — no overlay banner */}
      <div className="relative w-full overflow-hidden rounded-xl border border-gray-200 bg-white shadow-sm">
        <canvas
          ref={canvasRef}
          width={width}
          height={height}
          className="w-full"
          style={{ display: 'block' }}
        />
      </div>
    </div>
  );
}