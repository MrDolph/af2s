'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  OscillatorState, OscillatorParams, rk4Step,
  kineticEnergy, potentialEnergy,
  addTrailPoint, TrailPoint,
  analyzeDecay, DecayAnalysis,
} from '@/lib/physics/coupledOscillators';

interface TickMeta {
  qFactor: number;
  bandwidth: number;
  decayRate: number;
  valid: boolean;
  chartHistory: Array<{ t: number; e: number }>;
}

interface Props {
  x1Init: number; v1Init: number;
  x2Init: number; v2Init: number;
  params: OscillatorParams;
  isRunning: boolean;
  isPaused: boolean;
  showTrail: boolean;
  showEnergy: boolean;
  trailLength: number;
  onTick?: (state: OscillatorState, energy: { ke: number; pe: number; total: number }, meta: TickMeta) => void;
  width?: number;
  height?: number;
}

export function CoupledOscillatorsCanvas({
  x1Init, v1Init, x2Init, v2Init,
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

  const stateRef = useRef<OscillatorState>({ x1: x1Init, v1: v1Init, x2: x2Init, v2: v2Init });
  const trailRef = useRef<TrailPoint[]>([]);

  const propsRef = useRef({ params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick });
  propsRef.current = { params, isRunning, isPaused, showTrail, showEnergy, trailLength, onTick };

  const initRef = useRef({ x1Init, v1Init, x2Init, v2Init });
  useEffect(() => {
    const prev = initRef.current;
    if (prev.x1Init !== x1Init || prev.v1Init !== v1Init ||
        prev.x2Init !== x2Init || prev.v2Init !== v2Init) {
      stateRef.current = { x1: x1Init, v1: v1Init, x2: x2Init, v2: v2Init };
      trailRef.current = [];
      lastFrameRef.current = null;
      simTimeRef.current = 0;
      energyHistoryRef.current = [];
      chartHistoryRef.current = [];
      analysisRef.current = { qFactor: 0, bandwidth: 0, decayRate: 0, valid: false };
      lastAnalysisRef.current = 0;
      initRef.current = { x1Init, v1Init, x2Init, v2Init };
    }
  }, [x1Init, v1Init, x2Init, v2Init]);

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
      const subSteps = Math.max(4, Math.min(12, Math.ceil(dt * 300)));
      const subDt = dt / subSteps;
      for (let i = 0; i < subSteps; i++) {
        stateRef.current = rk4Step(stateRef.current, s.params, subDt);
        simTimeRef.current += subDt;
      }

      if (s.showTrail) {
        trailRef.current = addTrailPoint(trailRef.current, stateRef.current.x1, stateRef.current.x2, simTimeRef.current, s.trailLength);
      }

      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;

      energyHistoryRef.current.push({
        t: simTimeRef.current,
        e: total,
        signal: stateRef.current.x1,
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

    const worldLeft = -0.4;
    const worldRight = 0.4;
    const worldWidth = worldRight - worldLeft;
    const trackY = H * 0.35;
    const wallX1 = W * 0.08;
    const wallX2 = W * 0.92;
    const screenWidth = wallX2 - wallX1;
    const scale = screenWidth / worldWidth;

    function worldToScreen(x: number) {
      return wallX1 + ((x - worldLeft) / worldWidth) * screenWidth;
    }

    // Track line
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(wallX1, trackY); ctx.lineTo(wallX2, trackY); ctx.stroke();

    // Walls
    ctx.fillStyle = '#475569';
    ctx.fillRect(wallX1 - 10, trackY - 50, 10, 100);
    ctx.fillRect(wallX2, trackY - 50, 10, 100);

    function drawSpring(xA: number, xB: number, y: number, coils: number, amp: number, color: string) {
      const len = xB - xA;
      const seg = len / (coils * 2);
      ctx.strokeStyle = color;
      ctx.lineWidth = 2;
      ctx.lineJoin = 'round';
      ctx.beginPath();
      ctx.moveTo(xA, y);
      for (let i = 0; i < coils * 2; i++) {
        const x = xA + (i + 1) * seg;
        const yOff = (i % 2 === 0 ? -1 : 1) * amp;
        ctx.lineTo(x - seg / 2, y + yOff);
        ctx.lineTo(x, y);
      }
      ctx.stroke();
    }

    const sx1 = worldToScreen(stateRef.current.x1);
    const sx2 = worldToScreen(stateRef.current.x2);
    const mW1 = 18 + Math.min(s.params.m1, 5) * 10;
    const mW2 = 18 + Math.min(s.params.m2, 5) * 10;

    drawSpring(wallX1, sx1 - mW1 / 2, trackY, 10, 12, '#6366f1');
    drawSpring(sx1 + mW1 / 2, sx2 - mW2 / 2, trackY, 10, 12, '#f59e0b');
    drawSpring(sx2 + mW2 / 2, wallX2, trackY, 10, 12, '#10b981');

    ctx.fillStyle = '#6366f1';
    ctx.fillRect(sx1 - mW1 / 2, trackY - 22, mW1, 44);
    ctx.strokeStyle = '#4338ca'; ctx.lineWidth = 2;
    ctx.strokeRect(sx1 - mW1 / 2, trackY - 22, mW1, 44);
    ctx.fillStyle = 'white'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(`${s.params.m1.toFixed(1)}`, sx1, trackY + 4);

    ctx.fillStyle = '#f59e0b';
    ctx.fillRect(sx2 - mW2 / 2, trackY - 22, mW2, 44);
    ctx.strokeStyle = '#d97706'; ctx.lineWidth = 2;
    ctx.strokeRect(sx2 - mW2 / 2, trackY - 22, mW2, 44);
    ctx.fillStyle = 'white';
    ctx.fillText(`${s.params.m2.toFixed(1)}`, sx2, trackY + 4);

    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`x₁ = ${stateRef.current.x1.toFixed(3)} m`, 12, H - 36);
    ctx.fillText(`x₂ = ${stateRef.current.x2.toFixed(3)} m`, 12, H - 22);
    ctx.fillText(`v₁ = ${stateRef.current.v1.toFixed(2)} m/s`, 12, H - 8);

    // Strip chart
    const chartH = 90;
    const chartY = H - chartH - 8;
    const chartW = W - 20;
    const chartX = 10;
    ctx.fillStyle = 'rgba(15, 23, 42, 0.6)';
    ctx.fillRect(chartX, chartY, chartW, chartH);
    ctx.strokeStyle = '#334155'; ctx.lineWidth = 1;
    ctx.strokeRect(chartX, chartY, chartW, chartH);

    ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 1;
    ctx.beginPath(); ctx.moveTo(chartX, chartY + chartH / 2); ctx.lineTo(chartX + chartW, chartY + chartH / 2); ctx.stroke();

    if (trailRef.current.length > 1) {
      const tWindow = 6;
      const maxX = Math.max(0.25, ...trailRef.current.map(p => Math.max(Math.abs(p.x1), Math.abs(p.x2))));

      ctx.strokeStyle = '#6366f1'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      let first = true;
      for (const p of trailRef.current) {
        const age = simTimeRef.current - p.t;
        if (age > tWindow) continue;
        const x = chartX + chartW * (1 - age / tWindow);
        const y = chartY + chartH / 2 - (p.x1 / maxX) * (chartH / 2 - 6);
        if (first) { ctx.moveTo(x, y); first = false; }
        else { ctx.lineTo(x, y); }
      }
      ctx.stroke();

      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 1.5;
      ctx.beginPath();
      first = true;
      for (const p of trailRef.current) {
        const age = simTimeRef.current - p.t;
        if (age > tWindow) continue;
        const x = chartX + chartW * (1 - age / tWindow);
        const y = chartY + chartH / 2 - (p.x2 / maxX) * (chartH / 2 - 6);
        if (first) { ctx.moveTo(x, y); first = false; }
        else { ctx.lineTo(x, y); }
      }
      ctx.stroke();

      ctx.fillStyle = '#94a3b8'; ctx.font = '8px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('x₁', chartX + 4, chartY + 12);
      ctx.fillText('x₂', chartX + 4, chartY + 22);
      ctx.fillStyle = '#6366f1'; ctx.fillRect(chartX + 22, chartY + 7, 8, 3);
      ctx.fillStyle = '#f59e0b'; ctx.fillRect(chartX + 22, chartY + 17, 8, 3);
    }

    if (s.showEnergy) {
      const ke = kineticEnergy(stateRef.current, s.params);
      const pe = potentialEnergy(stateRef.current, s.params);
      const total = ke + pe;
      const barW = 120; const barH = 8;
      const barX = W - barW - 16; const barY = H - 40;
      const keFrac = ke / Math.max(total, 0.001);
      const peFrac = pe / Math.max(total, 0.001);

      ctx.fillStyle = 'rgba(30, 41, 59, 0.8)';
      ctx.fillRect(barX - 4, barY - 18, barW + 8, 36);
      ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.textAlign = 'left';
      ctx.fillText('Energy', barX, barY - 4);

      ctx.fillStyle = '#ef4444';
      ctx.fillRect(barX, barY, barW * keFrac, barH);
      ctx.fillStyle = '#3b82f6';
      ctx.fillRect(barX + barW * keFrac, barY, barW * peFrac, barH);

      ctx.fillStyle = '#94a3b8'; ctx.font = '8px system-ui';
      ctx.fillText(`KE`, barX, barY + barH + 10);
      ctx.fillText(`PE`, barX + barW * keFrac + 4, barY + barH + 10);
      ctx.fillText(`${total.toFixed(3)}J`, barX + barW - 38, barY + barH + 10);
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
