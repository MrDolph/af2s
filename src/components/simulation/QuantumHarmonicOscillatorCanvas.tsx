'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  QHOParams, normalize, wavefunction, computeExpectations,
  energyExpectation, classicalTurningPoints,
  type WavefunctionResult,
} from '@/lib/physics/quantumHarmonicOscillator';

interface Props {
  coeffs: number[];
  params: QHOParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: {
    energy: number;
    x: number;
    x2: number;
    p: number;
    p2: number;
    leftTurn: number;
    rightTurn: number;
    maxProb: number;
  }) => void;
  width?: number;
  height?: number;
}

interface GridPoint extends WavefunctionResult {
  x: number;
}

export function QuantumHarmonicOscillatorCanvas({
  coeffs,
  params,
  isRunning,
  isPaused,
  onTick,
  width = 660,
  height = 420,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, coeffs, isRunning, isPaused, onTick });
  propsRef.current = { params, coeffs, isRunning, isPaused, onTick };

  // Reset time when coefficients change
  const coeffsRef = useRef(coeffs);
  useEffect(() => {
    const prev = coeffsRef.current;
    const changed =
      prev.length !== coeffs.length ||
      prev.some((c, i) => Math.abs(c - coeffs[i]) > 1e-6);
    if (changed) {
      timeRef.current = 0;
      coeffsRef.current = [...coeffs];
    }
  }, [coeffs]);

  const draw = useCallback(
    (timestamp?: number) => {
      const canvas = canvasRef.current;
      if (!canvas) return;
      const ctx = canvas.getContext('2d');
      if (!ctx) return;
      const s = propsRef.current;

      const dpr = window.devicePixelRatio || 1;
      const displayW = width;
      const displayH = height;

      // Super-responsive: adapt internal resolution to device pixel ratio
      if (
        canvas.width !== Math.floor(displayW * dpr) ||
        canvas.height !== Math.floor(displayH * dpr)
      ) {
        canvas.width = Math.floor(displayW * dpr);
        canvas.height = Math.floor(displayH * dpr);
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

      // Physics time step
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
        timeRef.current += dt * s.params.speed;
      }
      const t = timeRef.current;

      // Clear
      ctx.clearRect(0, 0, displayW, displayH);
      ctx.fillStyle = '#0f172a';
      ctx.fillRect(0, 0, displayW, displayH);

      // Compute wavefunction on adaptive grid
      const xMax = s.params.xMax;
      const gridN = Math.min(1200, Math.max(200, Math.floor(displayW * 1.5)));
      const points: GridPoint[] = [];
      const normCoeffs = normalize(s.coeffs);
      for (let i = 0; i <= gridN; i++) {
        const x = -xMax + (i / gridN) * (2 * xMax);
        points.push({ x, ...wavefunction(x, normCoeffs, t) });
      }

      // Expectation values
      const exps = computeExpectations(points);
      const energy = energyExpectation(normCoeffs);
      const { left, right } = classicalTurningPoints(energy);
      const maxProb = Math.max(...points.map((p) => p.prob));

      // Throttled stats callback
      if (s.onTick && timestamp !== undefined) {
        const now = performance.now();
        if (now - lastTickRef.current > 80) {
          lastTickRef.current = now;
          s.onTick({
            energy,
            ...exps,
            leftTurn: left,
            rightTurn: right,
            maxProb,
          });
        }
      }

      // Layout
      const padL = 52;
      const padR = 16;
      const padT = 16;
      const padB = 36;
      const plotW = displayW - padL - padR;
      const plotH = displayH - padT - padB;
      const mapX = (x: number) => padL + ((x + xMax) / (2 * xMax)) * plotW;

      // ── Energy diagram (top 40 %) ─────────────────────────────────────────
      const eMax = s.params.eMax;
      const energyH = plotH * 0.40;
      const eTop = padT;
      const eBottom = padT + energyH;
      const mapE = (E: number) => eBottom - (E / eMax) * energyH;

      // Potential V(x) = ½ x²
      if (s.params.showPotential) {
        ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let px = 0; px <= plotW; px += 2) {
          const x = -xMax + (px / plotW) * (2 * xMax);
          const V = 0.5 * x * x;
          if (V > eMax) continue;
          const py = mapE(V);
          if (px === 0) ctx.moveTo(mapX(x), py);
          else ctx.lineTo(mapX(x), py);
        }
        ctx.stroke();
      }

      // Energy levels
      if (s.params.showEnergyLevels) {
        for (let n = 0; n < s.params.nMax; n++) {
          const E = n + 0.5;
          if (E > eMax) break;
          const y = mapE(E);
          ctx.strokeStyle = 'rgba(99, 102, 241, 0.35)';
          ctx.setLineDash([3, 3]);
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(mapX(-xMax), y);
          ctx.lineTo(mapX(xMax), y);
          ctx.stroke();
          ctx.setLineDash([]);
          ctx.fillStyle = '#818cf8';
          ctx.font = '10px system-ui';
          ctx.textAlign = 'right';
          ctx.fillText(`n=${n}  E=${E.toFixed(1)}ℏω`, mapX(-xMax) - 6, y + 3);
        }
      }

      // ── Wavefunction diagram (bottom 58 %) ────────────────────────────────
      const wfTop = eBottom + 8;
      const wfH = displayH - padB - wfTop;
      const xAxisY = wfTop + wfH * 0.55;
      const probScale = wfH * 0.50;
      const waveScale = wfH * 0.40;

      // X-axis
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.25)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(mapX(-xMax), xAxisY);
      ctx.lineTo(mapX(xMax), xAxisY);
      ctx.stroke();

      // Classical turning points
      if (s.params.showClassicalTurning && energy > 0) {
        ctx.strokeStyle = 'rgba(16, 185, 129, 0.35)';
        ctx.setLineDash([6, 4]);
        ctx.lineWidth = 1;
        for (const sign of [-1, 1]) {
          const xT = sign * Math.sqrt(2 * energy);
          if (Math.abs(xT) <= xMax) {
            ctx.beginPath();
            ctx.moveTo(mapX(xT), wfTop);
            ctx.lineTo(mapX(xT), displayH - padB);
            ctx.stroke();
          }
        }
        ctx.setLineDash([]);
        ctx.fillStyle = '#10b981';
        ctx.font = '9px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('classical turning points', mapX(0), displayH - padB + 14);
      }

      // |ψ|² — filled area
      if (s.params.showProbability) {
        ctx.fillStyle = 'rgba(244, 63, 94, 0.18)';
        ctx.beginPath();
        ctx.moveTo(mapX(-xMax), xAxisY);
        for (const p of points) {
          ctx.lineTo(mapX(p.x), xAxisY - p.prob * probScale);
        }
        ctx.lineTo(mapX(xMax), xAxisY);
        ctx.closePath();
        ctx.fill();

        ctx.strokeStyle = '#f43f5e';
        ctx.lineWidth = 2;
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].prob * probScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }

      // Re(ψ)
      if (s.params.showReal) {
        ctx.strokeStyle = '#3b82f6';
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].re * waveScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
      }

      // Im(ψ)
      if (s.params.showImaginary) {
        ctx.strokeStyle = '#f59e0b';
        ctx.lineWidth = 1.5;
        ctx.setLineDash([4, 2]);
        ctx.beginPath();
        for (let i = 0; i < points.length; i++) {
          const px = mapX(points[i].x);
          const py = xAxisY - points[i].im * waveScale;
          if (i === 0) ctx.moveTo(px, py);
          else ctx.lineTo(px, py);
        }
        ctx.stroke();
        ctx.setLineDash([]);
      }

      // ⟨x⟩ expectation indicator
      const xExp = exps.x;
      if (Math.abs(xExp) <= xMax) {
        ctx.fillStyle = '#f8fafc';
        ctx.beginPath();
        ctx.arc(mapX(xExp), xAxisY, 5, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = '#64748b';
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.arc(mapX(xExp), xAxisY, 5, 0, Math.PI * 2);
        ctx.stroke();
      }

      // Axis labels
      ctx.fillStyle = '#64748b';
      ctx.font = '10px system-ui';
      ctx.textAlign = 'center';
      ctx.fillText('Position x (units of √(ℏ/mω))', mapX(0), displayH - 8);

      ctx.save();
      ctx.translate(14, xAxisY);
      ctx.rotate(-Math.PI / 2);
      ctx.textAlign = 'center';
      ctx.fillText('Amplitude', 0, 0);
      ctx.restore();

      // Legend
      const legendX = displayW - padR - 100;
      const legendY = wfTop + 10;
      ctx.font = '10px system-ui';
      ctx.textAlign = 'left';
      let ly = legendY;
      if (s.params.showProbability) {
        ctx.fillStyle = '#f43f5e';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('|ψ|²', legendX + 14, ly + 9);
        ly += 16;
      }
      if (s.params.showReal) {
        ctx.fillStyle = '#3b82f6';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Re(ψ)', legendX + 14, ly + 9);
        ly += 16;
      }
      if (s.params.showImaginary) {
        ctx.fillStyle = '#f59e0b';
        ctx.fillRect(legendX, ly, 10, 10);
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Im(ψ)', legendX + 14, ly + 9);
        ly += 16;
      }

      // Status
      ctx.font = 'bold 11px system-ui';
      ctx.textAlign = 'center';
      if (!s.isRunning) {
        ctx.fillStyle = '#94a3b8';
        ctx.fillText('Press Run to start time evolution', displayW / 2, 28);
      } else if (s.isPaused) {
        ctx.fillStyle = '#f59e0b';
        ctx.fillText('⏸ Paused', displayW / 2, 28);
      } else {
        ctx.fillStyle = '#10b981';
        ctx.fillText('● Evolving', displayW / 2, 28);
      }

      rafRef.current = requestAnimationFrame(draw);
    },
    [width, height]
  );

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas
      ref={canvasRef}
      width={width}
      height={height}
      className="w-full rounded-xl border border-gray-700 bg-slate-900"
      style={{ display: 'block' }}
    />
  );
}
