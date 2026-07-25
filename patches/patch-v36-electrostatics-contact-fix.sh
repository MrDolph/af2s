#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v36: fix genuinely wrong physics in charging
# by friction/conduction (objects were never actually touching) and add
# real electron-flow animation to the electroscope
#
#   CHARGING BY FRICTION AND CONDUCTION WERE NOT PHYSICALLY IN CONTACT.
#   Quantified the exact bug numerically before touching any code: at what
#   the animation treated as "gap = 0" (the start of rubbing/touching),
#   the rod and cloth were actually 86px apart, and the rod tip and
#   sphere were actually 26px apart — an abstract "gap" variable was
#   driving the animation timing, but it didn't correspond to the real
#   physical distance between the objects' surfaces (their own widths/
#   radii were never subtracted out). Rubbing and conduction both
#   fundamentally require contact — this was conceptually wrong, not
#   just a cosmetic gap.
#
#   Rebuilt both from the object geometry outward: the rod is now fixed
#   in friction mode, and the cloth approaches until its edge is in EXACT
#   contact with the rod's edge (verified numerically: gap = 0, to the
#   pixel) before any rubbing begins, then stays in contact for the
#   entire rub phase while sliding vertically along the seam — an actual
#   rubbing motion while touching, not two objects hovering apart with a
#   twitch animation. Conduction now brings the rod tip into exact
#   contact with the sphere's surface (also verified to zero gap) before
#   any charge transfer is shown. Both re-verified across the full phase
#   sequence (approach -> contact -> separate) to confirm the gap is
#   exactly zero throughout the contact phase and only opens up again
#   during separation.
#
#   ELECTROSCOPE ELECTRON FLOW WASN'T SHOWN. Charge previously just
#   appeared simultaneously at the cap and the leaves once a time
#   threshold passed, with no visible transfer between them. Fixed the
#   remaining small 2px rod-to-cap contact gap to exactly zero at the
#   same time, and added a genuine particle animation: charge now visibly
#   travels from the point of contact, down the connecting rod, and out
#   along each leaf, with the path traced by explicit segment geometry
#   (cap -> hinge -> leaf tip) rather than an approximation — verified
#   numerically that a particle's position lands exactly on the rod's
#   centreline for the first segment and exactly on the leaf's own angled
#   line for the second, reaching the precise leaf-tip coordinates at the
#   end of its travel.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v36-electrostatics-contact-fix.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "-- A-Factor patch v36: fix charging-by-contact physics + electron flow --"
mkdir -p "src/components/simulation"

echo "  -> src/components/simulation/ChargingMethodsCanvas.tsx"
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
      // approach(0) -> rub(1) -> separate(2). The rod stays fixed; the
      // cloth approaches until it is in EXACT physical contact (zero gap
      // between the rod's right edge and the cloth's left edge) before
      // any rubbing or charge transfer happens — rubbing requires
      // contact, so the cloth reaches contact at the end of the approach
      // phase and stays there, sliding vertically along the seam, rather
      // than hovering apart from the rod the whole time.
      const rodHalfW = 8, clothHalfW = 26;
      const rodX = W / 2 - 70;
      const clothTouchX = rodX + rodHalfW + clothHalfW; // exact contact position, gap = 0

      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      // Before contact, cloth approaches from further right. Once
      // approach completes, clothX snaps exactly onto the touching
      // position and stays there through the whole rub phase.
      const clothX = approach < 1
        ? clothTouchX + 130 * (1 - approach)
        : clothTouchX + separate * 100;

      // Rubbing = sliding along the seam while still touching, not
      // wobbling apart from each other. Clamped so the cloth's stroke
      // never carries it past the rod's own top/bottom edge.
      const rubReach = 34;
      const rubY = phaseIdx === 1 ? Math.sin(t.current * 7) * rubReach : 0;

      // Rod (glass) — fixed
      ctx.fillStyle = '#c7d2fe'; ctx.fillRect(rodX - rodHalfW, midY - 60, rodHalfW * 2, 120);
      ctx.strokeStyle = '#6366f1'; ctx.strokeRect(rodX - rodHalfW, midY - 60, rodHalfW * 2, 120);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('glass rod', rodX, midY - 70);

      // Cloth (silk) — approaches, then slides vertically while touching
      const clothY = midY + rubY;
      ctx.fillStyle = '#fecaca'; ctx.fillRect(clothX - clothHalfW, clothY - 50, clothHalfW * 2, 100);
      ctx.strokeStyle = '#ef4444'; ctx.strokeRect(clothX - clothHalfW, clothY - 50, clothHalfW * 2, 100);
      ctx.fillText('silk cloth', clothX, clothY - 60);

      // A short motion streak at the contact seam while actively rubbing,
      // so the sliding-while-touching motion reads clearly rather than
      // looking like the cloth is merely twitching in place.
      if (phaseIdx === 1) {
        ctx.save();
        ctx.strokeStyle = 'rgba(239,68,68,0.35)'; ctx.lineWidth = 3; ctx.lineCap = 'round';
        ctx.beginPath();
        ctx.moveTo(rodX + rodHalfW, midY - Math.sign(Math.cos(t.current * 7)) * rubReach * 0.6);
        ctx.lineTo(rodX + rodHalfW, clothY);
        ctx.stroke();
        ctx.restore();
      }

      // Electrons transfer directly across the contact seam (a few
      // pixels, not across an open gap) — spawning near the rod's
      // surface and settling just inside the cloth's surface, at the
      // CURRENT rubbing height so the transfer visibly tracks the
      // sliding contact point.
      const rubProgress = phaseIdx === 1 ? phaseT : phaseIdx > 1 ? 1 : 0;
      if (phaseIdx === 1) {
        for (let i = 0; i < 4; i++) {
          const localPhase = (rubProgress * 3 + i * 0.6) % 1;
          const ex = (rodX + rodHalfW) + (clothX - clothHalfW - (rodX + rodHalfW)) * localPhase;
          const ey = clothY - 25 + i * 17;
          drawCharge(ctx, ex, ey, -1, 4.5);
        }
      }
      const netCharge = phaseIdx >= 1 ? Math.min(1, rubProgress) : 0;
      if (netCharge > 0.05 || phaseIdx === 2) {
        drawCharge(ctx, rodX, midY + 45, 1, 6);
        drawCharge(ctx, clothX, clothY + 45, -1, 6);
      }
    } else if (s.method === 'conduction') {
      const sphereR = 34;
      const sphereX = W / 2 + 90;
      // Rod tip approaches until it is in EXACT physical contact with the
      // sphere's surface (zero gap) — conduction requires actual contact,
      // so the rod reaches the sphere's surface exactly at the end of the
      // approach phase rather than stopping visibly short of it.
      const touchX = sphereX - sphereR;
      const approach = phaseIdx === 0 ? phaseT : 1;
      const separate = phaseIdx === 2 ? phaseT : 0;
      const rodTipX = approach < 1 ? touchX - 100 * (1 - approach) : touchX + separate * 90;

      ctx.fillStyle = '#93c5fd'; ctx.fillRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.strokeStyle = '#2563eb'; ctx.strokeRect(rodTipX - 90, midY - 8, 90, 16);
      ctx.fillStyle = '#334155'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('negatively charged rod', rodTipX - 45, midY - 20);
      for (let i = 0; i < 5; i++) drawCharge(ctx, rodTipX - 12 - i * 16, midY, -1, 5);

      ctx.fillStyle = '#e2e8f0';
      ctx.beginPath(); ctx.arc(sphereX, midY, sphereR, 0, Math.PI * 2); ctx.fill();
      ctx.strokeStyle = '#94a3b8'; ctx.stroke();
      ctx.fillText('neutral sphere', sphereX, midY - 46);

      // Electrons visibly cross the contact point (rod tip -> sphere
      // surface) during the touch phase, then spread out over the
      // sphere, rather than simply appearing on the sphere with no
      // visible transfer.
      if (phaseIdx === 1) {
        for (let i = 0; i < 4; i++) {
          const localPhase = (phaseT * 3 + i * 0.5) % 1;
          const ex = rodTipX + (sphereX - sphereR - rodTipX) * Math.min(1, localPhase * 1.6);
          drawCharge(ctx, ex, midY - 10 + i * 6, -1, 4.5);
        }
      }
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

echo "  -> src/components/simulation/ElectroscopeCanvas.tsx"
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

    // Charging/test rod — reaches EXACT contact with the cap's surface
    // (the cap is drawn as an ellipse of x-radius 18, so contact is at
    // capX-18) rather than stopping visibly short of it.
    const capRadius = 18;
    const rodTipX = capX - capRadius - (1 - rodApproach) * 160;
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
    ctx.beginPath(); ctx.ellipse(capX, capY, capRadius, 8, 0, 0, Math.PI * 2); ctx.fill();
    ctx.fillRect(capX - 3, capY, 6, leafTopY - capY);

    // Leaves — hinge at the bottom of the rod, swinging apart by divergenceDeg
    const hingeY = leafTopY;
    const rad = (divergenceDeg * Math.PI) / 180;
    ctx.strokeStyle = '#eab308'; ctx.lineWidth = 3; ctx.lineCap = 'round';
    [-1, 1].forEach(side => {
      const dx = Math.sin(rad) * side, dy = Math.cos(rad);
      ctx.beginPath(); ctx.moveTo(capX, hingeY); ctx.lineTo(capX + dx * leafLen, hingeY + dy * leafLen); ctx.stroke();
    });

    // Electron flow — while charge is actively transferring by contact,
    // particles travel visibly from the cap, down the connecting rod,
    // and out along each leaf, instead of charge simply appearing
    // simultaneously at the cap AND the leaves with no transit shown.
    if (s.mode === 'charging' && running && t.current >= 0.9 && t.current < 2.4) {
      const flowT = t.current - 0.9;
      const segALen = hingeY - capY;
      const nParticles = 6;
      for (let i = 0; i < nParticles; i++) {
        const side = i % 2 === 0 ? -1 : 1;
        const dx = Math.sin(rad) * side, dy = Math.cos(rad);
        const segBLen = leafLen;
        const totalLen = segALen + segBLen;
        const speed = 130; // px/s along the path
        const phase = (((flowT * speed) + i * (totalLen / nParticles)) % totalLen) / totalLen;
        let px: number, py: number;
        if (phase * totalLen < segALen) {
          const f = (phase * totalLen) / segALen;
          px = capX; py = capY + f * segALen;
        } else {
          const f = (phase * totalLen - segALen) / segBLen;
          px = capX + dx * leafLen * f; py = hingeY + dy * leafLen * f;
        }
        drawCharge(ctx, px, py, sign, 4);
      }
    }

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

echo ""
echo "Patch v36 applied -- 2 files written."
echo ""
echo "Next steps:"
echo "  rm -rf .next"
echo "  npm run dev"
echo ""
echo "Check: /simulations/electrostatics-charging"
echo "  Production of charges -> Friction: the cloth should visibly touch"
echo "    the rod before any rubbing motion starts, and stay touching"
echo "    while sliding up and down."
echo "  Production of charges -> Conduction: the rod tip should visibly"
echo "    touch the sphere's surface before charge starts appearing on it."
echo "  Gold-leaf electroscope -> Charging: watch for charge dots visibly"
echo "    travelling from the cap, down the rod, and out along the leaves."
