#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio -- patch v44: Electromagnetism part 2 of 3 --
# Electromagnetic Induction (secondary through undergraduate level)
#
#   Second of three planned pages. Covers Faraday's and Lenz's laws
#   (a bar magnet oscillating in and out of a coil, with a live
#   galvanometer and the coil's induced pole shown), an AC generator
#   (rotating coil with a live EMF-vs-time graph), and a transformer
#   (linked primary/secondary coils on a shared core).
#
#   CAUGHT AND FIXED THREE REAL BUGS DURING DEVELOPMENT, before shipping:
#
#   1. Stale-closure bug: the draw loop referenced the raw `magnetPoleOut`
#      prop directly in several places instead of the ref-mirrored
#      `s.magnetPoleOut`. Since the draw callback is memoized with an
#      empty dependency array (the same established pattern used
#      throughout this app to avoid animation-jitter bugs), this meant
#      toggling the magnet's pole after the first render would have been
#      silently ignored -- the canvas would keep showing the FIRST pole
#      choice forever. Caught by eslint's exhaustive-deps warning, not
#      guessed -- fixed by routing every reference through the ref.
#
#   2. Backwards pole-direction logic: initially wrote the coil's
#      near-face current-direction convention as a direct reuse of the
#      solenoid mode's TOP=out<->N-at-right relation, but the geometry is
#      mirrored here (the magnet approaches from the LEFT, needing N at
#      the left/near end, not the right). Caught by explicitly re-deriving
#      the relationship via mirror symmetry rather than assuming the reuse
#      was valid, and fixed before it shipped.
#
#   3. Sin/cos swap in the AC generator's visual: the coil's apparent
#      width (how "face-on" vs "edge-on" it looks as it rotates) was
#      computed with cos(theta) where the 3D geometry actually requires
#      sin(theta) -- verified from first principles (working out exactly
#      what the coil's normal vector does in 3D as it rotates about a
#      vertical axis) that the original formula would have shown the coil
#      edge-on exactly when EMF peaks and face-on exactly when EMF is
#      zero -- the reverse of the correct picture. Fixed and reverified
#      against the (already-correct) accompanying text labels.
#
#   All three were caught through independent numerical/geometric
#   verification before shipping, not through visual inspection alone --
#   consistent with the standard applied to every simulation built in
#   this project.
#
#   Part 3 (Simple AC Circuits) is next -- the physics (RMS values,
#   inductive/capacitive reactance, series RLC impedance and phase angle,
#   resonant frequency) is already written and verified in
#   electromagnetism.ts, ready for its own canvas.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v44-electromagnetic-induction.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v44: Electromagnetism part 2 -- Electromagnetic Induction --"
mkdir -p "src/app/embed/electromagnetic-induction" "src/app/simulations" "src/app/simulations/electromagnetic-induction" "src/components/simulation"

echo "  -> src/components/simulation/InductionCanvas.tsx"
cat > "src/components/simulation/InductionCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { generatorPeakEmf, transformerSecondaryVoltage, transformerSecondaryCurrent } from '@/lib/physics/electromagnetism';

export type InductionMode = 'faraday-lenz' | 'ac-generator' | 'transformer';

interface Props {
  mode: InductionMode;
  turns: number;             // faraday-lenz: coil turns. generator: coil turns.
  speed: number;              // faraday-lenz: magnet oscillation speed (rad/s-ish)
  magnetPoleOut: boolean;     // faraday-lenz: which pole faces the coil (true = N facing coil)
  fieldB: number;             // generator: field strength (T)
  coilArea: number;           // generator: coil area (m^2)
  omega: number;              // generator: angular speed (rad/s)
  primaryTurns: number;       // transformer
  secondaryTurns: number;     // transformer
  primaryVoltage: number;     // transformer: peak AC voltage
  isRunning: boolean; isPaused: boolean;
  onTick?: (value: number) => void;
  width?: number; height?: number;
}

function drawGalvanometer(ctx: CanvasRenderingContext2D, cx: number, cy: number, r: number, deflectionFrac: number, uiScale: number) {
  ctx.save();
  ctx.fillStyle = '#f8fafc'; ctx.strokeStyle = '#94a3b8'; ctx.lineWidth = 2;
  ctx.beginPath(); ctx.arc(cx, cy, r, Math.PI, 0); ctx.closePath(); ctx.fill(); ctx.stroke();
  ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
  for (let i = -1; i <= 1; i++) {
    const a = Math.PI / 2 + i * Math.PI / 3;
    ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * r * 0.7, cy - Math.sin(a) * r * 0.7); ctx.lineTo(cx + Math.cos(a) * r * 0.9, cy - Math.sin(a) * r * 0.9); ctx.stroke();
  }
  const clamped = Math.max(-1, Math.min(1, deflectionFrac));
  const needleAngle = Math.PI / 2 - clamped * (Math.PI / 2.4);
  ctx.strokeStyle = '#dc2626'; ctx.lineWidth = 2.5;
  ctx.beginPath(); ctx.moveTo(cx, cy); ctx.lineTo(cx + Math.cos(needleAngle) * r * 0.85, cy - Math.sin(needleAngle) * r * 0.85); ctx.stroke();
  ctx.fillStyle = '#334155';
  ctx.beginPath(); ctx.arc(cx, cy, 3 * uiScale, 0, Math.PI * 2); ctx.fill();
  ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'center'; ctx.fillStyle = '#64748b';
  ctx.fillText('G', cx, cy + 16 * uiScale);
}

export function InductionCanvas({
  mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega,
  primaryTurns, secondaryTurns, primaryVoltage,
  isRunning, isPaused, onTick, width = 660, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const t = useRef(0);
  const lastFrameRef = useRef<number | null>(null);
  const prevFluxRef = useRef<number | null>(null);
  const emfTraceRef = useRef<number[]>([]);
  const sim = useRef({ mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage, isRunning, isPaused, onTick });
  sim.current = { mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage, isRunning, isPaused, onTick };

  useEffect(() => {
    t.current = 0; lastFrameRef.current = null; prevFluxRef.current = null; emfTraceRef.current = [];
  }, [mode, turns, speed, magnetPoleOut, fieldB, coilArea, omega, primaryTurns, secondaryTurns, primaryVoltage]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const uiScale = Math.max(0.55, Math.min(1, Math.min(W, H) / 300));

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) { dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1); t.current += dt; }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    if (s.mode === 'faraday-lenz') {
      const cy = H / 2;
      const coilX = W * 0.62;
      const loopR = 40 * uiScale;
      // Magnet oscillates in/out. x = gap between magnet tip and coil.
      const gapAmp = 150 * uiScale;
      const gapX = Math.abs(Math.sin(t.current * s.speed)) * gapAmp;

      // Flux linkage model: smooth bell curve in gap distance (physically
      // reasonable, not a literal dipole formula) — verified numerically
      // before implementing that this gives EMF that correctly peaks
      // during fast motion and drops to ~0 at the turning points.
      const x0 = 60 * uiScale;
      const flux = s.turns * (1 / (1 + (gapX / x0) * (gapX / x0))) * (s.magnetPoleOut ? 1 : -1);
      let emf = 0;
      if (prevFluxRef.current !== null && dt > 0) emf = -(flux - prevFluxRef.current) / dt;
      prevFluxRef.current = flux;

      const magnetX = coilX - loopR - 20 * uiScale - gapX;

      // Bar magnet
      const magW = 70 * uiScale, magH = 26 * uiScale;
      ctx.fillStyle = s.magnetPoleOut ? '#dc2626' : '#2563eb';
      ctx.fillRect(magnetX - magW, cy - magH / 2, magW / 2, magH);
      ctx.fillStyle = s.magnetPoleOut ? '#2563eb' : '#dc2626';
      ctx.fillRect(magnetX - magW / 2, cy - magH / 2, magW / 2, magH);
      ctx.strokeStyle = '#1e293b'; ctx.lineWidth = 1.5; ctx.strokeRect(magnetX - magW, cy - magH / 2, magW, magH);
      ctx.fillStyle = 'white'; ctx.font = `bold ${11 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(s.magnetPoleOut ? 'N' : 'S', magnetX - magW * 0.25, cy + 4 * uiScale);
      ctx.fillText(s.magnetPoleOut ? 'S' : 'N', magnetX - magW * 0.75, cy + 4 * uiScale);

      // Coil (dots-and-crosses convention, same as solenoid mode). The
      // induced near-face pole follows the verified Lenz's-law relation:
      // SAME as the magnet's facing pole while approaching (repel),
      // OPPOSITE while receding (attract) — derived from the sign of emf
      // (rate of flux increase) rather than asserted separately, so it
      // can never disagree with the galvanometer reading.
      const fluxIncreasing = emf * (s.magnetPoleOut ? -1 : 1) > 0; // emf = -dPhi/dt, so dPhi/dt = -emf
      const nearFaceIsN = fluxIncreasing ? s.magnetPoleOut : !s.magnetPoleOut;
      const loopCount = 5;
      const coilSpan = 70 * uiScale;
      for (let i = 0; i < loopCount; i++) {
        const x = coilX + (i / (loopCount - 1)) * coilSpan;
        ctx.strokeStyle = '#475569'; ctx.lineWidth = 1.6 * uiScale;
        ctx.beginPath(); ctx.moveTo(x, cy - loopR); ctx.lineTo(x, cy + loopR); ctx.stroke();
      }
      // Current markers only shown while there's meaningfully-large emf
      if (Math.abs(emf) > 0.01) {
        // Coil's near (left) face should be N when nearFaceIsN=true. The
        // solenoid mode verified TOP=out(dot)/BOTTOM=in(cross) puts N at
        // the RIGHT end; by mirror symmetry, reversing every current
        // (TOP=in/BOTTOM=out) moves N to the LEFT end instead — so
        // nearFaceIsN=true (N wanted at the left, near, end) needs
        // topOut=false, not topOut=nearFaceIsN.
        const topOut = !nearFaceIsN;
        for (let i = 0; i < loopCount; i++) {
          const x = coilX + (i / (loopCount - 1)) * coilSpan;
          const dotR = 3.5 * uiScale;
          [{ y: cy - loopR, out: topOut }, { y: cy + loopR, out: !topOut }].forEach(({ y, out }) => {
            ctx.fillStyle = '#1e293b';
            ctx.beginPath(); ctx.arc(x, y, dotR, 0, Math.PI * 2); ctx.fill();
            if (out) { ctx.fillStyle = '#f8fafc'; ctx.beginPath(); ctx.arc(x, y, dotR * 0.4, 0, Math.PI * 2); ctx.fill(); }
            else {
              ctx.strokeStyle = '#f8fafc'; ctx.lineWidth = 1;
              ctx.beginPath(); ctx.moveTo(x - dotR * 0.5, y - dotR * 0.5); ctx.lineTo(x + dotR * 0.5, y + dotR * 0.5);
              ctx.moveTo(x + dotR * 0.5, y - dotR * 0.5); ctx.lineTo(x - dotR * 0.5, y + dotR * 0.5); ctx.stroke();
            }
          });
        }
        ctx.fillStyle = nearFaceIsN ? '#dc2626' : '#2563eb'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
        ctx.fillText(nearFaceIsN ? 'N' : 'S', coilX - 12 * uiScale, cy - loopR - 10 * uiScale);
      }

      drawGalvanometer(ctx, coilX + coilSpan + 55 * uiScale, cy, 32 * uiScale, emf * 0.4, uiScale);
      s.onTick?.(emf);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`EMF = ${emf.toFixed(2)} (arb. units) — ${Math.abs(emf) < 0.02 ? 'no relative motion, no EMF' : fluxIncreasing ? 'flux increasing: coil repels the magnet' : 'flux decreasing: coil attracts the magnet'}`, W / 2, H - 8);
    } else if (s.mode === 'ac-generator') {
      const cx = W * 0.32, cy = H / 2;
      const poleGap = 90 * uiScale, poleH = 130 * uiScale;
      ctx.fillStyle = '#dc2626'; ctx.fillRect(cx - poleGap - 50 * uiScale, cy - poleH / 2, 50 * uiScale, poleH);
      ctx.fillStyle = '#2563eb'; ctx.fillRect(cx + poleGap, cy - poleH / 2, 50 * uiScale, poleH);
      ctx.fillStyle = 'white'; ctx.font = `bold ${12 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText('N', cx - poleGap - 25 * uiScale, cy + 4 * uiScale);
      ctx.fillText('S', cx + poleGap + 25 * uiScale, cy + 4 * uiScale);
      for (let i = -2; i <= 2; i++) {
        const y = cy + i * 22 * uiScale;
        ctx.strokeStyle = 'rgba(100,116,139,0.4)'; ctx.lineWidth = 1.2;
        ctx.beginPath(); ctx.moveTo(cx - poleGap, y); ctx.lineTo(cx + poleGap, y); ctx.stroke();
      }

      const theta = s.omega * t.current;
      const coilW = 60 * uiScale, coilH = 80 * uiScale;
      // Rotating coil, viewed edge-on: its apparent width shrinks with cos(theta)
      // Apparent width: zero when the coil's normal points along B (edge-on
      // to the viewer, flux max, EMF=0) and full when the normal points
      // toward the viewer (face-on, flux=0, EMF=peak) — verified from the
      // 3D geometry before implementing; this is sin(theta), not cos(theta).
      const apparentW = Math.abs(Math.sin(theta)) * coilW;
      const frontFacing = Math.sin(theta) >= 0;
      ctx.save();
      ctx.strokeStyle = frontFacing ? '#4f46e5' : '#7c3aed'; ctx.lineWidth = 3 * uiScale;
      ctx.strokeRect(cx - apparentW / 2, cy - coilH / 2, Math.max(2, apparentW), coilH);
      ctx.restore();

      const peakEmf = generatorPeakEmf(s.turns, s.fieldB, s.coilArea, s.omega);
      const emfNow = peakEmf * Math.sin(theta);
      s.onTick?.(emfNow);

      if (s.isRunning && !s.isPaused) {
        emfTraceRef.current.push(emfNow);
        if (emfTraceRef.current.length > 200) emfTraceRef.current.shift();
      }
      // EMF-vs-time graph
      const gx = W * 0.62, gy = H * 0.28, gw = W * 0.34, gh = H * 0.44;
      ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 1;
      ctx.strokeRect(gx, gy, gw, gh);
      ctx.beginPath(); ctx.moveTo(gx, gy + gh / 2); ctx.lineTo(gx + gw, gy + gh / 2);
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      const trace = emfTraceRef.current;
      if (trace.length > 1 && peakEmf > 0) {
        ctx.beginPath();
        trace.forEach((v, i) => {
          const px = gx + (i / 199) * gw;
          const py = gy + gh / 2 - (v / peakEmf) * (gh / 2 - 4);
          if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
        });
        ctx.strokeStyle = '#4f46e5'; ctx.lineWidth = 1.8; ctx.stroke();
      }
      ctx.fillStyle = '#64748b'; ctx.font = `${9 * uiScale}px system-ui`; ctx.textAlign = 'left';
      ctx.fillText(`EMF vs time`, gx, gy - 6);
      ctx.fillText(`peak = ${peakEmf.toFixed(1)}V`, gx, gy + gh + 14);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      const nearParallel = Math.abs(Math.sin(theta)) > 0.97;
      const nearPerp = Math.abs(Math.cos(theta)) > 0.97;
      ctx.fillText(
        nearParallel ? 'Coil plane parallel to B: cutting field lines fastest — EMF near MAXIMUM'
          : nearPerp ? 'Coil plane perpendicular to B: sides moving along the field — EMF near ZERO'
          : `e = ${emfNow.toFixed(1)} V`,
        W / 2, H - 8,
      );
    } else {
      // transformer
      const cx = W / 2, cy = H / 2;
      const coreW = 220 * uiScale, coreH = 130 * uiScale, coreT = 22 * uiScale;
      ctx.strokeStyle = '#78716c'; ctx.lineWidth = coreT; ctx.lineJoin = 'round';
      ctx.strokeRect(cx - coreW / 2, cy - coreH / 2, coreW, coreH);
      ctx.fillStyle = '#f8fafc'; ctx.fillRect(cx - coreW / 2 + coreT, cy - coreH / 2 + coreT, coreW - coreT * 2, coreH - coreT * 2);

      const omegaT = 4;
      const iPrimary = Math.sin(t.current * omegaT);
      const primaryTurnsDrawn = 5, secondaryTurnsDrawn = Math.max(3, Math.min(8, Math.round(5 * (s.secondaryTurns / Math.max(1, s.primaryTurns)))));
      const px = cx - coreW / 2 - 4 * uiScale, sx = cx + coreW / 2 + 4 * uiScale;
      const loopR = 16 * uiScale;
      for (let i = 0; i < primaryTurnsDrawn; i++) {
        const y = cy - coreH / 2 + 14 * uiScale + i * ((coreH - 28 * uiScale) / (primaryTurnsDrawn - 1));
        ctx.strokeStyle = '#dc2626'; ctx.lineWidth = 1.8 * uiScale;
        ctx.beginPath(); ctx.ellipse(px, y, loopR, 7 * uiScale, 0, 0, Math.PI * 2); ctx.stroke();
      }
      for (let i = 0; i < secondaryTurnsDrawn; i++) {
        const y = cy - coreH / 2 + 14 * uiScale + i * ((coreH - 28 * uiScale) / (secondaryTurnsDrawn - 1));
        ctx.strokeStyle = '#2563eb'; ctx.lineWidth = 1.8 * uiScale;
        ctx.beginPath(); ctx.ellipse(sx, y, loopR, 7 * uiScale, 0, 0, Math.PI * 2); ctx.stroke();
      }
      // Current direction markers, oscillating with iPrimary
      ctx.fillStyle = iPrimary >= 0 ? '#dc2626' : '#f87171';
      ctx.beginPath(); ctx.arc(px, cy - coreH / 2 - 14 * uiScale, 3.5 * uiScale, 0, Math.PI * 2); ctx.fill();

      const vs = transformerSecondaryVoltage(s.primaryVoltage, s.primaryTurns, s.secondaryTurns);
      const isec = transformerSecondaryCurrent(1, s.primaryTurns, s.secondaryTurns); // per 1A primary, illustrative
      s.onTick?.(vs);

      ctx.fillStyle = '#334155'; ctx.font = `bold ${10 * uiScale}px system-ui`; ctx.textAlign = 'center';
      ctx.fillText(`${s.primaryTurns} turns`, px, cy + coreH / 2 + 18 * uiScale);
      ctx.fillText(`${s.secondaryTurns} turns`, sx, cy + coreH / 2 + 18 * uiScale);
      ctx.fillStyle = '#64748b'; ctx.font = `${10 * uiScale}px system-ui`;
      ctx.fillText(
        `Vp=${s.primaryVoltage}V -> Vs=${vs.toFixed(1)}V (${s.secondaryTurns > s.primaryTurns ? 'step-UP' : s.secondaryTurns < s.primaryTurns ? 'step-DOWN' : 'isolation, 1:1'}) — Is per 1A Ip = ${isec.toFixed(2)}A`,
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

echo "  -> src/app/simulations/electromagnetic-induction/page.tsx"
cat > "src/app/simulations/electromagnetic-induction/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { InductionCanvas, InductionMode } from '@/components/simulation/InductionCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { generatorPeakEmf, rmsFromPeak, transformerSecondaryVoltage, transformerSecondaryCurrent } from '@/lib/physics/electromagnetism';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'faraday-lenz' | 'ac-generator' | 'transformer';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB', 'Undergraduate'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700', Undergraduate: 'bg-slate-200 text-slate-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  'faraday-lenz': { title: "Faraday's & Lenz's Law", icon: '🧲', sub: 'Moving magnet induces EMF', eq: 'EMF = -N dΦ/dt' },
  'ac-generator': { title: 'AC Generator',            icon: '🔄', sub: 'Rotating coil in a field',  eq: 'e = NBAω sin(ωt)' },
  transformer:    { title: 'Transformer',              icon: '🔌', sub: 'Changing flux, linked coils', eq: 'Vs/Vp = Ns/Np' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  'faraday-lenz': [
    "Faraday's law: an EMF is induced in a circuit whenever the magnetic flux linking it CHANGES — no change, no EMF, even if the field itself is strong.",
    'The size of the induced EMF depends on the RATE of change of flux — move the magnet faster, or use more turns, and the galvanometer deflects further.',
    "Lenz's law gives the DIRECTION: the induced current always flows to OPPOSE the change that created it. An approaching magnet induces a current that makes the coil repel it; a receding magnet induces a current that makes the coil attract it back.",
    "Lenz's law is really a statement of energy conservation — if the induced current instead ASSISTED the motion, you'd get free energy from nothing, which is impossible. The opposing force is exactly why you feel resistance pushing a magnet into a coil.",
    'Undergraduate note: EMF = -N dΦ/dt is Faraday\u2019s law in its general (integral) form; the minus sign IS Lenz\u2019s law, encoded directly into the equation rather than argued separately.',
  ],
  'ac-generator': [
    'An AC generator converts mechanical rotation into electrical energy by rotating a coil inside a magnetic field (or, equivalently, rotating the magnet around a fixed coil).',
    'The output is sinusoidal: e = e₀sin(ωt), because the RATE at which the coil cuts field lines varies smoothly as it turns — fastest when the coil plane is parallel to the field, zero for an instant when it is perpendicular.',
    'Peak EMF e₀ = NBAω — more turns, a stronger field, a bigger coil, or spinning faster all increase the output.',
    'Slip rings (continuous contact) let an AC generator deliver alternating current to an external circuit; a DC generator instead uses a split-ring commutator to reverse the connections every half turn, converting the output to a bumpy one-directional DC.',
    'Undergraduate note: RMS values (used for practical AC ratings, e.g. "230V mains") are e₀/√2 — the DC-equivalent value that would deliver the same average power, since a sine wave\u2019s average power is half its peak power.',
  ],
  transformer: [
    'A transformer uses electromagnetic induction to change AC voltage: an alternating current in the primary coil creates a constantly CHANGING flux in the shared iron core, which induces an EMF in the secondary coil.',
    'Ideal transformer equation: Vs/Vp = Ns/Np — more turns on the secondary than the primary steps the voltage UP; fewer turns steps it DOWN.',
    'A transformer only works on AC — a steady DC current produces a constant (non-changing) flux, so no EMF is induced in the secondary at all.',
    'Power is conserved in an ideal transformer (VpIp = VsIs), so stepping voltage UP necessarily steps current DOWN by the same factor, and vice versa — a transformer cannot create extra power.',
    'Undergraduate note: real transformers lose some energy to resistive heating in the windings and to hysteresis/eddy-current losses in the core — laminating the core (thin insulated sheets instead of one solid block) is specifically to reduce eddy-current losses.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  'faraday-lenz': [
    { q: 'A magnet is pushed INTO a coil, north pole first. What pole does the coil face present toward the magnet, and why?', a: 'By Lenz\u2019s law, the coil opposes the increasing flux by presenting a NORTH pole toward the approaching magnet — like poles repel, resisting the push.' },
    { q: 'The same magnet is now pulled OUT of the coil. How does the induced current direction compare to when it was pushed in?', a: 'It reverses — the coil now presents a SOUTH pole to attract the receding magnet and oppose its departure, meaning the current flows in the opposite direction around the coil.' },
    { q: 'Why is there no induced EMF when the magnet is held stationary inside the coil?', a: 'Flux is only changing while there is RELATIVE MOTION between the magnet and coil — a stationary magnet produces a constant flux, and dΦ/dt = 0 means no induced EMF.' },
  ],
  'ac-generator': [
    { q: 'A generator coil of 200 turns, area 0.03m², spins at 60 rad/s in a 0.4T field. Find the peak EMF.', a: 'e₀ = NBAω = 200×0.4×0.03×60 = 144 V.' },
    { q: 'At what point in the rotation is the induced EMF exactly zero, and why?', a: 'When the coil plane is perpendicular to the field (the coil face pointing directly along the field lines) — at that instant the coil sides are momentarily moving PARALLEL to the field, cutting no field lines at all.' },
    { q: 'A generator\u2019s peak EMF is 340V. Find the RMS voltage (the value you would measure with a standard AC voltmeter).', a: 'RMS = peak/√2 = 340/1.414 ≈ 240V — very close to the UK/Nigeria mains RMS voltage.' },
  ],
  transformer: [
    { q: 'A step-down transformer has 1000 turns on the primary and 50 on the secondary, with 240V AC input. Find the output voltage.', a: 'Vs = Vp×(Ns/Np) = 240×(50/1000) = 12 V.' },
    { q: 'The same transformer draws a primary current of 0.5A. Find the secondary current (assume 100% efficiency).', a: 'Power is conserved: VpIp = VsIs, so Is = VpIp/Vs = (240×0.5)/12 = 10 A.' },
    { q: 'Why won\u2019t a transformer work if you connect its primary to a battery (DC) instead of AC?', a: 'A steady DC current produces a constant magnetic flux in the core. Since Faraday\u2019s law requires a CHANGING flux to induce an EMF, a constant flux induces nothing in the secondary — except for the brief instants the DC is switched on or off.' },
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

export default function ElectromagneticInductionPage() {
  const [topic, setTopic] = useState<Topic>('faraday-lenz');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [turns, setTurns] = useState(8);
  const [speed, setSpeed] = useState(2);
  const [magnetPoleOut, setMagnetPoleOut] = useState(true);

  const [genTurns, setGenTurns] = useState(50);
  const [genFieldB, setGenFieldB] = useState(0.3);
  const [genArea, setGenArea] = useState(0.02);
  const [genOmega, setGenOmega] = useState(3);

  const [primaryTurns, setPrimaryTurns] = useState(500);
  const [secondaryTurns, setSecondaryTurns] = useState(100);
  const [primaryVoltage, setPrimaryVoltage] = useState(240);

  const [liveValue, setLiveValue] = useState(0);

  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, turns, speed, magnetPoleOut, genTurns, genFieldB, genArea, genOmega, primaryTurns, secondaryTurns, primaryVoltage, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  const peakEmf = generatorPeakEmf(genTurns, genFieldB, genArea, genOmega);
  const vs = transformerSecondaryVoltage(primaryVoltage, primaryTurns, secondaryTurns);
  const isPer1A = transformerSecondaryCurrent(1, primaryTurns, secondaryTurns);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electromagnetism</p>
                <h1 className="text-lg font-semibold text-gray-900">Electromagnetic Induction</h1>
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
                <InductionCanvas key={resetKey} mode={topic as InductionMode}
                  turns={turns} speed={speed} magnetPoleOut={magnetPoleOut}
                  fieldB={genFieldB} coilArea={genArea} omega={genOmega}
                  primaryTurns={primaryTurns} secondaryTurns={secondaryTurns} primaryVoltage={primaryVoltage}
                  isRunning={isRunning} isPaused={isPaused} onTick={setLiveValue}
                  width={canvasSize.width} height={canvasSize.height} />
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electromagnetic-induction"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={{ topic }} />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'faraday-lenz' && <>
                  <Slider label="Coil turns" unit="" value={turns} min={2} max={20} step={1} set={setTurns} color="#6366f1" />
                  <Slider label="Oscillation speed" unit="rad/s" value={speed} min={0.5} max={5} step={0.5} set={setSpeed} color="#f59e0b" />
                  <div className="flex gap-2">
                    {([true, false] as const).map(v => (
                      <button key={String(v)} onClick={() => setMagnetPoleOut(v)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                          magnetPoleOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{v ? 'N faces coil' : 'S faces coil'}</button>
                    ))}
                  </div>
                </>}

                {topic === 'ac-generator' && <>
                  <Slider label="Coil turns" unit="" value={genTurns} min={10} max={200} step={10} set={setGenTurns} color="#6366f1" />
                  <Slider label="Field strength" unit="T" value={genFieldB} min={0.1} max={1} step={0.05} set={setGenFieldB} color="#f59e0b" />
                  <Slider label="Coil area" unit="m²" value={genArea} min={0.005} max={0.05} step={0.005} set={setGenArea} color="#8b5cf6" />
                  <Slider label="Angular speed ω" unit="rad/s" value={genOmega} min={1} max={10} step={0.5} set={setGenOmega} color="#8b5cf6" />
                </>}

                {topic === 'transformer' && <>
                  <Slider label="Primary voltage (peak)" unit="V" value={primaryVoltage} min={12} max={240} step={12} set={setPrimaryVoltage} color="#dc2626" />
                  <Slider label="Primary turns" unit="" value={primaryTurns} min={50} max={1000} step={50} set={setPrimaryTurns} color="#6366f1" />
                  <Slider label="Secondary turns" unit="" value={secondaryTurns} min={50} max={1000} step={50} set={setSecondaryTurns} color="#2563eb" />
                </>}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'faraday-lenz' && <>
                    <StatRow label="Live EMF" value={liveValue.toFixed(2)} unit="(arb. units)" color="text-indigo-600" />
                    <StatRow label="Lenz's law" value="opposes the change" unit="always" color="text-emerald-600" />
                  </>}
                  {topic === 'ac-generator' && <>
                    <StatRow label="Peak EMF e₀" value={peakEmf.toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="RMS EMF" value={rmsFromPeak(peakEmf).toFixed(1)} unit="V" color="text-emerald-600" />
                    <StatRow label="Frequency" value={(genOmega / (2 * Math.PI)).toFixed(2)} unit="Hz" color="text-amber-600" />
                  </>}
                  {topic === 'transformer' && <>
                    <StatRow label="Secondary voltage" value={vs.toFixed(1)} unit="V" color="text-indigo-600" />
                    <StatRow label="Turns ratio Ns/Np" value={(secondaryTurns / primaryTurns).toFixed(2)} unit="" color="text-amber-600" />
                    <StatRow label="Is per 1A primary" value={isPer1A.toFixed(2)} unit="A" color="text-purple-600" />
                    <StatRow label="Type" value={secondaryTurns > primaryTurns ? 'step-up' : secondaryTurns < primaryTurns ? 'step-down' : 'isolation'} unit="" color="text-emerald-600" />
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

echo "  -> src/app/embed/electromagnetic-induction/page.tsx"
cat > "src/app/embed/electromagnetic-induction/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { InductionCanvas, InductionMode } from '@/components/simulation/InductionCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'faraday-lenz' | 'ac-generator' | 'transformer';

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

function InductionEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'ac-generator' || t === 'transformer' ? t : 'faraday-lenz';
  })();
  const showControls = sp.get('controls') !== '0';

  const [turns, setTurns] = useState(() => num(sp, 'turns', 8, 2, 20));
  const [speed, setSpeed] = useState(() => num(sp, 'speed', 2, 0.5, 5));
  const [magnetPoleOut, setMagnetPoleOut] = useState(true);

  const [genFieldB, setGenFieldB] = useState(0.3);
  const [genArea] = useState(0.02);
  const [genOmega, setGenOmega] = useState(3);

  const [primaryTurns, setPrimaryTurns] = useState(500);
  const [secondaryTurns, setSecondaryTurns] = useState(100);
  const [primaryVoltage] = useState(240);

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, turns, speed, magnetPoleOut, genFieldB, genOmega, primaryTurns, secondaryTurns, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      <InductionCanvas key={resetKey} mode={topic as InductionMode}
        turns={turns} speed={speed} magnetPoleOut={magnetPoleOut}
        fieldB={genFieldB} coilArea={genArea} omega={genOmega}
        primaryTurns={primaryTurns} secondaryTurns={secondaryTurns} primaryVoltage={primaryVoltage}
        isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'faraday-lenz' && <>
            <Slider label="Coil turns" unit="" value={turns} min={2} max={20} step={1} set={setTurns} color="#6366f1" />
            <Slider label="Oscillation speed" unit="rad/s" value={speed} min={0.5} max={5} step={0.5} set={setSpeed} color="#f59e0b" />
            <div className="flex gap-2">
              {([true, false] as const).map(v => (
                <button key={String(v)} onClick={() => setMagnetPoleOut(v)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    magnetPoleOut === v ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{v ? 'N faces coil' : 'S faces coil'}</button>
              ))}
            </div>
          </>}
          {topic === 'ac-generator' && <>
            <Slider label="Field strength" unit="T" value={genFieldB} min={0.1} max={1} step={0.05} set={setGenFieldB} color="#f59e0b" />
            <Slider label="Angular speed" unit="rad/s" value={genOmega} min={1} max={10} step={0.5} set={setGenOmega} color="#8b5cf6" />
          </>}
          {topic === 'transformer' && <>
            <Slider label="Primary turns" unit="" value={primaryTurns} min={50} max={1000} step={50} set={setPrimaryTurns} color="#6366f1" />
            <Slider label="Secondary turns" unit="" value={secondaryTurns} min={50} max={1000} step={50} set={setSecondaryTurns} color="#2563eb" />
          </>}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function InductionEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <InductionEmbedInner />
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
echo "Patch v44 applied -- 4 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/electromagnetic-induction -- all three tabs:"
echo "  Faraday's & Lenz's Law, AC Generator, Transformer."
echo ""
echo "Simple AC Circuits is next."
