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
