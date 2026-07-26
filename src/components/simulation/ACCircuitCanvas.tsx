'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg,
} from '@/lib/physics/electromagnetism';

export type ACMode = 'waveform' | 'reactance' | 'rlc-circuit';

interface Props {
  mode: ACMode;
  vPeak: number;         // V
  frequency: number;     // Hz
  resistance: number;    // ohm — waveform & rlc-circuit
  component: 'inductor' | 'capacitor'; // reactance mode
  inductance: number;    // H — reactance & rlc-circuit
  capacitance: number;   // F — reactance & rlc-circuit
  isRunning: boolean; isPaused: boolean;
  onTick?: (value: number) => void;
  width?: number; height?: number;
}

function drawAxes(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number) {
  ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2); ctx.lineTo(gx + gw, gy + gh / 2); ctx.stroke();
  ctx.strokeStyle = '#cbd5e1';
  ctx.strokeRect(gx, gy, gw, gh);
}

function traceWave(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number, phaseOffsetDeg: number, cycles: number, color: string, lineWidth: number) {
  ctx.beginPath();
  const n = 200;
  for (let i = 0; i <= n; i++) {
    const frac = i / n;
    const angle = frac * cycles * 2 * Math.PI + (phaseOffsetDeg * Math.PI) / 180;
    const y = gy + gh / 2 - Math.sin(angle) * (gh / 2 - 4);
    const x = gx + frac * gw;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = color; ctx.lineWidth = lineWidth; ctx.stroke();
}

export function ACCircuitCanvas({
  mode, vPeak, frequency, resistance, component, inductance, capacitance,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, vPeak, frequency, resistance, component, inductance, capacitance, isRunning, isPaused, onTick });
  sim.current = { mode, vPeak, frequency, resistance, component, inductance, capacitance, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, vPeak, frequency, resistance, component, inductance, capacitance]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 300));

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const omega = angularFrequency(s.frequency);

    if (s.mode === 'waveform') {
      // Simple resistive AC circuit: V and I in phase.
      const iPeak = s.vPeak / s.resistance;
      const wt = omega * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt);
      s.onTick?.(vNow);

      // Phasor (rotating vector) on the left — its vertical projection is
      // exactly the instantaneous value traced on the graph to the right,
      // making the link between "rotating phasor" and "sine wave" explicit.
      const pcx = W * 0.16, pcy = H / 2, pr = 55 * uiScale;
      ctx.strokeStyle = '#e2e8f0'; ctx.beginPath(); ctx.arc(pcx, pcy, pr, 0, Math.PI * 2); ctx.stroke();
      const angle = -wt; // canvas angle: negative so increasing wt rotates counterclockwise, matching sin(wt) rising
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(pcx, pcy); ctx.lineTo(pcx + Math.cos(angle) * pr, pcy + Math.sin(angle) * pr); ctx.stroke();
      ctx.setLineDash([3, 3]); ctx.strokeStyle = '#c7d2fe';
      ctx.beginPath(); ctx.moveTo(pcx + Math.cos(angle) * pr, pcy + Math.sin(angle) * pr); ctx.lineTo(pcx, pcy + Math.sin(angle) * pr); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('V, I phasor', pcx, pcy + pr + 16 * uiScale);
      ctx.fillText('(in phase)', pcx, pcy + pr + 28 * uiScale);

      const gx = W * 0.38, gy = H * 0.15, gw = W * 0.56, gh = H * 0.7;
      drawAxes(ctx, gx, gy, gw, gh);
      const cycles = 2.5;
      traceWave(ctx, gx, gy, gw, gh, -((wt * 180) / Math.PI) % 360, cycles, 'rgba(79,70,229,0.85)', 2);
      // I trace, scaled to share the same visual amplitude but tagged separately
      ctx.save(); ctx.globalAlpha = 0.7;
      traceWave(ctx, gx, gy, gw, gh, -((wt * 180) / Math.PI) % 360, cycles, '#f59e0b', 1.6);
      ctx.restore();
      // RMS reference line
      const rmsFracY = rmsFromPeak(1);
      ctx.strokeStyle = 'rgba(100,116,139,0.4)'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2 - rmsFracY * (gh / 2 - 4)); ctx.lineTo(gx + gw, gy + gh / 2 - rmsFracY * (gh / 2 - 4)); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('RMS level', gx + 4, gy + gh / 2 - rmsFracY * (gh / 2 - 4) - 4);
      ctx.fillStyle = '#4f46e5'; ctx.fillText('— V(t)', gx + gw - 90 * uiScale, gy + 12 * uiScale);
      ctx.fillStyle = '#f59e0b'; ctx.fillText('— I(t) (in phase)', gx + gw - 90 * uiScale, gy + 24 * uiScale);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(2)}A — resistor: current and voltage always in phase`, W / 2, H - 8);
    } else if (s.mode === 'reactance') {
      const isInductor = s.component === 'inductor';
      const X = isInductor ? inductiveReactance(omega, s.inductance) : capacitiveReactance(omega, s.capacitance);
      const iPeak = X > 0 ? s.vPeak / X : 0;
      // Verified: inductor -> current LAGS voltage by 90 (i = sin(wt-90));
      // capacitor -> current LEADS voltage by 90 (i = sin(wt+90)).
      const phaseShiftDeg = isInductor ? 90 : -90;
      const wt = omega * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt - (phaseShiftDeg * Math.PI) / 180);
      s.onTick?.(X);

      const pcx = W * 0.16, pcy = H / 2, pr = 55 * uiScale;
      ctx.strokeStyle = '#e2e8f0'; ctx.beginPath(); ctx.arc(pcx, pcy, pr, 0, Math.PI * 2); ctx.stroke();
      const vAngle = -wt;
      const iAngle = -wt + (phaseShiftDeg * Math.PI) / 180;
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(pcx, pcy); ctx.lineTo(pcx + Math.cos(vAngle) * pr, pcy + Math.sin(vAngle) * pr); ctx.stroke();
      ctx.strokeStyle = '#f59e0b'; ctx.lineWidth = 2.5;
      ctx.beginPath(); ctx.moveTo(pcx, pcy); ctx.lineTo(pcx + Math.cos(iAngle) * pr * 0.75, pcy + Math.sin(iAngle) * pr * 0.75); ctx.stroke();
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(isInductor ? 'ELI: V leads I' : 'ICE: I leads V', pcx, pcy + pr + 16 * uiScale);
      ctx.fillText('by 90°', pcx, pcy + pr + 28 * uiScale);

      const gx = W * 0.38, gy = H * 0.15, gw = W * 0.56, gh = H * 0.7;
      drawAxes(ctx, gx, gy, gw, gh);
      const cycles = 2.5;
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gy, gw, gh, wtDeg, cycles, 'rgba(79,70,229,0.85)', 2);
      traceWave(ctx, gx, gy, gw, gh, wtDeg - phaseShiftDeg, cycles, 'rgba(245,158,11,0.85)', 1.8);
      ctx.fillStyle = '#4f46e5'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('— V(t)', gx + gw - 90 * uiScale, gy + 12 * uiScale);
      ctx.fillStyle = '#f59e0b'; ctx.fillText(isInductor ? '— I(t) (lags)' : '— I(t) (leads)', gx + gw - 90 * uiScale, gy + 24 * uiScale);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        `${isInductor ? 'XL = ωL' : 'XC = 1/ωC'} = ${X.toFixed(1)} Ω — v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else {
      // rlc-circuit: phasor diagram + impedance triangle + resonance readout
      const XL = inductiveReactance(omega, s.inductance);
      const XC = capacitiveReactance(omega, s.capacitance);
      const Z = seriesRLCImpedance(s.resistance, XL, XC);
      const phaseDeg = seriesRLCPhaseAngleDeg(s.resistance, XL, XC);
      s.onTick?.(Z);

      const iPeak = Z > 0 ? s.vPeak / Z : 0;
      const wt = omega * t.current;
      const iNow = iPeak * Math.sin(wt - (phaseDeg * Math.PI) / 180);

      // Phasor diagram: VR along the current axis (reference), VL leading
      // 90°, VC lagging 90°, resultant V is their vector sum.
      const pcx = W * 0.22, pcy = H * 0.55, scale = Math.min(60, 55 / Math.max(s.resistance, XL, XC, 1)) * uiScale;
      const vr = s.resistance * iPeak, vl = XL * iPeak, vc = XC * iPeak;
      ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(pcx - 70 * uiScale, pcy); ctx.lineTo(pcx + 70 * uiScale, pcy); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(pcx, pcy - 70 * uiScale); ctx.lineTo(pcx, pcy + 70 * uiScale); ctx.stroke();

      const c = ctx;
      function arrow(dx: number, dy: number, color: string, label: string) {
        c.strokeStyle = color; c.lineWidth = 2.2;
        c.beginPath(); c.moveTo(pcx, pcy); c.lineTo(pcx + dx, pcy + dy); c.stroke();
        c.fillStyle = color; c.font = `${9 * uiScale}px system-ui`; c.textAlign = 'left';
        c.fillText(label, pcx + dx + 4, pcy + dy);
      }
      arrow(vr * scale, 0, '#059669', 'VR');
      arrow(0, -vl * scale, '#dc2626', 'VL');
      arrow(0, vc * scale, '#2563eb', 'VC');
      const resDx = vr * scale, resDy = -(vl - vc) * scale;
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.8;
      ctx.beginPath(); ctx.moveTo(pcx, pcy); ctx.lineTo(pcx + resDx, pcy + resDy); ctx.stroke();
      ctx.fillStyle = '#4f46e5'; ctx.font = `bold ${9 * uiScale}px system-ui`;
      ctx.fillText('V', pcx + resDx + 4, pcy + resDy);

      // Impedance triangle
      const tx = W * 0.62, ty = H * 0.3, tscale = Math.min(1.4, 90 / Math.max(s.resistance, Math.abs(XL - XC), 1)) * uiScale;
      ctx.strokeStyle = '#059669'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(tx + s.resistance * tscale, ty); ctx.stroke();
      ctx.strokeStyle = (XL - XC) >= 0 ? '#dc2626' : '#2563eb'; ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(tx + s.resistance * tscale, ty); ctx.lineTo(tx + s.resistance * tscale, ty - (XL - XC) * tscale); ctx.stroke();
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.4;
      ctx.beginPath(); ctx.moveTo(tx, ty); ctx.lineTo(tx + s.resistance * tscale, ty - (XL - XC) * tscale); ctx.stroke();
      ctx.fillStyle = '#334155'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('R', tx + (s.resistance * tscale) / 2 - 4, ty + 12 * uiScale);
      ctx.fillText('Z', tx + (s.resistance * tscale) / 2, ty - ((XL - XC) * tscale) / 2 - 4);
      ctx.fillText('X', tx + s.resistance * tscale + 4, ty - ((XL - XC) * tscale) / 2);

      const nearResonance = Math.abs(XL - XC) < Math.max(s.resistance * 0.05, 0.5);
      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        nearResonance
          ? `RESONANCE: XL ≈ XC, Z ≈ R (minimum) = ${Z.toFixed(1)}Ω, current is MAXIMUM, phase ≈ 0°`
          : `Z = ${Z.toFixed(1)}Ω, phase = ${phaseDeg.toFixed(0)}° (${phaseDeg > 0 ? 'current lags — inductive' : 'current leads — capacitive'}), i(t) = ${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    }

    rafRef.current = requestAnimationFrame(draw);
  }, []);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
