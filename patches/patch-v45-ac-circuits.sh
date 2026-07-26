#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v45: Electromagnetism part 3 of 3 -- Simple
# AC Circuits (secondary through undergraduate level) -- completes the
# full Electromagnetism module requested (Magnetic Effects of Current,
# Electromagnetic Induction, Simple AC Circuits)
#
#   Third and final page. Covers AC waveforms & RMS values (with a
#   rotating phasor whose vertical projection traces the sine wave live,
#   making the phasor-to-waveform link explicit rather than just
#   asserted), inductive/capacitive reactance ("ELI the ICE man", with
#   the 90-degree lead/lag shown on both a phasor diagram and paired
#   waveforms), and a full series RLC circuit (phasor diagram, impedance
#   triangle, and a resonance sweep).
#
#   Verified the resonance behaviour numerically before building the
#   frequency slider around it: at R=100ohm, L=0.5H, C=10uF, resonance
#   falls at ~71.2Hz, where XL=XC exactly, Z drops to exactly R=100ohm
#   (its minimum), and the phase angle is ~0 degrees -- all three
#   independent calculations agreeing at the same frequency, confirming
#   the underlying formulas are self-consistent before any UI was built
#   around them.
#
#   Verified the inductor/capacitor phase relationship directly (not from
#   memory) before implementing: at a test angle before the voltage peak,
#   the inductor's current is unambiguously negative (lagging behind) while
#   the capacitor's is unambiguously ahead of the voltage -- confirming
#   "ELI the ICE man" is implemented with the correct sign in both cases.
#
#   Caught two real bugs during development, before shipping:
#     - A TypeScript null-narrowing issue where a helper function nested
#       inside the draw loop couldn't see that the outer null-check on the
#       canvas context still applied to it -- fixed by capturing the
#       context in a separately-typed local constant.
#     - Proactively re-swept every reference inside the draw loop for the
#       same stale-closure pattern (bare prop names instead of the ref-
#       mirrored version) that caused a real bug in the previous
#       Electromagnetic Induction patch -- none found this time, confirmed
#       clean by both a targeted grep and a clean eslint pass with zero
#       exhaustive-deps warnings.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v45-ac-circuits.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v45: Electromagnetism part 3 -- Simple AC Circuits --"
mkdir -p "src/app/embed/ac-circuits" "src/app/simulations" "src/app/simulations/ac-circuits" "src/components/simulation"

echo "  -> src/components/simulation/ACCircuitCanvas.tsx"
cat > "src/components/simulation/ACCircuitCanvas.tsx" << 'AFEOF'
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
AFEOF

echo "  -> src/app/simulations/ac-circuits/page.tsx"
cat > "src/app/simulations/ac-circuits/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import {
  angularFrequency, rmsFromPeak, inductiveReactance, capacitiveReactance,
  seriesRLCImpedance, seriesRLCPhaseAngleDeg, resonantAngularFrequency,
} from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'waveform' | 'reactance' | 'rlc-circuit';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  waveform:      { title: 'AC Waveform & RMS',      icon: '〰️', sub: 'Peak vs RMS values',        eq: 'Vrms = Vpeak/√2' },
  reactance:     { title: 'Inductive & Capacitive Reactance', icon: '⏱️', sub: "'ELI the ICE man'", eq: 'XL=ωL, XC=1/ωC' },
  'rlc-circuit': { title: 'Series RLC Circuit',      icon: '📈', sub: 'Impedance & resonance',      eq: 'Z=√(R²+(XL-XC)²)' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  waveform: [
    'Alternating current (AC) reverses direction periodically, unlike DC which flows one way — mains supply is AC specifically because transformers (which only work on AC) make it far more efficient to transmit over long distances.',
    'PEAK value is the maximum instantaneous value the wave reaches; RMS (root-mean-square) is the "effective" DC-equivalent value — the steady value that would deliver the same average power to a resistor.',
    'For a sine wave, RMS = peak/√2 ≈ 0.707 × peak — this factor comes directly from averaging sin²(θ) over a full cycle, which works out to exactly 1/2.',
    'When electricians or exam questions say "230V mains" or "240V mains", that is the RMS value — the actual peak voltage reaches roughly 325-340V.',
    'Undergraduate note: average power in a resistor is P = Irms²R = Vrms²/R — using RMS values lets you apply the familiar DC power formulas directly to AC circuits without needing to integrate over a cycle each time.',
  ],
  reactance: [
    'Reactance is the AC equivalent of resistance for inductors and capacitors — it opposes current flow, measured in ohms, but (unlike resistance) it depends on frequency.',
    "Mnemonic 'ELI the ICE man': in an inductor (L), EMF (voltage) Leads Current — ELI. In a capacitor (C), Current leads EMF (voltage) — ICE.",
    'Inductive reactance XL = ωL INCREASES with frequency — an inductor increasingly opposes fast-changing current (that\u2019s exactly why it opposes the sudden current changes that create the back-EMF).',
    'Capacitive reactance XC = 1/ωC DECREASES with frequency — a capacitor charges and discharges more freely as the current reverses faster, offering less opposition.',
    'Undergraduate note: reactance doesn\u2019t dissipate energy the way resistance does — a pure inductor or capacitor stores and returns energy every half-cycle rather than converting it to heat, which is why reactance and resistance combine as a right-angled (vector) sum rather than a simple addition.',
  ],
  'rlc-circuit': [
    'A series RLC circuit combines a resistor, inductor, and capacitor — their opposition to current (R, XL, XC) combines as impedance Z = √(R² + (XL-XC)²), not a simple sum, because XL and XC act in OPPOSITE directions.',
    'The phasor diagram shows why: VR is in phase with the current (reference direction), VL leads by 90°, VC lags by 90° — so VL and VC directly cancel each other, and only their DIFFERENCE combines with VR.',
    'RESONANCE occurs when XL = XC (they cancel completely) — at this frequency, impedance is at its MINIMUM (Z = R exactly), current is at its MAXIMUM, and the circuit behaves as if it were purely resistive (phase angle = 0°).',
    'Resonant angular frequency ω₀ = 1/√(LC) — this is the exact frequency an RLC circuit "prefers", the basis of tuning a radio receiver to a specific station by adjusting L or C.',
    'Undergraduate note: away from resonance, the phase angle φ = arctan((XL-XC)/R) tells you whether the circuit is net inductive (current lags, φ>0) or net capacitive (current leads, φ<0) — and the power factor cos(φ) determines how much of VrmsIrms is actually real (usable) power versus reactive power that sloshes back and forth without doing net work.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  waveform: [
    { q: 'A UK-style AC supply has an RMS voltage of 230V. Find the peak voltage.', a: 'Vpeak = Vrms×√2 = 230×1.414 ≈ 325 V.' },
    { q: 'A sinusoidal current has a peak value of 5A. Find the RMS value and the average power delivered to a 10Ω resistor.', a: 'Irms = 5/√2 ≈ 3.54A. Average power P = Irms²R = 3.54²×10 ≈ 125 W.' },
    { q: 'Why can\u2019t you just average the instantaneous values of a sine wave to find its "effective" value?', a: 'A sine wave is positive for exactly half the cycle and negative for the other half, so the simple average is always zero — RMS instead averages the SQUARE of the values (always positive) before taking the square root, giving a meaningful non-zero effective value.' },
  ],
  reactance: [
    { q: 'Find the reactance of a 200mH inductor at a frequency of 50Hz.', a: 'XL = ωL = 2π×50×0.2 ≈ 62.8 Ω.' },
    { q: 'Find the reactance of a 20µF capacitor at 50Hz.', a: 'XC = 1/(ωC) = 1/(2π×50×20×10⁻⁶) ≈ 159.2 Ω.' },
    { q: 'As frequency increases, what happens to XL and XC, and how does that explain why a capacitor "blocks DC but passes AC"?', a: 'XL increases and XC decreases with frequency. At f=0 (DC), XC = 1/(0) → infinite — a capacitor completely blocks steady current. At high frequency, XC → 0, offering almost no opposition, so a capacitor lets rapidly alternating current pass relatively freely.' },
  ],
  'rlc-circuit': [
    { q: 'A series RLC circuit has R=50Ω, XL=120Ω, XC=40Ω. Find the impedance.', a: 'Z = √(R² + (XL-XC)²) = √(50² + 80²) = √(2500+6400) = √8900 ≈ 94.3 Ω.' },
    { q: 'For the same circuit, find the phase angle and state whether current leads or lags voltage.', a: 'φ = arctan((XL-XC)/R) = arctan(80/50) ≈ 58°. Since XL>XC, the circuit is net inductive, so CURRENT LAGS voltage by about 58°.' },
    { q: 'A series circuit has L=0.2H and C=50µF. Find the resonant frequency.', a: 'ω₀ = 1/√(LC) = 1/√(0.2×50×10⁻⁶) = 1/√(1×10⁻⁵) ≈ 316.2 rad/s. f₀ = ω₀/2π ≈ 50.3 Hz.' },
  ],
};

function Slider({ label, unit, value, min, max, step, set, color, note }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string; note?: string;
}) {
  return (
    <div className="space-y-1.5">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="text-gray-400 font-normal">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
      {note && <p className="text-[10px] text-gray-400">{note}</p>}
    </div>
  );
}

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function ACCircuitsPage() {
  const [topic, setTopic] = useState<Topic>('waveform');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [vPeak, setVPeak] = useState(20);
  const [frequency, setFrequency] = useState(2);
  const [resistance, setResistance] = useState(100);

  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance, setInductance] = useState(0.5);
  const [capacitance, setCapacitance] = useState(10); // µF, converted below

  const [rlcFrequency, setRlcFrequency] = useState(50);

  const [liveValue, setLiveValue] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  const capF = capacitance * 1e-6;
  const effFrequency = topic === 'rlc-circuit' ? rlcFrequency : frequency;
  const omega = angularFrequency(effFrequency);
  const XL = inductiveReactance(omega, inductance);
  const XC = capacitiveReactance(omega, capF);
  const Z = seriesRLCImpedance(resistance, XL, XC);
  const phaseDeg = seriesRLCPhaseAngleDeg(resistance, XL, XC);
  const omegaRes = resonantAngularFrequency(inductance, capF);
  const fRes = omegaRes / (2 * Math.PI);
  const reactanceX = component === 'inductor' ? XL : XC;

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Simple AC Circuits</h1>
              </div>
              <div className="flex gap-1.5 flex-wrap">
                {CURRICULA.map(c => (
                  <button key={c}
                    onClick={() => setActiveCurricula(p => p.includes(c) ? p.filter(x => x !== c) : [...p, c])}
                    className={`text-xs px-2.5 py-2 rounded-full border font-medium transition ${
                      activeCurricula.includes(c) ? CC[c] + ' border-transparent' : 'bg-white text-gray-400 border-gray-200'
                    }`}>{c}</button>
                ))}
              </div>
            </div>
          </div>
        </section>

        <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4 space-y-4">
          <div className="flex gap-1 bg-gray-100 p-1 rounded-xl overflow-x-auto">
            {(Object.keys(TOPIC_META) as Topic[]).map(t => (
              <button key={t} onClick={() => { setTopic(t); setOpenEx(null); }}
                className={`shrink-0 flex items-center gap-1.5 px-3 py-2 rounded-lg text-xs font-medium transition ${
                  topic === t ? 'bg-white text-indigo-700 shadow-sm' : 'text-gray-500 hover:text-gray-700'
                }`}>
                <span>{TOPIC_META[t].icon}</span><span>{TOPIC_META[t].title}</span>
              </button>
            ))}
          </div>

          <div className="flex flex-wrap items-center gap-3 rounded-xl border border-gray-200 bg-white px-4 py-2.5">
            <span className="text-xs text-gray-400">{TOPIC_META[topic].sub}</span>
            <span className="text-sm font-semibold font-mono text-gray-900">{TOPIC_META[topic].eq}</span>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-[1fr_220px] xl:grid-cols-[1fr_220px_260px] gap-4">
            <div className="space-y-3 min-w-0">
              <div ref={canvasBoxRef} className="rounded-2xl border border-gray-200 bg-white p-3 shadow-sm">
                <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
                  vPeak={vPeak} frequency={effFrequency} resistance={resistance}
                  component={component} inductance={inductance} capacitance={capF}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveValue}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/ac-circuits"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'waveform' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
                </>}

                {topic === 'reactance' && <>
                  <div className="flex gap-2">
                    {(['inductor', 'capacitor'] as const).map(c => (
                      <button key={c} onClick={() => setComponent(c)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{c}</button>
                    ))}
                  </div>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
                  {component === 'inductor'
                    ? <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#8b5cf6" />
                    : <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#8b5cf6" />}
                </>}

                {topic === 'rlc-circuit' && <>
                  <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
                  <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b"
                    note={`Resonance at ≈ ${fRes.toFixed(1)} Hz`} />
                  <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
                  <Slider label="Inductance" unit="H" value={inductance} min={0.1} max={2} step={0.1} set={setInductance} color="#dc2626" />
                  <Slider label="Capacitance" unit="µF" value={capacitance} min={1} max={50} step={1} set={setCapacitance} color="#2563eb" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'waveform' && <>
                    <StatRow label="Vrms" value={rmsFromPeak(vPeak).toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="Irms" value={rmsFromPeak(vPeak / resistance).toFixed(2)} unit="A" color="text-emerald-600" />
                    <StatRow label="Average power" value={((rmsFromPeak(vPeak) ** 2) / resistance).toFixed(2)} unit="W" color="text-amber-600" />
                    <StatRow label="v(t) now" value={liveValue.toFixed(1)} unit="V" color="text-gray-500" />
                  </>}
                  {topic === 'reactance' && <>
                    <StatRow label={component === 'inductor' ? 'XL' : 'XC'} value={reactanceX.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Peak current" value={(vPeak / reactanceX).toFixed(3)} unit="A" color="text-emerald-600" />
                    <StatRow label="Phase" value={component === 'inductor' ? 'I lags V by 90°' : 'I leads V by 90°'} unit="" color="text-amber-600" />
                  </>}
                  {topic === 'rlc-circuit' && <>
                    <StatRow label="XL" value={XL.toFixed(1)} unit="Ω" color="text-red-600" />
                    <StatRow label="XC" value={XC.toFixed(1)} unit="Ω" color="text-blue-600" />
                    <StatRow label="Impedance Z" value={Z.toFixed(1)} unit="Ω" color="text-indigo-600" />
                    <StatRow label="Phase angle" value={phaseDeg.toFixed(1)} unit="°" color="text-emerald-600" />
                    <StatRow label="Resonant f₀" value={fRes.toFixed(1)} unit="Hz" color="text-purple-600" />
                  </>}
                </div>
              </div>

              <div className="rounded-2xl border border-gray-100 bg-white p-4">
                <p className="text-xs text-gray-400 mb-2">Curriculum</p>
                <div className="flex flex-wrap gap-1.5">
                  {CURRICULA.map(c => (
                    <span key={c} className={`text-xs font-medium px-2 py-0.5 rounded-full ${
                      activeCurricula.includes(c) ? CC[c] : 'bg-gray-100 text-gray-400'
                    }`}>{c}</span>
                  ))}
                </div>
              </div>
            </div>

            <div className="space-y-3 lg:col-span-2 xl:col-span-1">
              <div className="rounded-2xl border border-amber-100 bg-amber-50 p-4">
                <p className="text-xs font-medium text-amber-700 uppercase tracking-wide mb-3">📋 Teacher notes</p>
                <ul className="space-y-2">
                  {TEACHER_NOTES[topic].map((n, i) => (
                    <li key={i} className="text-xs text-amber-900 leading-relaxed flex gap-2">
                      <span className="text-amber-400 shrink-0 mt-0.5">•</span>{n}
                    </li>
                  ))}
                </ul>
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4">
                <p className="text-xs font-medium text-gray-500 uppercase tracking-wide mb-3">✏️ Exercises</p>
                <div className="space-y-2">
                  {EXERCISES[topic].map((ex, i) => (
                    <div key={i} className="rounded-xl border border-gray-100 overflow-hidden">
                      <button onClick={() => setOpenEx(openEx === i ? null : i)}
                        className="w-full text-left px-3 py-2.5 text-xs text-gray-700 leading-relaxed hover:bg-gray-50 transition flex justify-between gap-2">
                        <span><span className="font-medium text-indigo-600">Q{i + 1}.</span> {ex.q}</span>
                        <span className="text-gray-300 shrink-0 text-sm">{openEx === i ? '▲' : '▼'}</span>
                      </button>
                      {openEx === i && (
                        <div className="px-3 py-2.5 bg-emerald-50 border-t border-gray-100 text-xs text-emerald-800 leading-relaxed">
                          <span className="font-medium">Answer: </span>{ex.a}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </>
  );
}
AFEOF

echo "  -> src/app/embed/ac-circuits/page.tsx"
cat > "src/app/embed/ac-circuits/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ACCircuitCanvas, ACMode } from '@/components/simulation/ACCircuitCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'waveform' | 'reactance' | 'rlc-circuit';

function num(sp: URLSearchParams, key: string, fallback: number, min: number, max: number) {
  const v = Number(sp.get(key));
  return Number.isFinite(v) && sp.get(key) !== null ? Math.min(max, Math.max(min, v)) : fallback;
}

function Slider({ label, unit, value, min, max, step, set, color }: {
  label: string; unit: string; value: number; min: number; max: number;
  step: number; set: (v: number) => void; color: string;
}) {
  return (
    <div className="space-y-1">
      <div className="flex justify-between text-xs">
        <span className="text-gray-500">{label}</span>
        <span className="font-medium tabular-nums text-gray-800">{value} <span className="font-normal text-gray-400">{unit}</span></span>
      </div>
      <input type="range" min={min} max={max} step={step} value={value}
        onChange={e => set(Number(e.target.value))} className="w-full" style={{ accentColor: color }} />
    </div>
  );
}

function PoweredBy() {
  return (
    <p className="text-center text-[10px] text-gray-400">
      Powered by{' '}
      <a href="/" target="_blank" rel="noopener noreferrer" className="font-medium text-indigo-500 hover:text-indigo-600">
        A-Factor STEM Studio
      </a>
    </p>
  );
}

function ACEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'reactance' || t === 'rlc-circuit' ? t : 'waveform';
  })();
  const showControls = sp.get('controls') !== '0';

  const [vPeak, setVPeak] = useState(() => num(sp, 'v', 20, 5, 50));
  const [frequency, setFrequency] = useState(() => num(sp, 'f', 2, 0.5, 5));
  const [resistance, setResistance] = useState(() => num(sp, 'r', 100, 10, 500));
  const [component, setComponent] = useState<'inductor' | 'capacitor'>('inductor');
  const [inductance] = useState(0.5);
  const [capacitance] = useState(10);
  const [rlcFrequency, setRlcFrequency] = useState(50);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, vPeak, frequency, resistance, component, inductance, capacitance, rlcFrequency, reset]);

  const effFrequency = topic === 'rlc-circuit' ? rlcFrequency : frequency;

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <ACCircuitCanvas key={resetKey} mode={topic as ACMode}
        vPeak={vPeak} frequency={effFrequency} resistance={resistance}
        component={component} inductance={inductance} capacitance={capacitance * 1e-6}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          <Slider label="Peak voltage" unit="V" value={vPeak} min={5} max={50} step={5} set={setVPeak} color="#6366f1" />
          {topic === 'waveform' && (
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={500} step={10} set={setResistance} color="#8b5cf6" />
          )}
          {topic === 'reactance' && <>
            <div className="flex gap-2">
              {(['inductor', 'capacitor'] as const).map(c => (
                <button key={c} onClick={() => setComponent(c)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    component === c ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{c}</button>
              ))}
            </div>
            <Slider label="Frequency" unit="Hz" value={frequency} min={0.5} max={5} step={0.5} set={setFrequency} color="#f59e0b" />
          </>}
          {topic === 'rlc-circuit' && <>
            <Slider label="Frequency" unit="Hz" value={rlcFrequency} min={10} max={200} step={1} set={setRlcFrequency} color="#f59e0b" />
            <Slider label="Resistance" unit="Ω" value={resistance} min={10} max={300} step={10} set={setResistance} color="#059669" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ACEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ACEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  -> src/app/simulations/page.tsx"
cat > "src/app/simulations/page.tsx" << 'AFEOF'
'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'] as const;

const SIMULATIONS = [
  {
    slug: 'projectile-motion',
    href: '/simulations/projectile-motion',
    title: 'Projectile motion',
    description: 'Launch a projectile and explore range, height, and trajectory in real time.',
    icon: '🎯',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'gas-laws',
    href: '/simulations/gas-laws',
    title: "Gas laws (Boyle & Charles)",
    description: 'Compress gas to see pressure rise. Heat it to watch volume expand.',
    icon: '🧪',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'newtons-second-law',
    href: '/simulations/newtons-laws',
    title: "Newton's 2nd law",
    description: 'Apply forces to a block and observe acceleration in real time.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'consequences-of-newtons-motion-laws',
    href: '/simulations/consequences-of-motion',
    title: "Consequences of Newton's motion laws",
    description: 'Explore inertia, momentum and action-reaction with interactive experiments.',
    icon: '🚈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'simple-harmonic-motion',
    href: '/simulations/oscillations',
    title: 'Simple harmonic motion',
    description: 'Oscillating mass-spring system with displacement, velocity and energy graphs.',
    icon: '〰️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'ohms-law',
    href: '/simulations/ohms-law',
    title: "Ohm's law & circuits",
    description: 'Adjust voltage and resistance, measure current. Build series and parallel circuits.',
    icon: '⚡',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electrostatics-charging',
    href: '/simulations/electrostatics-charging',
    title: 'Electrostatics: Charging Objects',
    description: 'Friction, conduction & induction, the gold-leaf electroscope, and the electrophorus.',
    icon: '🍂',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electrostatics-fields',
    href: '/simulations/electrostatics-fields',
    title: "Electrostatics: Coulomb's Law & Fields",
    description: 'Force between point charges, with a real release animation, plus electric field lines.',
    icon: '🧲',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electrostatics-potential',
    href: '/simulations/electrostatics-potential',
    title: 'Electrostatics: Potential & Capacitors',
    description: 'Potential energy with live KE/PE tracking, equipotential surfaces, and a charging/discharging capacitor.',
    icon: '🔋',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'magnetic-effects',
    href: '/simulations/magnetic-effects',
    title: 'Magnetic Effects of Current',
    description: "Field of a straight wire and solenoid (right-hand rule), plus the motor effect (Fleming's left-hand rule). Secondary to undergraduate level.",
    icon: '🧲',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'electromagnetic-induction',
    href: '/simulations/electromagnetic-induction',
    title: 'Electromagnetic Induction',
    description: "Faraday's and Lenz's laws with a moving magnet and galvanometer, an AC generator with a live EMF-time graph, and a transformer. Secondary to undergraduate level.",
    icon: '🔄',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'ac-circuits',
    href: '/simulations/ac-circuits',
    title: 'Simple AC Circuits',
    description: 'AC waveforms and RMS values, inductive/capacitive reactance with phasor diagrams, and a series RLC circuit with impedance triangle and resonance. Secondary to undergraduate level.',
    icon: '📈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'],
    topic: 'Electricity',
    status: 'live',
  },
  {
    slug: 'waves',
    href: '/simulations/waves',
    title: 'Wave motion',
    description: 'Visualise transverse and longitudinal waves. Explore frequency and amplitude.',
    icon: '🌊',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'diffraction',
    href: '/simulations/diffraction',
    title: 'Diffraction',
    description: 'Waves spreading through a single slit, and diffraction-grating spectral orders.',
    icon: '🌈',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'polarization',
    href: '/simulations/polarization',
    title: 'Polarization',
    description: 'Unpolarized light through a single filter, and Malus\u2019s law with two polarizers.',
    icon: '🕶️',
    tags: ['IGCSE', 'SAT', 'JUPEB'],
    topic: 'Waves',
    status: 'live',
  },
  {
    slug: 'refraction',
    href: '/simulations/refraction',
    title: 'Refraction & lenses',
    description: 'Trace light rays through convex and concave lenses. Find focal length.',
    icon: '🔭',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'reflection',
    href: '/simulations/reflection',
    title: 'Reflection',
    description: 'The law of reflection, mirror rotation (fixed source, 2θ rule), and concave/convex ray diagrams.',
    icon: '🪞',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'rectilinear-propagation',
    href: '/simulations/rectilinear-propagation',
    title: 'Sources of Light & Rectilinear Propagation',
    description: 'Shadows (umbra & penumbra), solar & lunar eclipses, and the pinhole camera.',
    icon: '🌑',
    tags: ['WAEC', 'NECO', 'IGCSE'],
    topic: 'Optics',
    status: 'live',
  },
  {
    slug: 'radioactive-decay',
    href: '/simulations/radioactive-decay',
    title: 'Radioactive decay',
    description: 'Watch nuclei decay over time. Explore half-life with live decay curves.',
    icon: '☢️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'photoelectric-effect',
    href: '/simulations/photoelectric-effect',
    title: 'Photoelectric effect',
    description: "Fire light at a metal plate and test Einstein's equation hf = φ + KEmax.",
    icon: '💡',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'de-broglie',
    href: '/simulations/de-broglie',
    title: 'De Broglie hypothesis',
    description: 'See matter waves in action: λ = h/mv for particles from electrons to cricket balls.',
    icon: '〰️',
    tags: ['IGCSE', 'JUPEB', 'SAT'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'x-rays',
    href: '/simulations/x-rays',
    title: 'X-rays',
    description: 'Explore X-ray tube production, the continuous spectrum, and the Duane–Hunt limit.',
    icon: '🩻',
    tags: ['WAEC', 'IGCSE', 'JUPEB'],
    topic: 'Modern physics',
    status: 'live',
  },
  {
    slug: 'friction',
    href: '/simulations/friction',
    title: 'Friction',
    description: 'Static vs kinetic friction on flat and inclined surfaces, with the angle of repose.',
    icon: '🧱',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'heat-transfer',
    href: '/simulations/heat-transfer',
    title: 'Modes of heat transfer',
    description: 'Conduction, convection, and radiation compared side by side with live particle animation.',
    icon: '🔥',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Thermal physics',
    status: 'live',
  },
  {
    slug: 'elasticity',
    href: '/simulations/elasticity',
    title: 'Elasticity',
    description: "Hooke's law with a loaded spring, and Young's modulus for a stretched wire.",
    icon: '🪢',
    tags: ['WAEC', 'NECO', 'IGCSE', 'SAT'],
    topic: 'Mechanics',
    status: 'live',
  },
  {
    slug: 'equilibrium-of-forces',
    href: '/simulations/equilibrium-of-forces',
    title: 'Equilibrium of forces',
    description: 'Static & dynamic equilibrium, coplanar forces, moments, and floating bodies.',
    icon: '⚖️',
    tags: ['WAEC', 'NECO', 'IGCSE', 'JUPEB'],
    topic: 'Mechanics',
    status: 'live',
  },
];

const TOPICS = ['All', 'Mechanics', 'Electricity', 'Waves', 'Optics', 'Thermal physics', 'Modern physics'];

const CURRICULUM_COLORS: Record<string, string> = {
  WAEC:  'bg-indigo-100 text-indigo-700',
  NECO:  'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700',
  SAT:   'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
  Undergraduate: 'bg-slate-200 text-slate-700',
};

export default function SimulationsPage() {
  const [selectedTopic, setSelectedTopic] = useState<string>('All');
  const visibleSims = selectedTopic === 'All'
    ? SIMULATIONS
    : SIMULATIONS.filter(sim => sim.topic === selectedTopic);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">

        {/* Hero */}
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-7xl px-4 sm:px-6 py-10 sm:py-14">
            <div className="max-w-2xl">
              <div className="mb-3 flex flex-wrap gap-2">
                {CURRICULA.map(c => (
                  <span key={c} className={`text-xs font-medium px-2.5 py-0.5 rounded-full ${CURRICULUM_COLORS[c]}`}>{c}</span>
                ))}
              </div>
              <h1 className="text-2xl sm:text-3xl font-semibold text-gray-900 leading-tight mb-3">
                Physics simulations for every curriculum
              </h1>
              <p className="text-sm sm:text-base text-gray-500 leading-relaxed">
                Interactive, AI-powered simulations built for WAEC, NECO, IGCSE, SAT and JUPEB students.
                Type a prompt or pick a topic below.
              </p>
            </div>
          </div>
        </section>

        {/* Simulations grid */}
        <section className="mx-auto max-w-7xl px-4 sm:px-6 py-8">

          {/* Topic filter — scroll on mobile */}
          <div className="flex gap-2 overflow-x-auto pb-2 mb-6 scrollbar-hide">
            {TOPICS.map(t => {
              const count = t === 'All' ? SIMULATIONS.length : SIMULATIONS.filter(sim => sim.topic === t).length;
              const active = selectedTopic === t;
              return (
                <button key={t} onClick={() => setSelectedTopic(t)}
                  className={`shrink-0 flex items-center gap-1.5 rounded-full border px-4 py-1.5 text-xs font-medium transition whitespace-nowrap ${
                    active
                      ? 'border-indigo-600 bg-indigo-600 text-white'
                      : 'border-gray-200 bg-white text-gray-600 hover:border-indigo-300 hover:text-indigo-700'
                  }`}>
                  {t}
                  <span className={`rounded-full px-1.5 text-[10px] ${active ? 'bg-white/20' : 'bg-gray-100 text-gray-400'}`}>
                    {count}
                  </span>
                </button>
              );
            })}
          </div>

          {/* Cards grid */}
          {visibleSims.length === 0 ? (
            <div className="rounded-2xl border border-dashed border-gray-200 py-16 text-center">
              <p className="text-sm text-gray-400">No simulations in {selectedTopic} yet.</p>
            </div>
          ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
            {visibleSims.map(sim => (
              <div key={sim.slug} className={`group relative rounded-2xl border bg-white overflow-hidden transition ${
                sim.status === 'live'
                  ? 'border-gray-200 hover:border-indigo-300 hover:shadow-md cursor-pointer'
                  : 'border-gray-100 opacity-70'
              }`}>
                {sim.status === 'coming' && (
                  <div className="absolute top-3 right-3 rounded-full bg-gray-100 px-2 py-0.5 text-[10px] font-medium text-gray-400">
                    Coming soon
                  </div>
                )}
                {sim.status === 'live' && (
                  <div className="absolute top-3 right-3 flex items-center gap-1">
                    <span className="h-1.5 w-1.5 rounded-full bg-emerald-500 animate-pulse"/>
                    <span className="text-[10px] font-medium text-emerald-600">Live</span>
                  </div>
                )}

                <Link href={sim.status === 'live' ? sim.href : '#'}
                  className={sim.status !== 'live' ? 'pointer-events-none' : ''}>
                  <div className="p-5">
                    {/* Icon + topic */}
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-2xl">{sim.icon}</span>
                      <span className="text-[10px] font-medium text-gray-400 uppercase tracking-wide">{sim.topic}</span>
                    </div>

                    <h3 className="text-sm font-semibold text-gray-900 mb-1.5 group-hover:text-indigo-700 transition">
                      {sim.title}
                    </h3>
                    <p className="text-xs text-gray-500 leading-relaxed mb-4">{sim.description}</p>

                    {/* Curriculum tags */}
                    <div className="flex flex-wrap gap-1">
                      {sim.tags.map(tag => (
                        <span key={tag} className={`text-[10px] font-medium px-2 py-0.5 rounded-full ${CURRICULUM_COLORS[tag]}`}>
                          {tag}
                        </span>
                      ))}
                    </div>
                  </div>

                  {sim.status === 'live' && (
                    <div className="border-t border-gray-100 px-5 py-3 flex items-center justify-between">
                      <span className="text-xs font-medium text-indigo-600">Open simulation</span>
                      <svg width="14" height="14" viewBox="0 0 14 14" fill="none" stroke="#6366f1" strokeWidth="1.5" strokeLinecap="round">
                        <path d="M2 7h10M8 3l4 4-4 4"/>
                      </svg>
                    </div>
                  )}
                </Link>
              </div>
            ))}
          </div>
          )}

          {/* Coming soon note */}
          <p className="text-center text-xs text-gray-400 mt-8">
            More simulations being added weekly. Suggest a topic at{' '}
            <a href="mailto:hello@afactor.app" className="text-indigo-500 hover:underline">hello@afactor.app</a>
          </p>
        </section>
      </main>
    </>
  );
}
AFEOF

echo ""
echo "Patch v45 applied -- 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/ac-circuits -- all three tabs:"
echo "  AC Waveform & RMS, Inductive & Capacitive Reactance, Series RLC Circuit."
echo "On the RLC tab, sweep the frequency slider across the noted resonance"
echo "point -- impedance should visibly dip to its minimum and the phase"
echo "angle should pass through zero there."
echo ""
echo "This completes the full Electromagnetism module: Magnetic Effects of"
echo "Current, Electromagnetic Induction, and Simple AC Circuits."
