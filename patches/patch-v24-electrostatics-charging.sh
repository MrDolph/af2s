#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v24: new Electrostatics module, part 1 of 3 —
# Charging Objects (production of charges, gold-leaf electroscope,
# electrophorus)
#
#   This is the first of three planned pages covering the full electrostatics
#   syllabus you asked for. This one covers the qualitative/experimental
#   cluster; Coulomb's law + electric fields, and potential + capacitors
#   will follow as parts 2 and 3.
#
#   PRODUCTION OF CHARGES — three animated methods, each a genuine multi-
#   phase sequence (not a single static picture):
#     - Friction: rod and cloth approach, rub (with electrons visibly
#       transferring), separate carrying opposite charges.
#     - Conduction: charged rod touches a neutral sphere, charge (SAME
#       sign) spreads onto it — a key exam distinction from induction.
#     - Induction: rod approaches (no contact) -> polarises the sphere ->
#       earthing lets the repelled charge escape -> earth disconnected ->
#       rod removed, leaving a net charge OPPOSITE to the rod. The step
#       order is enforced by the animation itself (earth removed before
#       the rod, exactly as the physics requires).
#
#   GOLD-LEAF ELECTROSCOPE — two modes:
#     - Charging by contact: rod touches the cap, charge spreads to the
#       leaves, they diverge and stay diverged once the rod is removed.
#     - Testing an unknown charge's sign: bring a known charge near an
#       already-charged electroscope's cap. Verified numerically that a
#       same-sign approach increases divergence (24° -> 40°, the maximum)
#       while an opposite-sign approach decreases it (24° -> 2°) — the
#       standard electroscope charge-sign test.
#
#   ELECTROPHORUS — the full repeatable-charging sequence: disc lowered
#   onto the (permanently) charged slab, induction separates the disc's
#   charge, earthing lets the repelled charge escape, and lifting the disc
#   by its insulating handle carries away a net charge OPPOSITE to the
#   slab. A cycle counter demonstrates the key exam point that this can
#   repeat indefinitely from a single charging of the slab, since the
#   slab's own charge is never touched or transferred.
#
#   All physics (Coulomb's law, field, potential, capacitance, RC charging
#   curve) verified against standard textbook values before any UI was
#   built — e.g. two 1μC charges 1m apart give 0.00899N, a 0.01m² parallel
#   plate capacitor at 1mm gives 88.5pF, and an RC charging curve hits the
#   classic 63.2% at t=τ.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v24-electrostatics-charging.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── A-Factor patch v24: Electrostatics part 1 — Charging Objects ──"
mkdir -p "src/app/embed/electrostatics-charging" "src/app/simulations" "src/app/simulations/electrostatics-charging" "src/components/simulation" "src/lib/physics"

echo "  → src/lib/physics/electrostatics.ts"
cat > "src/lib/physics/electrostatics.ts" << 'AFEOF'
// ── Electrostatics ──────────────────────────────────────────────────────────
export const COULOMB_K = 8.99e9;   // N·m²/C² (= 1/4πε₀)
export const EPSILON_0 = 8.85e-12; // F/m — permittivity of free space
export const ELEMENTARY_CHARGE = 1.602e-19; // C

// ── Coulomb's law ────────────────────────────────────────────────────────────
// Force magnitude between two point charges.
export function coulombForce(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * Math.abs(q1 * q2)) / (r * r);
}
// Signed version: positive = repulsive (like charges), negative = attractive.
export function coulombForceSigned(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q1 * q2) / (r * r);
}

// ── Electric field ────────────────────────────────────────────────────────────
// Field strength at distance r from a point charge q.
export function electricFieldPoint(q: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * Math.abs(q)) / (r * r);
}
// E = F/q — field strength from the force it exerts on a test charge.
export function electricFieldFromForce(force: number, testCharge: number): number {
  return testCharge !== 0 ? force / testCharge : 0;
}
// Uniform field between parallel plates.
export function uniformFieldStrength(voltage: number, separation: number): number {
  return separation > 0 ? voltage / separation : 0;
}

// ── Electric potential & potential energy ────────────────────────────────────
// Potential at distance r from a point charge q (defining V=0 at infinity).
export function electricPotentialPoint(q: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q) / r;
}
// Potential energy of a pair of point charges separated by r.
export function electricPotentialEnergy(q1: number, q2: number, r: number): number {
  if (r <= 0) return 0;
  return (COULOMB_K * q1 * q2) / r;
}
// Work done moving a charge q through a potential difference V: W = qV.
export function workDoneByPotentialDiff(charge: number, voltage: number): number {
  return charge * voltage;
}

// ── Capacitors ────────────────────────────────────────────────────────────────
export function parallelPlateCapacitance(areaM2: number, separationM: number, relativePermittivity = 1): number {
  if (separationM <= 0) return 0;
  return (EPSILON_0 * relativePermittivity * areaM2) / separationM;
}
export function capacitorCharge(capacitance: number, voltage: number): number {
  return capacitance * voltage;
}
export function capacitorEnergy(capacitance: number, voltage: number): number {
  return 0.5 * capacitance * voltage * voltage;
}
// Charging/discharging through a resistor follows an exponential approach —
// used to animate a capacitor's voltage climbing (or falling) over time,
// with the standard RC time constant.
export function capacitorChargingVoltage(t: number, V0: number, R: number, C: number): number {
  const tau = R * C;
  if (tau <= 0) return V0;
  return V0 * (1 - Math.exp(-t / tau));
}
export function capacitorDischargingVoltage(t: number, V0: number, R: number, C: number): number {
  const tau = R * C;
  if (tau <= 0) return 0;
  return V0 * Math.exp(-t / tau);
}

// ── Gold-leaf electroscope ───────────────────────────────────────────────────
// Simplified model for this level: leaf divergence angle is proportional to
// the magnitude of charge on the electroscope, saturating at a realistic
// maximum before the leaves would touch the case.
export function electroscopeDivergenceAngle(chargeMagnitude: number, maxCharge: number, maxAngleDeg = 40): number {
  if (maxCharge <= 0) return 0;
  const frac = Math.min(1, Math.abs(chargeMagnitude) / maxCharge);
  return frac * maxAngleDeg;
}
AFEOF

echo "  → src/components/simulation/ChargingMethodsCanvas.tsx"
cat > "src/components/simulation/ChargingMethodsCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

export type ChargingMethod = 'friction' | 'conduction' | 'induction';

interface Props {
  method: ChargingMethod;
  isRunning: boolean; isPaused: boolean;
  onPhaseChange?: (phase: string) => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 7) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.5;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

// Phase durations (s) for each method's animated sequence
const DURATIONS: Record<ChargingMethod, number[]> = {
  friction: [1.2, 1.8, 1.2],                 // approach, rub, separate
  conduction: [1.2, 1.4, 1.2],               // approach, touch/transfer, separate
  induction: [1.0, 1.4, 1.2, 0.8, 1.2],      // approach, polarize, ground, disconnect, remove
};
const PHASE_LABELS: Record<ChargingMethod, string[]> = {
  friction: ['Rod and cloth, both neutral', 'Rubbing transfers electrons rod → cloth', 'Rod is left positive, cloth negative'],
  conduction: ['Charged rod approaches a neutral sphere', 'Contact — electrons spread onto the sphere', 'Sphere keeps the SAME sign as the rod, rod\u2019s charge is reduced'],
  induction: [
    'Charged rod approaches — sphere still neutral overall',
    'Polarisation: charges separate, but total charge is still zero',
    'Earthing: the repelled charge escapes to ground',
    'Ground wire disconnected — sphere now has a net charge',
    'Rod removed — induced charge is OPPOSITE to the rod, spread evenly',
  ],
};

export function ChargingMethodsCanvas({ method, isRunning, isPaused, onPhaseChange, width = 660, height = 300 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const lastPhaseIdx = useRef(-1);
  const sim = useRef({ method, isRunning, isPaused, onPhaseChange });
  sim.current = { method, isRunning, isPaused, onPhaseChange };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; lastPhaseIdx.current = -1; }, [method]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    const durations = DURATIONS[s.method];
    const totalDuration = durations.reduce((a, b) => a + b, 0);

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, totalDuration);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    // Which phase are we in, and how far through it (0..1)?
    let acc = 0, phaseIdx = 0, phaseT = 0;
    for (let i = 0; i < durations.length; i++) {
      if (t.current < acc + durations[i] || i === durations.length - 1) {
        phaseIdx = i; phaseT = Math.min(1, (t.current - acc) / durations[i]); break;
      }
      acc += durations[i];
    }
    if (!s.isRunning) { phaseIdx = 0; phaseT = 0; }
    if (phaseIdx !== lastPhaseIdx.current) { lastPhaseIdx.current = phaseIdx; s.onPhaseChange?.(PHASE_LABELS[s.method][phaseIdx]); }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H / 2;

    if (s.method === 'friction') {
      // approach(0) -> rub(1) -> separate(2)
      const approach = phaseIdx === 0 ? phaseT : 1;
      const rubProgress = phaseIdx === 1 ? phaseT : phaseIdx > 1 ? 1 : 0;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const gap = 120 * (1 - approach) - separate * 100;
      const rodX = W / 2 - 60 - gap / 2, clothX = W / 2 + 60 + gap / 2;
      const wobble = phaseIdx === 1 ? Math.sin(t.current * 18) * 10 : 0;

      // Rod (glass)
      ctx.fillStyle = '#c7d2fe'; ctx.fillRect(rodX - 8 + wobble, midY - 60, 16, 120);
      ctx.strokeStyle = '#6366f1'; ctx.strokeRect(rodX - 8 + wobble, midY - 60, 16, 120);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('glass rod', rodX + wobble, midY - 70);

      // Cloth (silk)
      ctx.fillStyle = '#fecaca'; ctx.fillRect(clothX - 26 - wobble, midY - 50, 52, 100);
      ctx.strokeStyle = '#ef4444'; ctx.strokeRect(clothX - 26 - wobble, midY - 50, 52, 100);
      ctx.fillText('silk cloth', clothX - wobble, midY - 60);

      // Electrons transferring during rub phase
      if (phaseIdx === 1) {
        for (let i = 0; i < 5; i++) {
          const ex = rodX + wobble + (clothX - wobble - (rodX + wobble)) * Math.min(1, rubProgress * 1.4 - i * 0.08);
          if (ex > rodX + wobble && ex < clothX - wobble) drawCharge(ctx, ex, midY - 30 + i * 15, -1, 5);
        }
      }
      const netCharge = phaseIdx >= 1 ? Math.min(1, rubProgress) : 0;
      if (netCharge > 0.05 || phaseIdx === 2) {
        drawCharge(ctx, rodX + wobble, midY + 50, 1, 6);
        drawCharge(ctx, clothX - wobble, midY + 50, -1, 6);
      }
    } else if (s.method === 'conduction') {
      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const gap = 100 * (1 - approach) + separate * 90;
      const sphereX = W / 2 + 90;
      const rodTipX = sphereX - 60 - gap;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('negatively charged rod', rodTipX - 45, midY - 20);
      for (let i = 0; i < 5; i++) drawCharge(ctx, rodTipX - 12 - i * 16, midY, -1, 5);

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, 34, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();
      ctx.fillText('neutral sphere', sphereX, midY - 46);

      if (phaseIdx >= 1) {
        const n = Math.round((phaseIdx === 1 ? phaseT : 1) * 4);
        for (let i = 0; i < n; i++) {
          const a = (i / 4) * Math.PI * 2;
          drawCharge(ctx, sphereX + Math.cos(a) * 20, midY + Math.sin(a) * 20, -1, 5);
        }
      }
      if (phaseIdx === 2) {
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui';
        ctx.fillText('rod: reduced (–)   sphere: (–), same sign as rod', W / 2, H - 16);
      }
    } else {
      // induction: approach(0) polarise(1) ground(2) disconnect(3) remove(4)
      const approach = phaseIdx === 0 ? phaseT : 1;
      const remove = phaseIdx === 4 ? phaseT : 0;
      const gap = 130 * (1 - approach) + remove * 160;
      const sphereX = W / 2 + 60;
      const rodTipX = sphereX - 70 - gap;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 100, 16, 100);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('negative rod', rodTipX - 82, midY - 110);
      for (let i = 0; i < 4; i++) drawCharge(ctx, rodTipX - 82, midY - 90 + i * 25, -1, 5);

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, 34, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();

      const polarised = phaseIdx >= 1;
      const grounded = phaseIdx === 2 || phaseIdx === 3;
      const groundProgress = phaseIdx === 2 ? phaseT : phaseIdx > 2 ? 1 : 0;
      const finalCharge = phaseIdx === 4;

      if (grounded) {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2;
        ctx.beginPath(); ctx.moveTo(sphereX + 34, midY); ctx.lineTo(sphereX + 80, midY); ctx.lineTo(sphereX + 80, midY + 60); ctx.stroke();
        for (let i = -1; i <= 1; i++) { ctx.beginPath(); ctx.moveTo(sphereX + 72 + i * 6, midY + 60); ctx.lineTo(sphereX + 66 + i * 6, midY + 70); ctx.stroke(); }
        ctx.fillStyle = '#64748b'; ctx.font = '9px system-ui'; ctx.fillText('ground', sphereX + 80, midY + 84);
      }

      if (polarised) {
        // near side (left, toward rod) positive; far side negative, fading as it's earthed away
        for (let i = 0; i < 3; i++) drawCharge(ctx, sphereX - 16, midY - 16 + i * 16, 1, 5);
        const farAlpha = grounded ? Math.max(0, 1 - groundProgress) : 1;
        if (farAlpha > 0.05 && !finalCharge) {
          ctx.save(); ctx.globalAlpha = farAlpha;
          for (let i = 0; i < 3; i++) drawCharge(ctx, sphereX + 16, midY - 16 + i * 16, -1, 5);
          ctx.restore();
        }
      }
      if (finalCharge) {
        // Net positive, spread evenly
        for (let i = 0; i < 4; i++) {
          const a = (i / 4) * Math.PI * 2;
          drawCharge(ctx, sphereX + Math.cos(a) * 20, midY + Math.sin(a) * 20, 1, 5);
        }
        ctx.fillStyle = '#1e293b'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
        ctx.fillText('Sphere left with a net POSITIVE charge — opposite to the rod', W / 2, H - 16);
      }
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(PHASE_LABELS[s.method][phaseIdx] ?? '', W / 2, 24);

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

echo "  → src/components/simulation/ElectroscopeCanvas.tsx"
cat > "src/components/simulation/ElectroscopeCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';
import { electroscopeDivergenceAngle } from '@/lib/physics/electrostatics';

export type ElectroscopeMode = 'charging' | 'testing';

interface Props {
  mode: ElectroscopeMode;
  rodSign: 1 | -1;               // sign of the charging rod (charging mode) or the test rod (testing mode)
  electroscopeSign: 1 | -1;      // testing mode only: the electroscope's pre-existing charge sign
  isRunning: boolean; isPaused: boolean;
  onTick?: (divergenceDeg: number) => void;
  width?: number; height?: number;
}

const MAX_ANGLE = 40;

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 6) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.3;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

export function ElectroscopeCanvas({ mode, rodSign, electroscopeSign, isRunning, isPaused, onTick, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const sim = useRef({ mode, rodSign, electroscopeSign, isRunning, isPaused, onTick });
  sim.current = { mode, rodSign, electroscopeSign, isRunning, isPaused, onTick };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; }, [mode, rodSign, electroscopeSign]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    const DURATION = s.mode === 'charging' ? 3.2 : 3.6;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, DURATION);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }
    const running = s.isRunning;

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const capX = W / 2, capY = 60;
    const jarTop = 90, jarBottom = H - 30, jarHalfW = 70;
    const leafTopY = jarTop + 20, leafLen = 90;

    let divergenceDeg: number, rodApproach: number, sign: 1 | -1, chargeVisible = 0;

    if (s.mode === 'charging') {
      // approach (0-0.9) -> touch/transfer (0.9-2.4) -> withdraw (2.4-3.2)
      const p1 = 0.9, p2 = 2.4;
      if (!running) { rodApproach = 0; chargeVisible = 0; }
      else if (t.current < p1) { rodApproach = t.current / p1; chargeVisible = 0; }
      else if (t.current < p2) { rodApproach = 1; chargeVisible = (t.current - p1) / (p2 - p1); }
      else { rodApproach = 1 - (t.current - p2) / (DURATION - p2); chargeVisible = 1; }
      sign = s.rodSign;
      divergenceDeg = electroscopeDivergenceAngle(chargeVisible, 1, MAX_ANGLE);
    } else {
      // baseline charge already present; test rod approaches (0-1.2), holds (1.2-2.4), retreats (2.4-3.6)
      const baseline = 0.6; // baseline divergence fraction before the test rod arrives
      const p1 = 1.2, p2 = 2.4;
      if (!running) { rodApproach = 0; }
      else if (t.current < p1) { rodApproach = t.current / p1; }
      else if (t.current < p2) { rodApproach = 1; }
      else { rodApproach = 1 - (t.current - p2) / (DURATION - p2); }
      sign = s.rodSign;
      const sameSign = s.rodSign === s.electroscopeSign;
      // Same sign approaching -> pushes more charge onto the leaves (more divergence).
      // Opposite sign approaching -> draws charge back up to the cap (less divergence).
      const influence = (sameSign ? 1 : -1) * rodApproach * 0.7;
      const frac = Math.max(0.05, Math.min(1, baseline + influence));
      divergenceDeg = electroscopeDivergenceAngle(frac, 1, MAX_ANGLE);
      chargeVisible = baseline; // the electroscope's own charge is always present in this mode
    }
    s.onTick?.(divergenceDeg);

    // Charging/test rod
    const rodTipX = capX - 20 - (1 - rodApproach) * 160;
    if (rodApproach > 0.01) {
      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, capY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, capY - 8, 90, 16);
      for (let i = 0; i < 4; i++) drawCharge(ctx, rodTipX - 14 - i * 20, capY, sign, 5);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${sign > 0 ? '+' : '−'} rod`, rodTipX - 45, capY - 18);
    }

    // Jar / case
    ctx.strokeStyle = '#cbd5e1'; ctx.lineWidth = 2;
    ctx.strokeRect(capX - jarHalfW, jarTop, jarHalfW * 2, jarBottom - jarTop);

    // Cap and rod down to the leaves
    ctx.fillStyle = '#94a3b8';
    ctx.beginPath(); ctx.ellipse(capX, capY, 18, 8, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(capX - 3, capY, 6, leafTopY - capY);

    // Leaves — hinge at the bottom of the rod, swinging apart by divergenceDeg
    const hingeY = leafTopY;
    const rad = (divergenceDeg * Math.PI) / 180;
    ctx.strokeStyle = '#eab308'; ctx.lineWidth = 3; ctx.lineCap = 'round';
    [-1, 1].forEach(side => {
      const dx = Math.sin(rad) * side, dy = Math.cos(rad);
      ctx.beginPath(); ctx.moveTo(capX, hingeY); ctx.lineTo(capX + dx * leafLen, hingeY + dy * leafLen); ctx.stroke();
    });

    // Charge distributed over the cap/rod/leaves once present
    if (chargeVisible > 0.05) {
      const n = Math.round(chargeVisible * 3) + 1;
      for (let i = 0; i < n; i++) drawCharge(ctx, capX + (i - (n - 1) / 2) * 14, capY - 16, sign, 4.5);
      [-1, 1].forEach(side => {
        const dx = Math.sin(rad) * side, dy = Math.cos(rad);
        drawCharge(ctx, capX + dx * leafLen * 0.6, hingeY + dy * leafLen * 0.6, sign, 4.5);
      });
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (s.mode === 'charging') {
      ctx.fillText(
        !running ? 'Press Run: charging by contact' :
        t.current < 0.9 ? 'Rod approaches the cap' :
        t.current < 2.4 ? 'Touching — charge spreads onto the cap, rod and leaves' :
        'Rod withdrawn — leaves stay diverged (electroscope is now charged)',
        W / 2, 20,
      );
    } else {
      const sameSign = s.rodSign === s.electroscopeSign;
      ctx.fillText(
        !running ? `Electroscope pre-charged (${s.electroscopeSign > 0 ? '+' : '−'}). Press Run to test with a ${s.rodSign > 0 ? '+' : '−'} rod` :
        t.current < 2.4 ? (sameSign ? 'Same sign approaching — leaves diverge FURTHER' : 'Opposite sign approaching — leaves diverge LESS') :
        'Rod withdrawn — leaves return to the original divergence',
        W / 2, 20,
      );
    }
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Leaf divergence ≈ ${divergenceDeg.toFixed(0)}°`, 8, H - 10);

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

echo "  → src/components/simulation/ElectrophorusCanvas.tsx"
cat > "src/components/simulation/ElectrophorusCanvas.tsx" << 'AFEOF'
'use client';
import { useRef, useEffect, useCallback } from 'react';

interface Props {
  isRunning: boolean; isPaused: boolean;
  cycleCount: number; // how many times the disc has been lifted+used this run (for the "repeatable" teaching point)
  onCycleComplete?: () => void;
  width?: number; height?: number;
}

function drawCharge(ctx: CanvasRenderingContext2D, x: number, y: number, sign: 1 | -1, r = 6) {
  ctx.save();
  ctx.fillStyle = sign > 0 ? '#ef4444' : '#3b82f6';
  ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill();
  ctx.strokeStyle = 'white'; ctx.lineWidth = 1.3;
  ctx.beginPath(); ctx.moveTo(x - r * 0.5, y); ctx.lineTo(x + r * 0.5, y); ctx.stroke();
  if (sign > 0) { ctx.beginPath(); ctx.moveTo(x, y - r * 0.5); ctx.lineTo(x, y + r * 0.5); ctx.stroke(); }
  ctx.restore();
}

// before(0) -> lower disc onto slab(1) -> induction settles(2) -> finger grounds it(3) -> lift disc(4)
const DURATIONS = [0.6, 1.0, 0.8, 1.0, 1.2];
const TOTAL = DURATIONS.reduce((a, b) => a + b, 0);
const PHASE_LABELS = [
  'Insulating slab, charged negative by rubbing earlier — the disc is not yet placed',
  'Metal disc lowered onto the charged slab (insulating handle keeps your hand safe)',
  'Induction: the disc\u2019s underside is pulled positive, its top pushed negative',
  'Touch the disc with a finger — the repelled negative charge escapes to earth through you',
  'Lift the disc by its insulating handle — it carries away a net POSITIVE charge',
];

export function ElectrophorusCanvas({ isRunning, isPaused, cycleCount, onCycleComplete, width = 660, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);
  const firedComplete = useRef(false);
  const sim = useRef({ isRunning, isPaused, onCycleComplete });
  sim.current = { isRunning, isPaused, onCycleComplete };

  useEffect(() => { t.current = 0; lastFrameRef.current = null; firedComplete.current = false; }, [cycleCount]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        t.current = Math.min(t.current + (timestamp - lastFrameRef.current) / 1000, TOTAL);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    let acc = 0, phaseIdx = 0, phaseT = 0;
    for (let i = 0; i < DURATIONS.length; i++) {
      if (t.current < acc + DURATIONS[i] || i === DURATIONS.length - 1) {
        phaseIdx = i; phaseT = DURATIONS[i] > 0 ? Math.min(1, (t.current - acc) / DURATIONS[i]) : 1; break;
      }
      acc += DURATIONS[i];
    }
    if (!s.isRunning) { phaseIdx = 0; phaseT = 0; }
    if (s.isRunning && t.current >= TOTAL && !firedComplete.current) { firedComplete.current = true; s.onCycleComplete?.(); }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    const midY = H * 0.62, slabX = W / 2, slabW = 220, slabH = 22;
    const slabTop = midY - slabH / 2;

    // Insulating slab (charged negative, fixed for the whole demo)
    ctx.fillStyle = '#c4b5fd'; ctx.fillRect(slabX - slabW / 2, slabTop, slabW, slabH);
    ctx.strokeStyle = '#7c3aed'; ctx.strokeRect(slabX - slabW / 2, slabTop, slabW, slabH);
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
    ctx.fillText('insulating slab (charged −)', slabX, slabTop + slabH + 16);
    for (let i = -3; i <= 3; i++) drawCharge(ctx, slabX + i * 28, slabTop + slabH / 2, -1, 5);

    // Disc height: starts high, lowers onto the slab in phase 1, stays down
    // through phases 2-3, lifts away in phase 4.
    const restY = slabTop - 14;
    const highY = slabTop - 130;
    let discY: number;
    if (phaseIdx === 0) discY = highY;
    else if (phaseIdx === 1) discY = highY + (restY - highY) * phaseT;
    else if (phaseIdx < 4) discY = restY;
    else discY = restY + (highY - restY) * phaseT;

    // Handle (insulating)
    ctx.strokeStyle = '#78350f'; ctx.lineWidth = 6; ctx.lineCap = 'round';
    ctx.beginPath(); ctx.moveTo(slabX, discY); ctx.lineTo(slabX, discY - 70); ctx.stroke();

    // Metal disc
    ctx.fillStyle = '#e2e8f0';
    ctx.beginPath(); ctx.ellipse(slabX, discY, 90, 12, 0, 0, Math.PI * 2); ctx.fill();
    ctx.strokeStyle = '#94a3b8'; ctx.stroke();
    ctx.fillStyle = '#334155'; ctx.font = '10px system-ui';
    ctx.fillText('metal disc', slabX, discY - 90);

    const touching = phaseIdx >= 1;
    const induced = phaseIdx >= 2;
    const grounded = phaseIdx === 3;
    const groundProgress = phaseIdx === 3 ? phaseT : phaseIdx > 3 ? 1 : 0;
    const lifted = phaseIdx === 4;

    if (induced) {
      // Bottom of disc: induced positive (attracted toward the slab's negative charge)
      for (let i = -3; i <= 3; i++) drawCharge(ctx, slabX + i * 24, discY + 8, 1, 5);
      // Top of disc: repelled negative — escapes once grounded
      const topAlpha = grounded || lifted ? Math.max(0, 1 - groundProgress) : 1;
      if (topAlpha > 0.05 && !lifted) {
        ctx.save(); ctx.globalAlpha = topAlpha;
        for (let i = -3; i <= 3; i++) drawCharge(ctx, slabX + i * 24, discY - 8, -1, 5);
        ctx.restore();
      }
    }
    if (touching && !induced) {
      // brief neutral-looking contact moment right as it lands
    }

    if (grounded) {
      // finger/ground symbol touching the top of the disc
      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); ctx.ellipse(slabX + 70, discY - 30, 8, 20, 0.3, 0, Math.PI * 2); ctx.fill();
      ctx.fillStyle = '#78350f'; ctx.font = '9px system-ui'; ctx.fillText('finger (to earth)', slabX + 70, discY - 56);
    }

    if (lifted && phaseT > 0.3) {
      // Disc now carries net positive charge, spread over its underside
      ctx.save(); ctx.globalAlpha = Math.min(1, (phaseT - 0.3) / 0.3);
      for (let i = -3; i <= 3; i++) drawCharge(ctx, slabX + i * 24, discY + 8, 1, 5);
      ctx.restore();
      ctx.fillStyle = '#dc2626'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('disc now carries a net POSITIVE charge', slabX, discY + 34);
    }

    ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    ctx.fillText(PHASE_LABELS[phaseIdx], W / 2, 20);
    ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
    ctx.fillText(`Cycle ${cycleCount + 1} — the slab itself is never touched, so this can repeat indefinitely`, 8, H - 10);

    rafRef.current = requestAnimationFrame(draw);
  }, [cycleCount]);

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

echo "  → src/app/simulations/electrostatics-charging/page.tsx"
cat > "src/app/simulations/electrostatics-charging/page.tsx" << 'AFEOF'
'use client';
import { useState, useCallback, useEffect, useRef } from 'react';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';

type Topic = 'production' | 'electroscope' | 'electrophorus';

const CURRICULA = ['WAEC', 'NECO', 'IGCSE', 'SAT', 'JUPEB'];
const CC: Record<string, string> = {
  WAEC: 'bg-indigo-100 text-indigo-700', NECO: 'bg-pink-100 text-pink-700',
  IGCSE: 'bg-emerald-100 text-emerald-700', SAT: 'bg-orange-100 text-orange-700',
  JUPEB: 'bg-purple-100 text-purple-700',
};

const TOPIC_META: Record<Topic, { title: string; icon: string; sub: string; eq: string }> = {
  production:    { title: 'Production of charges', icon: '⚡', sub: 'Friction, conduction, induction', eq: 'like charges repel, unlike attract' },
  electroscope:  { title: 'Gold-leaf electroscope', icon: '🍂', sub: 'Detecting & testing charge',      eq: 'divergence ∝ charge' },
  electrophorus: { title: 'Electrophorus',          icon: '🔌', sub: 'Repeatable charging by induction', eq: 'induced charge is opposite the slab' },
};

const TEACHER_NOTES: Record<Topic, string[]> = {
  production: [
    'Charging by FRICTION: rubbing two different insulators transfers electrons from one to the other. Whichever material holds electrons less strongly ends up positive; the other ends up negative — equal and opposite charges.',
    'Charging by CONDUCTION (contact): touching a charged object to a neutral conductor lets charge (the same sign) spread onto it. The originally-charged object loses some of its charge in the process.',
    'Charging by INDUCTION: bringing a charged object NEAR (not touching) a conductor separates its charges — no contact, no net charge change yet. Earthing the conductor while the inducing charge is still present lets the repelled charge escape, leaving a net charge OPPOSITE to the inducing object once the earth connection and the object are both removed (in that order).',
    'A key exam distinction: conduction leaves the object with the SAME sign of charge as the charging body; induction leaves it with the OPPOSITE sign.',
    'The order of steps matters for induction: the earth connection must be broken BEFORE the charged rod is taken away — if the rod is removed first, the separated charges simply recombine and no net charge is left behind.',
  ],
  electroscope: [
    'A gold-leaf electroscope detects and estimates charge: charge spreads down the cap, rod, and onto the two thin leaves, which — carrying the same sign — repel each other and diverge.',
    'Charging BY CONTACT: touch a charged rod to the cap; some charge transfers on, spreads through the instrument, and the leaves diverge and STAY diverged once the rod is removed.',
    'TESTING the sign of an unknown charge: bring it near the cap of an already-charged electroscope (no contact). If the leaves diverge FURTHER, the unknown charge has the SAME sign as the electroscope. If the leaves diverge LESS, it has the OPPOSITE sign.',
    'This works by induction at the cap: a like charge repels the electroscope\u2019s own charge further down toward the leaves (more divergence); an unlike charge attracts it back up toward the cap (less divergence).',
    'An electroscope can also be charged BY INDUCTION (earthing the case while a charged rod is held near the cap, then removing the earth before the rod) — giving it a charge opposite to the rod, the same principle as the electrophorus.',
  ],
  electrophorus: [
    'An electrophorus is a device for producing charge repeatedly from a SINGLE charging of an insulating slab — the slab itself is charged once (by friction) and never touched again.',
    'Sequence: place the metal disc on the charged slab (induction separates its charges) → touch the disc briefly to earth it (the repelled charge escapes) → lift the disc by its INSULATING handle.',
    'The disc lifts away carrying a net charge OPPOSITE to the slab\u2019s charge — if the slab is negative, the disc becomes positive.',
    'Because the slab\u2019s own charge is never used up (only induction happens, no charge transfers to or from the slab), this process can be repeated many times from a single rubbing of the slab.',
    'The insulating handle is essential — touching the metal disc directly (instead of through the handle) would earth it through your hand at the wrong moment and prevent it from carrying charge away.',
  ],
};

const EXERCISES: Record<Topic, { q: string; a: string }[]> = {
  production: [
    { q: 'An ebonite rod is rubbed with fur and becomes negatively charged. What happens to the fur, and why?', a: 'The fur becomes positively charged. Rubbing transfers electrons from the fur to the rod (since the rod holds electrons more strongly here), leaving the fur short of electrons — positively charged — while the rod gains the electrons and becomes negative.' },
    { q: 'A positively charged rod touches a neutral metal sphere on an insulating stand. State the sign of charge left on the sphere.', a: 'Positive — the same sign as the charging rod, since conduction transfers charge of the same sign onto the object touched.' },
    { q: 'Describe how to charge a metal sphere negatively using a POSITIVELY charged rod, without ever touching the rod to the sphere.', a: 'Bring the positive rod close to the sphere (inducing separation of charge — the near side becomes negative, the far side positive). Earth the sphere while the rod is still near, letting the repelled positive charge flow to earth. Disconnect the earth first, THEN remove the rod. The sphere is left with a net negative charge — opposite to the rod.' },
  ],
  electroscope: [
    { q: 'A charged electroscope has its leaves diverged. An unknown charged rod is brought near the cap and the leaves diverge further. What can you conclude about the rod\u2019s charge?', a: 'The rod carries the SAME sign of charge as the electroscope — a like charge repels the electroscope\u2019s charge further down onto the leaves, increasing the divergence.' },
    { q: 'Explain why the leaves of an electroscope diverge when it is charged.', a: 'Charge spreads through the cap, rod, and onto both leaves. Since both leaves carry the same sign, they repel each other and swing apart.' },
    { q: 'A student touches a charged rod to the cap of a neutral electroscope, then removes the rod. Describe and explain what is observed.', a: 'The leaves diverge as the rod touches (charge spreading onto them) and REMAIN diverged after the rod is removed, since the electroscope has now genuinely been charged by contact and retains that charge.' },
  ],
  electrophorus: [
    { q: 'Explain why the metal disc of an electrophorus becomes charged even though it never touches the (already charged) slab with a bare conducting path carrying charge from the slab.', a: 'The disc becomes charged by INDUCTION, not by charge transfer from the slab. The slab\u2019s fixed charge polarises the disc (separates its own charges); earthing the disc lets the repelled charge escape, leaving the disc with an induced charge of its own once the earth and then the slab contact are removed.' },
    { q: 'Why can an electrophorus be used repeatedly without re-charging the insulating slab?', a: 'The slab\u2019s charge is never transferred away — it only induces a redistribution of charge on the disc each time. Since the slab\u2019s own charge is untouched, the same slab can induce a fresh charge on the disc again and again.' },
    { q: 'State the correct order of steps for using an electrophorus, and explain why the order matters.', a: 'Lower the disc onto the slab → earth the disc (e.g., touch it) → remove the earth connection → THEN lift the disc away. If the disc were lifted before removing the earth connection, charge would simply flow back from earth as it left, and the disc would end up uncharged.' },
  ],
};

function StatRow({ label, value, unit, color }: { label: string; value: string; unit: string; color: string }) {
  return (
    <div className="flex justify-between items-center rounded-lg bg-gray-50 px-3 py-2">
      <span className="text-xs text-gray-500">{label}</span>
      <span className={`text-xs font-semibold tabular-nums ${color}`}>{value} <span className="text-gray-400 font-normal">{unit}</span></span>
    </div>
  );
}

export default function ElectrostaticsChargingPage() {
  const [topic, setTopic] = useState<Topic>('production');
  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [openEx, setOpenEx] = useState<number | null>(null);
  const [activeCurricula, setActiveCurricula] = useState(['WAEC', 'IGCSE', 'SAT']);

  const [method, setMethod] = useState<ChargingMethod>('friction');
  const [chargingPhaseLabel, setChargingPhaseLabel] = useState('');

  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>('charging');
  const [rodSign, setRodSign] = useState<1 | -1>(-1);
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(-1);
  const [liveDivergence, setLiveDivergence] = useState(0);

  const [electrophorusCycle, setElectrophorusCycle] = useState(0);

  const reset = useCallback(() => {
    setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1);
    setElectrophorusCycle(0);
  }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  const canvasBoxRef = useRef<HTMLDivElement>(null);
  const canvasSize = useResponsiveCanvasSize(canvasBoxRef, 660, 320, 980);

  return (
    <>
      <AppHeader />
      <main className="min-h-screen bg-gray-50">
        <section className="border-b border-gray-200 bg-white">
          <div className="mx-auto max-w-[100rem] px-4 sm:px-6 py-4">
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div>
                <p className="text-xs text-gray-400 mb-0.5">Electricity · Electrostatics</p>
                <h1 className="text-lg font-semibold text-gray-900">Charging Objects</h1>
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
                {topic === 'production' && (
                  <ChargingMethodsCanvas key={resetKey} method={method}
                    isRunning={isRunning} isPaused={isPaused} onPhaseChange={setChargingPhaseLabel}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electroscope' && (
                  <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
                    isRunning={isRunning} isPaused={isPaused} onTick={setLiveDivergence}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
                {topic === 'electrophorus' && (
                  <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
                    cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)}
                    width={canvasSize.width} height={canvasSize.height} />
                )}
              </div>

              <div className="flex flex-wrap items-center justify-between gap-2">
                <SimulationControls isRunning={isRunning} isPaused={isPaused}
                  onRun={() => { setIsRunning(true); setIsPaused(false); }}
                  onPause={() => setIsPaused(p => !p)} onReset={reset} />
                <EmbedButton path="/embed/electrostatics-charging"
                  title={`${TOPIC_META[topic].title} — A-Factor STEM Studio`}
                  params={
                    topic === 'production' ? { topic, method }
                    : topic === 'electroscope' ? { topic, mode: electroscopeMode, rod: rodSign, es: electroscopeSign }
                    : { topic }
                  } />
              </div>

              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-4">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide">Parameters</p>

                {topic === 'production' && (
                  <div className="flex flex-col gap-2">
                    {(['friction', 'conduction', 'induction'] as const).map(m => (
                      <button key={m} onClick={() => setMethod(m)}
                        className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                          method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                  </div>
                )}

                {topic === 'electroscope' && <>
                  <div className="flex gap-2">
                    {(['charging', 'testing'] as const).map(m => (
                      <button key={m} onClick={() => setElectroscopeMode(m)}
                        className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                          electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                        }`}>{m}</button>
                    ))}
                  </div>
                  {electroscopeMode === 'testing' && (
                    <div className="space-y-1.5">
                      <span className="text-xs text-gray-500">Electroscope&apos;s existing charge</span>
                      <div className="flex gap-2">
                        {([1, -1] as const).map(sgn => (
                          <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                            className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                              electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                            }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                        ))}
                      </div>
                    </div>
                  )}
                  <div className="space-y-1.5">
                    <span className="text-xs text-gray-500">{electroscopeMode === 'charging' ? 'Charging rod' : 'Test rod'}</span>
                    <div className="flex gap-2">
                      {([1, -1] as const).map(sgn => (
                        <button key={sgn} onClick={() => setRodSign(sgn)}
                          className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                            rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                          }`}>{sgn > 0 ? 'Positive (+)' : 'Negative (−)'}</button>
                      ))}
                    </div>
                  </div>
                </>}

                {topic === 'electrophorus' && (
                  <p className="text-xs text-gray-500 leading-relaxed">Press Run to lower the disc, earth it, and lift it away. Press Run again afterwards to repeat the cycle from the same charged slab.</p>
                )}
              </div>
            </div>

            <div className="space-y-3">
              <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-gray-400 uppercase tracking-wide mb-3">Calculated</p>
                <div className="space-y-2">
                  {topic === 'production' && <>
                    <StatRow label="Method" value={method} unit="" color="text-indigo-600" />
                    <StatRow label="Current phase" value={chargingPhaseLabel || '—'} unit="" color="text-emerald-600" />
                  </>}
                  {topic === 'electroscope' && <>
                    <StatRow label="Mode" value={electroscopeMode} unit="" color="text-indigo-600" />
                    <StatRow label="Live divergence" value={liveDivergence.toFixed(0)} unit="°" color="text-emerald-600" />
                    {electroscopeMode === 'testing' && (
                      <StatRow label="Relationship" value={rodSign === electroscopeSign ? 'same sign → more' : 'opposite sign → less'} unit="" color="text-amber-600" />
                    )}
                  </>}
                  {topic === 'electrophorus' && <>
                    <StatRow label="Cycles completed" value={electrophorusCycle.toString()} unit="" color="text-indigo-600" />
                    <StatRow label="Slab charge used" value="none — reusable" unit="" color="text-emerald-600" />
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

echo "  → src/app/embed/electrostatics-charging/page.tsx"
cat > "src/app/embed/electrostatics-charging/page.tsx" << 'AFEOF'
'use client';
import { Suspense, useState, useCallback, useEffect, useRef } from 'react';
import { useSearchParams } from 'next/navigation';
import { ChargingMethodsCanvas, ChargingMethod } from '@/components/simulation/ChargingMethodsCanvas';
import { ElectroscopeCanvas, ElectroscopeMode } from '@/components/simulation/ElectroscopeCanvas';
import { ElectrophorusCanvas } from '@/components/simulation/ElectrophorusCanvas';
import { SimulationControls } from '@/components/simulation/SimulationControls';

type Topic = 'production' | 'electroscope' | 'electrophorus';

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

function ElectrostaticsChargingEmbedInner() {
  const sp = useSearchParams();
  const topic = ((): Topic => {
    const t = sp.get('topic');
    return t === 'electroscope' || t === 'electrophorus' ? t : 'production';
  })();
  const showControls = sp.get('controls') !== '0';

  const [method, setMethod] = useState<ChargingMethod>(() => {
    const m = sp.get('method');
    return m === 'conduction' || m === 'induction' ? m : 'friction';
  });
  const [electroscopeMode, setElectroscopeMode] = useState<ElectroscopeMode>(() => (sp.get('mode') === 'testing' ? 'testing' : 'charging'));
  const [rodSign, setRodSign] = useState<1 | -1>(() => (sp.get('rod') === '-1' ? -1 : 1));
  const [electroscopeSign, setElectroscopeSign] = useState<1 | -1>(() => (sp.get('es') === '1' ? 1 : -1));

  const [isRunning, setIsRunning] = useState(false);
  const [isPaused, setIsPaused] = useState(false);
  const [resetKey, setResetKey] = useState(0);
  const [electrophorusCycle, setElectrophorusCycle] = useState(0);
  const reset = useCallback(() => { setIsRunning(false); setIsPaused(false); setResetKey(k => k + 1); setElectrophorusCycle(0); }, []);
  const resetTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(() => {
    if (resetTimer.current) clearTimeout(resetTimer.current);
    resetTimer.current = setTimeout(reset, 100);
  }, [topic, method, electroscopeMode, rodSign, electroscopeSign, reset]);

  return (
    <div className="mx-auto max-w-2xl space-y-3 p-3 sm:p-4">
      {topic === 'production' && (
        <ChargingMethodsCanvas key={resetKey} method={method} isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electroscope' && (
        <ElectroscopeCanvas key={resetKey} mode={electroscopeMode} rodSign={rodSign} electroscopeSign={electroscopeSign}
          isRunning={isRunning} isPaused={isPaused} width={640} height={300} />
      )}
      {topic === 'electrophorus' && (
        <ElectrophorusCanvas key={resetKey} isRunning={isRunning} isPaused={isPaused}
          cycleCount={electrophorusCycle} onCycleComplete={() => setElectrophorusCycle(c => c + 1)} width={640} height={300} />
      )}
      <SimulationControls isRunning={isRunning} isPaused={isPaused}
        onRun={() => { setIsRunning(true); setIsPaused(false); }}
        onPause={() => setIsPaused(p => !p)} onReset={reset} />
      {showControls && (
        <div className="rounded-2xl border border-gray-200 bg-white p-4 shadow-sm space-y-3">
          <p className="text-xs font-medium uppercase tracking-wide text-gray-400">Parameters</p>
          {topic === 'production' && (
            <div className="flex flex-col gap-2">
              {(['friction', 'conduction', 'induction'] as const).map(m => (
                <button key={m} onClick={() => setMethod(m)}
                  className={`rounded-lg border px-3 py-2 text-xs font-medium capitalize text-left transition ${
                    method === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
            </div>
          )}
          {topic === 'electroscope' && <>
            <div className="flex gap-2">
              {(['charging', 'testing'] as const).map(m => (
                <button key={m} onClick={() => setElectroscopeMode(m)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium capitalize transition ${
                    electroscopeMode === m ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>{m}</button>
              ))}
            </div>
            {electroscopeMode === 'testing' && (
              <div className="flex gap-2">
                {([1, -1] as const).map(sgn => (
                  <button key={sgn} onClick={() => setElectroscopeSign(sgn)}
                    className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                      electroscopeSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                    }`}>Electroscope: {sgn > 0 ? '+' : '−'}</button>
                ))}
              </div>
            )}
            <div className="flex gap-2">
              {([1, -1] as const).map(sgn => (
                <button key={sgn} onClick={() => setRodSign(sgn)}
                  className={`flex-1 rounded-lg border px-2 py-2 text-xs font-medium transition ${
                    rodSign === sgn ? 'border-indigo-300 bg-indigo-50 text-indigo-700' : 'border-gray-200 bg-white text-gray-500'
                  }`}>Rod: {sgn > 0 ? '+' : '−'}</button>
              ))}
            </div>
          </>}
          {topic === 'electrophorus' && (
            <p className="text-xs text-gray-500">Press Run to lower the disc, earth it, and lift it away.</p>
          )}
        </div>
      )}
      <PoweredBy />
    </div>
  );
}

export default function ElectrostaticsChargingEmbedPage() {
  return (
    <Suspense fallback={<div className="p-8 text-center text-xs text-gray-400">Loading simulation…</div>}>
      <ElectrostaticsChargingEmbedInner />
    </Suspense>
  );
}
AFEOF

echo "  → src/app/simulations/page.tsx"
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
echo "✓ Patch v24 applied — 7 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/electrostatics-charging -- all three tabs:"
echo "  Production of charges, Gold-leaf electroscope, Electrophorus."
echo ""
echo "Coulomb's law / electric fields / potential & capacitors are next —"
echo "the physics for all of those is already in electrostatics.ts,"
echo "verified against textbook values, ready for the following patches."
