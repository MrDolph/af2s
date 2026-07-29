'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg,
  parallelRLCBranchCurrents, parallelRLCTotalCurrent, parallelRLCImpedance, parallelRLCPhaseAngleDeg,
  qFactorSeries, qFactorParallel, bandwidthHz, resonantAngularFrequency,
} from '@/lib/physics/electromagnetism';

export type ACMode = 'waveform' | 'reactance' | 'series-rlc' | 'parallel-rlc' | 'resonance';

interface Props {
  mode: ACMode;
  vPeak: number;
  frequency: number;
  resistance: number;
  component: 'inductor' | 'capacitor';
  inductance: number;
  capacitance: number;
  resonanceCircuit: 'series' | 'parallel';
  speedMultiplier: number;
  phasorZoom: boolean;
  isRunning: boolean; isPaused: boolean;
  onTick?: (value: number) => void;
  width?: number; height?: number;
}

// ── Reusable circuit-symbol drawing helpers ─────────────────────────────────
// The animated phasor/waveform reference (wt) uses a FIXED visual angular
// rate, independent of the circuit's actual frequency — the RLC modes
// default to 10-200Hz, and even at the slowest speed setting that's
// 12-200+ cycles per second, an unwatchable blur no reasonable speed
// slider range could bring back to a perceivable rate. All the PHYSICS
// (XL, XC, Z, phase angles) still uses the real frequency-based omega —
// only the on-screen animation rate is decoupled from it. One cycle every
// 2 seconds at 1x speed, scaled by the speed slider from there.
const VISUAL_OMEGA = 2 * Math.PI * 0.5;

function drawResistor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, uiScale: number) {
  const n = 6, dx = (x1 - x0) / (n + 2), dy = (y1 - y0) / (n + 2);
  const perp = { x: -dy, y: dx };
  const len = Math.hypot(perp.x, perp.y) || 1;
  const amp = 7 * uiScale;
  const px = (perp.x / len) * amp, py = (perp.y / len) * amp;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(x0 + dx, y0 + dy);
  for (let i = 0; i < n; i++) {
    const sign = i % 2 === 0 ? 1 : -1;
    const cx = x0 + dx * (i + 1.5), cy = y0 + dy * (i + 1.5);
    ctx.lineTo(cx + px * sign, cy + py * sign);
  }
  ctx.lineTo(x1 - dx, y1 - dy); ctx.lineTo(x1, y1);
  ctx.stroke();
}
function drawInductor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number) {
  const n = 5, dx = (x1 - x0) / n, dy = (y1 - y0) / n;
  const r = Math.hypot(dx, dy) / 2;
  const angBase = Math.atan2(dy, dx);
  ctx.beginPath(); ctx.moveTo(x0, y0);
  for (let i = 0; i < n; i++) {
    const cx = x0 + dx * (i + 0.5), cy = y0 + dy * (i + 0.5);
    ctx.arc(cx, cy, r * 0.85, angBase + Math.PI, angBase, false);
  }
  ctx.stroke();
}
function drawCapacitor(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, s: number) {
  const mx = (x0 + x1) / 2, my = (y0 + y1) / 2;
  const dx = x1 - x0, dy = y1 - y0, len = Math.hypot(dx, dy) || 1;
  const ux = dx / len, uy = dy / len;
  const px = -uy * 10 * s, py = ux * 10 * s;
  const gap = 5 * s;
  ctx.beginPath(); ctx.moveTo(x0, y0); ctx.lineTo(mx - ux * gap, my - uy * gap); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx - ux * gap - px, my - uy * gap - py); ctx.lineTo(mx - ux * gap + px, my - uy * gap + py); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx + ux * gap - px, my + uy * gap - py); ctx.lineTo(mx + ux * gap + px, my + uy * gap + py); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(mx + ux * gap, my + uy * gap); ctx.lineTo(x1, y1); ctx.stroke();
}
function drawACSource(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, phase: number) {
  ctx.strokeStyle = '#334155'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke();
  ctx.beginPath();
  for (let i = 0; i <= 20; i++) {
    const f = i / 20;
    const x = cx - r * 0.6 + f * r * 1.2;
    const y = cy - Math.sin(f * Math.PI * 2 + phase) * r * 0.4;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.stroke();
}
function drawFlowDots(ctx: CanvasRenderingContext2D, x0: number, y0: number, x1: number, y1: number, flowFrac: number, color: string, s: number, count = 3) {
  const dx = x1 - x0, dy = y1 - y0;
  for (let i = 0; i < count; i++) {
    const base = (i + 0.5) / count;
    const local = Math.max(0.05, Math.min(0.95, base + flowFrac * (0.5 / count)));
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.arc(x0 + dx * local, y0 + dy * local, 2.6 * s, 0, Math.PI * 2); ctx.fill();
  }
}
// A single-component series loop (source -> component -> back), reused by
// the pure-R, pure-L and pure-C circuit diagrams.
function drawSingleComponentLoop(
  ctx: CanvasRenderingContext2D, x0: number, y0: number, w: number, h: number,
  kind: 'R' | 'L' | 'C', flowFrac: number, phase: number, uiScale: number, label: string,
) {
  ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
  const topY = y0, botY = y0 + h;
  ctx.beginPath(); ctx.moveTo(x0, topY); ctx.lineTo(x0 + w * 0.2, topY); ctx.stroke();
  const compColor = 'rgba(79,70,229,0.85)';
  if (kind === 'R') drawResistor(ctx, x0 + w * 0.2, topY, x0 + w * 0.8, topY, uiScale);
  else if (kind === 'L') drawInductor(ctx, x0 + w * 0.2, topY, x0 + w * 0.8, topY);
  else drawCapacitor(ctx, x0 + w * 0.2, topY, x0 + w * 0.8, topY, uiScale);
  drawFlowDots(ctx, x0 + w * 0.2, topY, x0 + w * 0.8, topY, flowFrac, compColor, uiScale);
  ctx.beginPath();
  ctx.moveTo(x0 + w * 0.8, topY); ctx.lineTo(x0 + w, topY); ctx.lineTo(x0 + w, botY);
  ctx.lineTo(x0, botY); ctx.lineTo(x0, topY);
  ctx.stroke();
  drawACSource(ctx, x0, (topY + botY) / 2, 15 * uiScale, phase);
  ctx.fillStyle = '#475569'; ctx.font = `${9.5 * uiScale}px system-ui`; ctx.textAlign = 'center';
  ctx.fillText(label, x0 + w * 0.5, topY - 15 * uiScale);
}

function drawAxes(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number) {
  ctx.strokeStyle = '#e2e8f0'; ctx.lineWidth = 1;
  ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2); ctx.lineTo(gx + gw, gy + gh / 2); ctx.stroke();
  ctx.strokeStyle = '#cbd5e1';
  ctx.strokeRect(gx, gy, gw, gh);
}
// A legend lives in its own reserved horizontal strip, entirely separate
// from the plotting area below it — never inside the axes box, where it
// would sit directly on top of whatever waveform happens to be passing
// through that same region at that moment. Verified numerically before
// this fix that a legend label placed inside the plot area does get
// crossed by the wave: at one point in the cycle the trace reaches 94%
// of its way to the top of the box, squarely where a top-corner label
// would sit.
function drawLegend(ctx: CanvasRenderingContext2D, x: number, y: number, uiScale: number, items: { color: string; label: string }[]) {
  ctx.font = `${8.5 * uiScale}px system-ui`; ctx.textBaseline = 'middle';
  let cx = x;
  items.forEach(({ color, label }) => {
    ctx.strokeStyle = color; ctx.lineWidth = 2.2;
    ctx.beginPath(); ctx.moveTo(cx, y); ctx.lineTo(cx + 14 * uiScale, y); ctx.stroke();
    ctx.fillStyle = color; ctx.textAlign = 'left';
    ctx.fillText(label, cx + 18 * uiScale, y + 0.5);
    cx += (18 + 8 * label.length + 10) * uiScale;
  });
  ctx.textBaseline = 'alphabetic';
}
function traceWave(ctx: CanvasRenderingContext2D, gx: number, gy: number, gw: number, gh: number, phaseOffsetDeg: number, ampFrac: number, cycles: number, color: string, lineWidth: number) {
  ctx.beginPath();
  const n = 160;
  for (let i = 0; i <= n; i++) {
    const frac = i / n;
    const angle = frac * cycles * 2 * Math.PI + (phaseOffsetDeg * Math.PI) / 180;
    const y = gy + gh / 2 - Math.sin(angle) * ampFrac * (gh / 2 - 4);
    const x = gx + frac * gw;
    if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
  }
  ctx.strokeStyle = color; ctx.lineWidth = lineWidth; ctx.stroke();
}

// ── Clean, reusable phasor diagram ──────────────────────────────────────────
// A shared, consistent style for every phasor plot in this canvas: faint
// circular grid at thirds, 0/90/180/270 axis lines, proper triangular
// arrowheads (not just bare lines), and labels placed just past each tip
// with a small leader offset so they don't overlap the arrow itself.
interface PhasorSpec { angleRad: number; magFrac: number; color: string; label: string; width?: number }
function drawPhasorDiagram(
  ctx: CanvasRenderingContext2D, cx: number, cy: number, maxR: number,
  phasors: PhasorSpec[], uiScale: number, title?: string,
) {
  ctx.save();
  ctx.strokeStyle = '#f1f5f9'; ctx.lineWidth = 1;
  [0.33, 0.66, 1].forEach(f => { ctx.beginPath(); ctx.arc(cx, cy, maxR * f, 0, Math.PI * 2); ctx.stroke(); });
  ctx.strokeStyle = '#e2e8f0';
  ctx.beginPath(); ctx.moveTo(cx - maxR, cy); ctx.lineTo(cx + maxR, cy); ctx.stroke();
  ctx.beginPath(); ctx.moveTo(cx, cy - maxR); ctx.lineTo(cx, cy + maxR); ctx.stroke();

  phasors.forEach(({ angleRad, magFrac, color, label, width }) => {
    const r = Math.max(0.04, Math.min(1, magFrac)) * maxR;
    const ex = cx + Math.cos(angleRad) * r, ey = cy + Math.sin(angleRad) * r;
    ctx.strokeStyle = color; ctx.lineWidth = width ?? 2.2;
    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(ex, ey); ctx.stroke();
    // Proper arrowhead
    const headLen = 7 * uiScale, headAngle = 0.45;
    ctx.save(); ctx.translate(ex, ey); ctx.rotate(angleRad);
    ctx.fillStyle = color;
    ctx.beginPath(); ctx.moveTo(0, 0);
    ctx.lineTo(-headLen * Math.cos(headAngle), -headLen * Math.sin(headAngle));
    ctx.lineTo(-headLen * Math.cos(headAngle), headLen * Math.sin(headAngle));
    ctx.closePath(); ctx.fill();
    ctx.restore();
    // Label with a short leader in the same radial direction, clear of the head
    const lx = ex + Math.cos(angleRad) * 12 * uiScale, ly = ey + Math.sin(angleRad) * 12 * uiScale;
    ctx.fillStyle = color; ctx.font = `bold ${9 * uiScale}px system-ui`;
    ctx.textAlign = Math.cos(angleRad) >= 0 ? 'left' : 'right';
    ctx.textBaseline = 'middle';
    ctx.fillText(label, lx, ly);
  });
  ctx.textBaseline = 'alphabetic';
  if (title) {
    ctx.fillStyle = '#94a3b8'; ctx.font = `${8.5 * uiScale}px system-ui`; ctx.textAlign = 'center';
    ctx.fillText(title, cx, cy + maxR + 22 * uiScale);
  }
  ctx.restore();
}

export function ACCircuitCanvas({
  mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit, speedMultiplier, phasorZoom,
  isRunning, isPaused, onTick, width = 660, height = 340,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const sim = useRef({ mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit, speedMultiplier, phasorZoom, isRunning, isPaused, onTick });
  sim.current = { mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit, speedMultiplier, phasorZoom, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, vPeak, frequency, resistance, component, inductance, capacitance, resonanceCircuit]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 340));

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) t.current += Math.min((timestamp - lastFrameRef.current) / 1000, 0.1) * s.speedMultiplier;
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const omega = angularFrequency(s.frequency);

    if (s.mode === 'waveform') {
      const iPeak = s.vPeak / s.resistance;
      const wt = VISUAL_OMEGA * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt);
      s.onTick?.(vNow);

      if (s.phasorZoom) {
        const pcx = W / 2, pcy = H * 0.48, pr = Math.min(W, H) * 0.36;
        drawPhasorDiagram(ctx, pcx, pcy, pr, [
          { angleRad: -wt, magFrac: 1, color: '#4f46e5', label: 'V, I', width: 3 },
        ], uiScale, 'in phase — zoomed');
        ctx.fillStyle = '#334155'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(`v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(2)}A`, W / 2, H - 8);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      drawSingleComponentLoop(ctx, W * 0.05, H * 0.08, W * 0.34, H * 0.3, 'R', iNow / iPeak, wt, uiScale, `R = ${s.resistance}Ω`);

      const pcx = W * 0.17, pcy = H * 0.64, pr = 0.15 * H;
      drawPhasorDiagram(ctx, pcx, pcy, pr, [
        { angleRad: -wt, magFrac: 1, color: '#4f46e5', label: 'V, I' },
      ], uiScale, 'in phase');

      const gx = W * 0.44, gw = W * 0.51;
      const gTitleY = H * 0.06, gLegendY = H * 0.105, gBoxY = H * 0.13, gBoxH = H * 0.36;
      ctx.fillStyle = '#94a3b8'; ctx.font = `${8.5 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('Voltage and current', gx, gTitleY);
      drawLegend(ctx, gx, gLegendY, uiScale, [{ color: '#4f46e5', label: 'V(t)' }, { color: '#f59e0b', label: 'I(t)' }]);
      drawAxes(ctx, gx, gBoxY, gw, gBoxH);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gBoxY, gw, gBoxH, wtDeg, 1, 2.5, 'rgba(79,70,229,0.85)', 2);
      traceWave(ctx, gx, gBoxY, gw, gBoxH, wtDeg, 1, 2.5, '#f59e0b', 1.5);
      const rmsFracY = rmsFromPeak(1);
      ctx.strokeStyle = 'rgba(100,116,139,0.4)'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(gx, gBoxY + gBoxH / 2 - rmsFracY * (gBoxH / 2 - 4)); ctx.lineTo(gx + gw, gBoxY + gBoxH / 2 - rmsFracY * (gBoxH / 2 - 4)); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = `${8 * uiScale}px system-ui`; ctx.textAlign = 'right';
      ctx.fillText('RMS', gx + gw - 2, gBoxY - 4);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(2)}A — pure resistor: current and voltage always in phase`, W / 2, H - 8);
    } else if (s.mode === 'reactance') {
      const isInductor = s.component === 'inductor';
      const X = isInductor ? inductiveReactance(omega, s.inductance) : capacitiveReactance(omega, s.capacitance);
      const iPeak = X > 0 ? s.vPeak / X : 0;
      const phaseShiftDeg = isInductor ? 90 : -90;
      const wt = VISUAL_OMEGA * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iNow = iPeak * Math.sin(wt - (phaseShiftDeg * Math.PI) / 180);
      s.onTick?.(X);

      if (s.phasorZoom) {
        const pcx = W / 2, pcy = H * 0.48, pr = Math.min(W, H) * 0.36;
        const iAngleZoom = -wt + (phaseShiftDeg * Math.PI) / 180;
        drawPhasorDiagram(ctx, pcx, pcy, pr, [
          { angleRad: -wt, magFrac: 1, color: '#4f46e5', label: 'V', width: 3 },
          { angleRad: iAngleZoom, magFrac: 0.78, color: '#f59e0b', label: 'I', width: 3 },
        ], uiScale, isInductor ? 'ELI: V leads I by 90° — zoomed' : 'ICE: I leads V by 90° — zoomed');
        ctx.fillStyle = '#334155'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(`v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(3)}A`, W / 2, H - 8);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      drawSingleComponentLoop(
        ctx, W * 0.05, H * 0.08, W * 0.34, H * 0.3, isInductor ? 'L' : 'C',
        iNow / Math.max(iPeak, 0.0001), wt, uiScale,
        isInductor ? `L = ${s.inductance}H` : `C = ${(s.capacitance * 1e6).toFixed(0)}µF`,
      );

      const pcx = W * 0.17, pcy = H * 0.64, pr = 0.15 * H;
      const iAngle = -wt + (phaseShiftDeg * Math.PI) / 180;
      drawPhasorDiagram(ctx, pcx, pcy, pr, [
        { angleRad: -wt, magFrac: 1, color: '#4f46e5', label: 'V' },
        { angleRad: iAngle, magFrac: 0.78, color: '#f59e0b', label: 'I' },
      ], uiScale, isInductor ? 'ELI: V leads I by 90°' : 'ICE: I leads V by 90°');

      const gx = W * 0.44, gw = W * 0.51;
      const gTitleY = H * 0.06, gLegendY = H * 0.105, gBoxY = H * 0.13, gBoxH = H * 0.36;
      ctx.fillStyle = '#94a3b8'; ctx.font = `${8.5 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText('Voltage and current', gx, gTitleY);
      drawLegend(ctx, gx, gLegendY, uiScale, [
        { color: '#4f46e5', label: 'V(t)' },
        { color: '#f59e0b', label: isInductor ? 'I(t) lags' : 'I(t) leads' },
      ]);
      drawAxes(ctx, gx, gBoxY, gw, gBoxH);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      traceWave(ctx, gx, gBoxY, gw, gBoxH, wtDeg, 1, 2.5, 'rgba(79,70,229,0.85)', 2);
      traceWave(ctx, gx, gBoxY, gw, gBoxH, wtDeg - phaseShiftDeg, 1, 2.5, 'rgba(245,158,11,0.85)', 1.8);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        `${isInductor ? 'XL = ωL' : 'XC = 1/ωC'} = ${X.toFixed(1)} Ω — v = ${vNow.toFixed(1)}V, i = ${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else if (s.mode === 'series-rlc') {
      const XL = inductiveReactance(omega, s.inductance);
      const XC = capacitiveReactance(omega, s.capacitance);
      const Z = seriesRLCImpedance(s.resistance, XL, XC);
      const phaseDeg = seriesRLCPhaseAngleDeg(s.resistance, XL, XC);
      s.onTick?.(Z);
      const iPeak = Z > 0 ? s.vPeak / Z : 0;
      const wt = VISUAL_OMEGA * t.current;
      const iNow = iPeak * Math.sin(wt - (phaseDeg * Math.PI) / 180);
      const vNow = s.vPeak * Math.sin(wt);
      const vrPeak = s.resistance * iPeak, vlPeak = XL * iPeak, vcPeak = XC * iPeak;
      const maxCompV = Math.max(vrPeak, vlPeak, vcPeak, 0.001);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      const iOffsetDeg = wtDeg - phaseDeg;
      const iAngleRad = -wt + (phaseDeg * Math.PI) / 180;
      // Component colours are chosen to stay visually distinct from V
      // (indigo) and I (amber) — VC was previously blue, too close to
      // indigo at a glance; fuchsia reads clearly differently.
      const colR = '#059669', colL = '#dc2626', colC = '#c026d3', colV = '#4f46e5', colI = '#f59e0b';

      if (s.phasorZoom) {
        // Zoomed view: the phasor diagram alone, using most of the canvas.
        const pcx = W / 2, pcy = H * 0.48, pr = Math.min(W, H) * 0.36;
        drawPhasorDiagram(ctx, pcx, pcy, pr, [
          { angleRad: iAngleRad, magFrac: vrPeak / maxCompV, color: colR, label: 'VR' },
          { angleRad: iAngleRad - Math.PI / 2, magFrac: vlPeak / maxCompV, color: colL, label: 'VL' },
          { angleRad: iAngleRad + Math.PI / 2, magFrac: vcPeak / maxCompV, color: colC, label: 'VC' },
          { angleRad: -wt, magFrac: s.vPeak / maxCompV, color: colV, label: 'V', width: 3 },
        ], uiScale, 'VR, VL, VC & resultant V — zoomed');
        ctx.fillStyle = '#334155'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(`φ = ${phaseDeg.toFixed(1)}° — ${phaseDeg > 0 ? 'current lags (inductive)' : phaseDeg < 0 ? 'current leads (capacitive)' : 'in phase (resonance)'}`, W / 2, H - 8);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      const cx0 = W * 0.04, cy0 = H * 0.12, cw = W * 0.36, ch = H * 0.24;
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
      const flowFrac = iNow / Math.max(iPeak, 0.0001);
      const segColor = 'rgba(79,70,229,0.85)';
      ctx.beginPath(); ctx.moveTo(cx0, cy0); ctx.lineTo(cx0, cy0 - 14 * uiScale); ctx.lineTo(cx0 + cw * 0.15, cy0 - 14 * uiScale); ctx.stroke();
      drawResistor(ctx, cx0 + cw * 0.15, cy0 - 14 * uiScale, cx0 + cw * 0.42, cy0 - 14 * uiScale, uiScale);
      drawFlowDots(ctx, cx0 + cw * 0.15, cy0 - 14 * uiScale, cx0 + cw * 0.42, cy0 - 14 * uiScale, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw * 0.42, cy0 - 14 * uiScale); ctx.lineTo(cx0 + cw * 0.55, cy0 - 14 * uiScale); ctx.stroke();
      drawInductor(ctx, cx0 + cw * 0.55, cy0 - 14 * uiScale, cx0 + cw * 0.78, cy0 - 14 * uiScale);
      drawFlowDots(ctx, cx0 + cw * 0.55, cy0 - 14 * uiScale, cx0 + cw * 0.78, cy0 - 14 * uiScale, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw * 0.78, cy0 - 14 * uiScale); ctx.lineTo(cx0 + cw, cy0 - 14 * uiScale); ctx.lineTo(cx0 + cw, cy0); ctx.stroke();
      drawCapacitor(ctx, cx0 + cw, cy0, cx0 + cw, cy0 + ch, uiScale);
      drawFlowDots(ctx, cx0 + cw, cy0, cx0 + cw, cy0 + ch, flowFrac, segColor, uiScale);
      ctx.beginPath(); ctx.moveTo(cx0 + cw, cy0 + ch); ctx.lineTo(cx0, cy0 + ch); ctx.lineTo(cx0, cy0); ctx.stroke();
      drawACSource(ctx, cx0, (cy0 + cy0 + ch) / 2, 14 * uiScale, wt);
      ctx.fillStyle = '#475569'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      // Label offsets verified numerically to clear the (now properly
      // uiScale-aware) component shapes at every canvas size, from a
      // 300px mobile width up to a 980px desktop one — the labels were
      // previously getting visually covered by the resistor/inductor
      // zigzag and the capacitor's own plate width on smaller screens.
      ctx.fillText('R', cx0 + cw * 0.285, cy0 - 26 * uiScale);
      ctx.fillText('L', cx0 + cw * 0.665, cy0 - 26 * uiScale);
      ctx.fillText('C', cx0 + cw + 20 * uiScale, cy0 + ch / 2);

      const pcx = W * 0.15, pcy = H * 0.64, pr = 0.15 * H;
      // VR, VL, VC are all referenced to the CURRENT's phase (iAngleRad),
      // not the raw source-voltage angle — VR is in phase with i, VL
      // leads i by 90°, VC lags i by 90°. Verified numerically that
      // vR(t)+vL(t)+vC(t) reconstructs v(t) exactly at every instant only
      // when referenced this way (KVL), not when anchored to v(t) directly.
      drawPhasorDiagram(ctx, pcx, pcy, pr, [
        { angleRad: iAngleRad, magFrac: vrPeak / maxCompV, color: colR, label: 'VR' },
        { angleRad: iAngleRad - Math.PI / 2, magFrac: vlPeak / maxCompV, color: colL, label: 'VL' },
        { angleRad: iAngleRad + Math.PI / 2, magFrac: vcPeak / maxCompV, color: colC, label: 'VC' },
        { angleRad: -wt, magFrac: s.vPeak / maxCompV, color: colV, label: 'V', width: 2.8 },
      ], uiScale, 'VR, VL, VC & resultant V');

      // Graph 1 (primary): total V and total I together — the headline
      // relationship. Title, then a dedicated legend row, THEN the plot
      // box — the legend never sits inside the box where waveform data
      // is drawn (verified numerically before this fix that it would
      // otherwise get crossed by the wave at some point in the cycle).
      const gx = W * 0.5, gw = W * 0.46;
      const g1TitleY = H * 0.04, g1LegendY = H * 0.075, g1BoxY = H * 0.095, g1BoxH = H * 0.145;
      ctx.font = `${8 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillStyle = '#94a3b8'; ctx.fillText('Total V(t) and I(t)', gx, g1TitleY);
      drawLegend(ctx, gx, g1LegendY, uiScale, [{ color: colV, label: 'V' }, { color: colI, label: 'I' }]);
      drawAxes(ctx, gx, g1BoxY, gw, g1BoxH);
      traceWave(ctx, gx, g1BoxY, gw, g1BoxH, wtDeg, 1, 2, colV, 1.8);
      traceWave(ctx, gx, g1BoxY, gw, g1BoxH, iOffsetDeg, iPeak > 0 ? 1 : 0, 2, colI, 1.6);

      // Graph 2 (secondary): the component voltage breakdown, same
      // colours as the phasor diagram above, same legend-outside-the-box pattern.
      const g2TitleY = H * 0.29, g2LegendY = H * 0.325, g2BoxY = H * 0.345, g2BoxH = H * 0.145;
      ctx.fillStyle = '#94a3b8'; ctx.fillText('Component voltages', gx, g2TitleY);
      drawLegend(ctx, gx, g2LegendY, uiScale, [{ color: colR, label: 'VR' }, { color: colL, label: 'VL' }, { color: colC, label: 'VC' }]);
      drawAxes(ctx, gx, g2BoxY, gw, g2BoxH);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, iOffsetDeg, vrPeak / maxCompV, 2, colR, 1.4);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, iOffsetDeg + 90, vlPeak / maxCompV, 2, colL, 1.4);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, iOffsetDeg - 90, vcPeak / maxCompV, 2, colC, 1.4);

      const nearResonance = Math.abs(XL - XC) < Math.max(s.resistance * 0.05, 0.5);
      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        nearResonance
          ? `RESONANCE: Z ≈ R (minimum) = ${Z.toFixed(1)}Ω — current is MAXIMUM, phase ≈ 0°`
          : `Z=${Z.toFixed(1)}Ω, φ=${phaseDeg.toFixed(0)}° — v=${vNow.toFixed(1)}V, i=${iNow.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else if (s.mode === 'parallel-rlc') {
      const XL = inductiveReactance(omega, s.inductance);
      const XC = capacitiveReactance(omega, s.capacitance);
      const { iR, iL, iC } = parallelRLCBranchCurrents(s.vPeak, s.resistance, XL, XC);
      const iTotal = parallelRLCTotalCurrent(s.vPeak, s.resistance, XL, XC);
      const Z = parallelRLCImpedance(s.vPeak, s.resistance, XL, XC);
      const phaseDeg = parallelRLCPhaseAngleDeg(s.resistance, XL, XC);
      s.onTick?.(Z);
      const wt = VISUAL_OMEGA * t.current;
      const vNow = s.vPeak * Math.sin(wt);
      const iRNow = iR * Math.sin(wt);
      const iLNow = iL * Math.sin(wt - Math.PI / 2);
      const iCNow = iC * Math.sin(wt + Math.PI / 2);
      const maxCompI = Math.max(iR, iL, iC, 0.0001);
      const wtDeg = -((wt * 180) / Math.PI) % 360;
      const colR = '#059669', colL = '#dc2626', colC = '#c026d3', colV = '#4f46e5', colI = '#f59e0b';

      if (s.phasorZoom) {
        const pcx = W / 2, pcy = H * 0.48, pr = Math.min(W, H) * 0.36;
        drawPhasorDiagram(ctx, pcx, pcy, pr, [
          { angleRad: -wt, magFrac: iR / maxCompI, color: colR, label: 'IR' },
          { angleRad: -wt + Math.PI / 2, magFrac: iL / maxCompI, color: colL, label: 'IL' },
          { angleRad: -wt - Math.PI / 2, magFrac: iC / maxCompI, color: colC, label: 'IC' },
          { angleRad: -wt - (phaseDeg * Math.PI) / 180, magFrac: iTotal / maxCompI, color: colV, label: 'I', width: 3 },
        ], uiScale, 'IR, IL, IC & resultant I — zoomed');
        ctx.fillStyle = '#334155'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(`φ = ${phaseDeg.toFixed(1)}° — ${phaseDeg > 0 ? 'current leads (capacitive)' : phaseDeg < 0 ? 'current lags (inductive)' : 'in phase (resonance)'}`, W / 2, H - 8);
        rafRef.current = requestAnimationFrame(draw);
        return;
      }

      const cx0 = W * 0.04, cx1 = W * 0.36, cyTop = H * 0.06, cyBot = H * 0.3;
      ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
      ctx.beginPath(); ctx.moveTo(cx0, cyTop); ctx.lineTo(cx1, cyTop); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx0, cyBot); ctx.lineTo(cx1, cyBot); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(cx0, cyTop); ctx.lineTo(cx0, cyBot); ctx.stroke();
      drawACSource(ctx, cx0, (cyTop + cyBot) / 2, 13 * uiScale, wt);

      const branchXs = [cx1 - (cx1 - cx0) * 0.62, cx1 - (cx1 - cx0) * 0.36, cx1 - (cx1 - cx0) * 0.1];
      const iPeakMax = Math.max(iR, iL, iC, 0.0001);
      ([
        { x: branchXs[0], kind: 'R' as const, flow: iRNow / iPeakMax, label: 'R' },
        { x: branchXs[1], kind: 'L' as const, flow: iLNow / iPeakMax, label: 'L' },
        { x: branchXs[2], kind: 'C' as const, flow: iCNow / iPeakMax, label: 'C' },
      ]).forEach(({ x, kind, flow, label }) => {
        ctx.strokeStyle = '#334155'; ctx.lineWidth = 1.6;
        ctx.beginPath(); ctx.moveTo(x, cyTop); ctx.lineTo(x, cyTop + 12 * uiScale); ctx.stroke();
        if (kind === 'R') drawResistor(ctx, x, cyTop + 12 * uiScale, x, cyBot - 12 * uiScale, uiScale);
        else if (kind === 'L') drawInductor(ctx, x, cyTop + 12 * uiScale, x, cyBot - 12 * uiScale);
        else drawCapacitor(ctx, x, cyTop + 12 * uiScale, x, cyBot - 12 * uiScale, uiScale);
        drawFlowDots(ctx, x, cyTop + 12 * uiScale, x, cyBot - 12 * uiScale, flow, 'rgba(79,70,229,0.85)', uiScale, 2);
        ctx.beginPath(); ctx.moveTo(x, cyBot - 12 * uiScale); ctx.lineTo(x, cyBot); ctx.stroke();
        ctx.fillStyle = '#475569'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(label, x, cyTop + 8 * uiScale);
      });

      const pcx = W * 0.15, pcy = H * 0.64, pr = 0.15 * H;
      drawPhasorDiagram(ctx, pcx, pcy, pr, [
        { angleRad: -wt, magFrac: iR / maxCompI, color: colR, label: 'IR' },
        { angleRad: -wt + Math.PI / 2, magFrac: iL / maxCompI, color: colL, label: 'IL' },
        { angleRad: -wt - Math.PI / 2, magFrac: iC / maxCompI, color: colC, label: 'IC' },
        { angleRad: -wt - (phaseDeg * Math.PI) / 180, magFrac: iTotal / maxCompI, color: colV, label: 'I', width: 2.8 },
      ], uiScale, 'IR, IL, IC & resultant I');

      // Graph 1 (primary): total V and total I together. Legend sits in
      // its own reserved row, never inside the plot box.
      const gx = W * 0.5, gw = W * 0.46;
      const g1TitleY = H * 0.04, g1LegendY = H * 0.075, g1BoxY = H * 0.095, g1BoxH = H * 0.145;
      ctx.font = `${8 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillStyle = '#94a3b8'; ctx.fillText('Total V(t) and I(t)', gx, g1TitleY);
      drawLegend(ctx, gx, g1LegendY, uiScale, [{ color: colV, label: 'V' }, { color: colI, label: 'I' }]);
      drawAxes(ctx, gx, g1BoxY, gw, g1BoxH);
      traceWave(ctx, gx, g1BoxY, gw, g1BoxH, wtDeg, 1, 2, colV, 1.8);
      traceWave(ctx, gx, g1BoxY, gw, g1BoxH, wtDeg + phaseDeg, iTotal > 0 ? 1 : 0, 2, colI, 1.6);

      // Graph 2 (secondary): the branch-current breakdown, same colours
      // as the phasor diagram above.
      const g2TitleY = H * 0.29, g2LegendY = H * 0.325, g2BoxY = H * 0.345, g2BoxH = H * 0.145;
      ctx.fillStyle = '#94a3b8'; ctx.fillText('Branch currents', gx, g2TitleY);
      drawLegend(ctx, gx, g2LegendY, uiScale, [{ color: colR, label: 'IR' }, { color: colL, label: 'IL' }, { color: colC, label: 'IC' }]);
      drawAxes(ctx, gx, g2BoxY, gw, g2BoxH);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, wtDeg, iR / maxCompI, 2, colR, 1.4);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, wtDeg - 90, iL / maxCompI, 2, colL, 1.4);
      traceWave(ctx, gx, g2BoxY, gw, g2BoxH, wtDeg + 90, iC / maxCompI, 2, colC, 1.4);

      const nearResonance = Math.abs(iL - iC) < Math.max(iR * 0.05, 0.001);
      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        nearResonance
          ? `RESONANCE: IL ≈ IC (cancel) — line current is MINIMUM, Z ≈ R (maximum) = ${Z.toFixed(0)}Ω`
          : `Z=${Z.toFixed(0)}Ω, φ=${phaseDeg.toFixed(0)}° — v=${vNow.toFixed(1)}V, I_total=${iTotal.toFixed(3)}A`,
        W / 2, H - 8,
      );
    } else {
      const isSeries = s.resonanceCircuit === 'series';
      const omega0 = resonantAngularFrequency(s.inductance, s.capacitance);
      const f0 = omega0 / (2 * Math.PI);
      const Q = isSeries ? qFactorSeries(s.resistance, s.inductance, s.capacitance) : qFactorParallel(s.resistance, s.inductance, s.capacitance);
      const bw = bandwidthHz(f0, Q);
      s.onTick?.(Q);

      const fMin = Math.max(0.5, f0 - bw * 2.2), fMax = f0 + bw * 2.2;
      const gx = W * 0.1, gy = H * 0.14, gw = W * 0.8, gh = H * 0.56;
      drawAxes(ctx, gx, gy, gw, gh);

      function responseAt(f: number) {
        const om = angularFrequency(f);
        const xl = inductiveReactance(om, s.inductance), xc = capacitiveReactance(om, s.capacitance);
        if (isSeries) {
          const z = seriesRLCImpedance(s.resistance, xl, xc);
          return z > 0 ? s.vPeak / z : 0;
        }
        return parallelRLCImpedance(s.vPeak, s.resistance, xl, xc);
      }
      const peakVal = responseAt(f0);
      const n = 160;
      ctx.beginPath();
      for (let i = 0; i <= n; i++) {
        const f = fMin + (i / n) * (fMax - fMin);
        const val = responseAt(f) / peakVal;
        const x = gx + (i / n) * gw;
        const y = gy + gh - val * (gh - 6);
        if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
      }
      ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 2.2; ctx.stroke();

      const halfY = gy + gh - (1 / Math.SQRT2) * (gh - 6);
      ctx.strokeStyle = 'rgba(100,116,139,0.5)'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(gx, halfY); ctx.lineTo(gx + gw, halfY); ctx.stroke();
      ctx.setLineDash([]);
      [f0 - bw / 2, f0 + bw / 2].forEach(f => {
        const x = gx + ((f - fMin) / (fMax - fMin)) * gw;
        ctx.strokeStyle = '#f59e0b'; ctx.setLineDash([3, 3]);
        ctx.beginPath(); ctx.moveTo(x, gy); ctx.lineTo(x, gy + gh); ctx.stroke();
        ctx.setLineDash([]);
      });
      const x0x = gx + ((f0 - fMin) / (fMax - fMin)) * gw;
      ctx.strokeStyle = 'rgba(220,38,38,0.5)'; ctx.setLineDash([2, 3]);
      ctx.beginPath(); ctx.moveTo(x0x, gy); ctx.lineTo(x0x, gy + gh); ctx.stroke();
      ctx.setLineDash([]);

      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(isSeries ? 'Current I (normalised)' : 'Impedance Z (normalised)', gx + gw / 2, gy - 6);
      ctx.fillStyle = '#dc2626'; ctx.textAlign = 'left'; ctx.fillText(`f₀=${f0.toFixed(1)}Hz`, x0x + 4, gy + gh - 6);
      ctx.fillStyle = '#f59e0b'; ctx.fillText(`half-power (1/√2)`, gx + 6, halfY - 4);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(
        `${isSeries ? 'Series' : 'Parallel'} RLC — Q = ${Q.toFixed(2)}, bandwidth = ${bw.toFixed(1)}Hz (f₁=${(f0 - bw / 2).toFixed(1)}Hz, f₂=${(f0 + bw / 2).toFixed(1)}Hz)`,
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
