'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  PendulumState, PendulumParams, rk4Step, getPositions,
  kineticEnergy, potentialEnergy,
  addTrailPoint, TrailPoint,
  analyzeDecay, DecayAnalysis,
} from '@/lib/physics/doublePendulum';

interface TickMeta {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
  chartHistory: Array<{ t: number; e: number }>;
}

interface Props {
  theta1Deg: number; omega1Init: number;
  theta2Deg: number; omega2Init: number;
  params: PendulumParams;
  isRunning: boolean;
  isPaused: boolean;
  showTrail: boolean;
  showEnergy: boolean;
  trailLength: number;
  onTick?: (state: PendulumState, energy: { ke: number; pe: number; total: number }, meta: TickMeta) => void;
  width?: number;
  height?: number;
}

export function DoublePendulumCanvas({
  theta1Deg, omega1Init, theta2Deg, omega2Init,
  params,
  isRunning,
  isPaused,
  showTrail,
  showEnergy,
  trailLength,
  onTick,
  width = 660,
  height = 420,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const simTimeRef = useRef(0);
  const energyHistoryRef = useRef<Array<{ t: number; e: number; signal: number }>>([]);
  const analysisRef = useRef<DecayAnalysis>({ qFactor: 0, bandwidth: 0, decayRate: 0, valid: false });
  const lastAnalysisRef = useRef(0);
  const chartHistoryRef = useRef<Array<{ t: number; e: number }>>([]);
  const dprRef = useRef(1);

  // EMA-smoothed energy values for the bar (alpha = 0.25)
  const smoothKeRef = useRef(0);
  const smoothPeRef = useRef(0);
  const smoothTotalRef = useRef(0);

  const stateRef = useRef<PendulumState>({
    theta1: (theta1Deg * Math.PI) / 180,
    omega1: omega1Init,
    theta2: (theta2Deg * Math.PI) / 180,
    omega2: omega2Init,
  });
  const trailRef = useRef<TrailPoint[]>([]);

  const propsRef = useRef({ params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick });
  propsRef.current = { params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick };

  const initRef = useRef({ theta1Deg, omega1Init, theta2Deg, omega2Init });
  useEffect(() => {
    const prev = initRef.current;
    if (prev.theta1Deg !== theta1Deg || prev.omega1Init !== omega1Init ||
        prev.theta2Deg !== theta2Deg || prev.omega2Init !== omega2Init) {
      stateRef.current = {
        theta1: (theta1Deg * Math.PI) / 180,
        omega1: omega1Init,
        theta2: (theta2Deg * Math.PI) / 180,
        omega2: omega2Init,
      };
      trailRef.current = [];
      lastFrameRef.current = null;
      simTimeRef.current = 0;
      energyHistoryRef.current = [];
      chartHistoryRef.current = [];
      analysisRef.current = { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
      lastAnalysisRef.current = 0;
      smoothKeRef.current = 0;
      smoothPeRef.current = 0;
      smoothTotalRef.current = 0;
      initRef.current = { theta1Deg, omega1Init, theta2Deg, omega2Init };
    }
  }, [theta1Deg, omega1Init, theta2Deg, omega2Init]);

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 3);
    dprRef.current = dpr;
    canvas.width = Math.round(width * dpr);
    canvas.height = Math.round(height * dpr);
    const ctx = canvas.getContext('2d');
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }, [width, height]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = propsRef.current;
    const W = width;
    const H = height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    if (dt > 0) {
      const subSteps = Math.max(4, Math.min(12, Math.ceil(dt * 200)));
      const subDt = dt / subSteps;
      for (let i = 0; i < subSteps; i++) {
        stateRef.current = rk4Step(stateRef.current, s.params, subDt);
        simTimeRef.current += subDt;
      }

      const pos = getPositions(stateRef.current, s.params);
      if (s.showTrail) {
        trailRef.current = addTrailPoint(trailRef.current, pos.x2, pos.y2, s.trailLength);
      }

      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;

      // Smooth energy bar values
      const alpha = 0.25;
      smoothKeRef.current += alpha * (ke - smoothKeRef.current);
      smoothPeRef.current += alpha * (pe - smoothPeRef.current);
      smoothTotalRef.current += alpha * (total - smoothTotalRef.current);

      energyHistoryRef.current.push({
        t: simTimeRef.current,
        e: total,
        signal: stateRef.current.theta1,
      });
      const cutoff = simTimeRef.current - 5;
      energyHistoryRef.current = energyHistoryRef.current.filter(p => p.t > cutoff);

      const lastChart = chartHistoryRef.current[chartHistoryRef.current.length - 1];
      if (!lastChart || simTimeRef.current - lastChart.t > 0.12) {
        chartHistoryRef.current.push({ t: simTimeRef.current, e: total });
      }
      const chartCutoff = simTimeRef.current - 10;
      chartHistoryRef.current = chartHistoryRef.current.filter(p => p.t > chartCutoff);

      if (simTimeRef.current - lastAnalysisRef.current > 0.5 && energyHistoryRef.current.length > 40) {
        analysisRef.current = analyzeDecay(energyHistoryRef.current);
        lastAnalysisRef.current = simTimeRef.current;
      }

      s.onTick?.(stateRef.current, { ke, pe, total }, {
        qFactor: analysisRef.current.qFactor,
        bandwidth: analysisRef.current.bandwidth,
        decayRate: analysisRef.current.decayRate,
        valid: analysisRef.current.valid,
        chartHistory: [...chartHistoryRef.current],
      });
    }

    // ── Rendering (logical coordinates) ───────────────────────────────────
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#0f172a'; ctx.fillRect(0, 0, W, H);

    const totalLen = s.params.L1 + s.params.L2;
    const margin = 60;
    const scale = Math.min((W - 2 * margin) / (totalLen * 2.2), (H - 2 * margin) / (totalLen * 2.2));
    const pivotX = W / 2;
    const pivotY = H * 0.15;

    const pos = getPositions(stateRef.current, s.params);
    const sx1 = pivotX + pos.x1 * scale;
    const sy1 = pivotY - pos.y1 * scale;
    const sx2 = pivotX + pos.x2 * scale;
    const sy2 = pivotY - pos.y2 * scale;

    ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)';
    ctx.lineWidth = 1;
    for (let r = 0.5; r <= totalLen; r += 0.5) {
      ctx.beginPath();
      ctx.arc(pivotX, pivotY, r * scale, 0, Math.PI * 2);
      ctx.stroke();
    }

    if (s.showTrail && trailRef.current.length > 1) {
      for (let i = 1; i < trailRef.current.length; i++) {
        const p0 = trailRef.current[i - 1];
        const p1 = trailRef.current[i];
        const alpha = 1 - p1.age / s.trailLength;
        ctx.strokeStyle = `rgba(244, 63, 94, ${alpha * 0.6})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.moveTo(pivotX + p0.x * scale, pivotY - p0.y * scale);
        ctx.lineTo(pivotX + p1.x * scale, pivotY - p1.y * scale);
        ctx.stroke();
      }
    }

    ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(pivotX, pivotY); ctx.lineTo(sx1, sy1); ctx.stroke();
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1.5;
    ctx.beginPath(); ctx.moveTo(sx1, sy1); ctx.lineTo(sx2, sy2); ctx.stroke();

    ctx.fillStyle = '#f8fafc';
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(pivotX, pivotY, 5, 0, Math.PI * 2); ctx.stroke();

    const r1 = 8 + Math.min(s.params.m1, 3) * 4;
    ctx.fillStyle = '#6366f1';
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx1, sy1, r1, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m1.toFixed(1)}kg`, sx1, sy1 + 3);

    const r2 = 8 + Math.min(s.params.m2, 3) * 4;
    ctx.fillStyle = '#f59e0b';
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#d97706'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.arc(sx2, sy2, r2, 0, Math.PI * 2); ctx.stroke();
    ctx.fillStyle = 'white'; ctx.font = 'bold 9px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m2.toFixed(1)}kg`, sx2, sy2 + 3);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    const t1deg = (stateRef.current.theta1 * 180 / Math.PI).toFixed(1);
    const t2deg = (stateRef.current.theta2 * 180 / Math.PI).toFixed(1);
    ctx.fillText(`θ₁ = ${t1deg}°`, 12, H - 36);
    ctx.fillText(`θ₂ = ${t2deg}°`, 12, H - 22);
    ctx.fillText(`ω₁ = ${stateRef.current.omega1.toFixed(2)} rad/s`, 12, H - 8);

    // ── Energy bar (smoothed + clamped) ────────────────────────────────────
    if (s.showEnergy) {
      const ke = smoothKeRef.current;
      const pe = smoothPeRef.current;
      const total = smoothTotalRef.current;
      const safeTotal = Math.max(total, 1e-6);
      const keFrac = Math.min(1, Math.max(0, ke / safeTotal));
      const peFrac = Math.min(1, Math.max(0, pe / safeTotal));

      const barW = 140;
      const barH = 10;
      const barX = W - barW - 18;
      const barY = H - 48;
      const r = barH / 2;

      // Background track
      ctx.fillStyle = 'rgba(30, 41, 59, 0.9)';
      ctx.beginPath();
      ctx.roundRect(barX - 6, barY - 22, barW + 12, 44, 6);
      ctx.fill();

      // Label
      ctx.fillStyle = '#94a3b8';
      ctx.font = '9px system-ui';
      ctx.textAlign = 'left';
      ctx.fillText('Energy', barX, barY - 6);

      // Track
      ctx.fillStyle = '#1e293b';
      ctx.beginPath();
      ctx.roundRect(barX, barY, barW, barH, r);
      ctx.fill();

      // KE segment
      if (keFrac > 0.005) {
        ctx.fillStyle = '#ef4444';
        ctx.beginPath();
        ctx.roundRect(barX, barY, barW * keFrac, barH, r);
        ctx.fill();
      }

      // PE segment
      if (peFrac > 0.005) {
        ctx.fillStyle = '#3b82f6';
        ctx.beginPath();
        ctx.roundRect(barX + barW * keFrac, barY, barW * peFrac, barH, r);
        ctx.fill();
      }

      // Divider line
      if (keFrac > 0.01 && peFrac > 0.01) {
        ctx.strokeStyle = '#0f172a';
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(barX + barW * keFrac, barY);
        ctx.lineTo(barX + barW * keFrac, barY + barH);
        ctx.stroke();
      }

      // Legend
      ctx.font = '8px system-ui';
      ctx.fillStyle = '#ef4444';
      ctx.fillText('KE', barX, barY + barH + 12);
      ctx.fillStyle = '#3b82f6';
      ctx.fillText('PE', barX + barW * keFrac + 4, barY + barH + 12);
      ctx.fillStyle = '#cbd5e1';
      ctx.textAlign = 'right';
      ctx.fillText(`${total.toFixed(2)} J`, barX + barW, barY + barH + 12);
    }

    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (!s.isRunning) {
      ctx.fillStyle = '#94a3b8';
      ctx.fillText('Press Run to start the simulation', W / 2, 24);
    } else if (s.isPaused) {
      ctx.fillStyle = '#f59e0b';
      ctx.fillText('⏸ Paused', W / 2, 24);
    } else {
      ctx.fillStyle = '#10b981';
      ctx.fillText('● Running', W / 2, 24);
    }

    rafRef.current = requestAnimationFrame(draw);
  }, [width, height]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef}
      width={width}
      height={height}
      className="w-full rounded-xl border border-gray-700 bg-slate-900"
      style={{ display: 'block', touchAction: 'pan-y' }}
    />
  );
}
