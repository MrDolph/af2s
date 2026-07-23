'use client';
import { useRef, useEffect, useCallback } from 'react';
import { plasticExtension, permanentSet, springStepResponse, springEnergy, wireExtension, stress, strain, G } from '@/lib/physics/elasticity';

export type ElasticityMode = 'hooke' | 'wire';

interface Props {
  mode: ElasticityMode;
  load: number;          // N
  k: number;              // N/m (hooke mode)
  elasticLimitF: number;
  // wire mode:
  wireLength: number;     // m
  wireDiamMm: number;     // mm
  youngE: number;         // Pa
  materialName: string;
  breakingStressMPa: number;
  isRunning: boolean; isPaused: boolean;
  unloadKey: number;      // increments to trigger "remove load" (hooke, once settled)
  onSettled?: () => void;
  onBroken?: () => void;
  width?: number; height?: number;
}

type HookePhase = 'unloaded' | 'settling' | 'settled' | 'unloading' | 'recovered' | 'permanent';
type WirePhase = 'unloaded' | 'stretching' | 'stretched' | 'breaking' | 'broken';

function drawCoil(ctx: CanvasRenderingContext2D, x: number, yTop: number, len: number, coils = 10, r = 16) {
  ctx.save();
  ctx.strokeStyle = '#64748b'; ctx.lineWidth = 2.5; ctx.lineJoin = 'round';
  ctx.beginPath();
  ctx.moveTo(x, yTop);
  const seg = len / (coils + 1);
  ctx.lineTo(x, yTop + seg / 2);
  for (let i = 0; i < coils; i++) {
    ctx.lineTo(x + (i % 2 === 0 ? r : -r), yTop + seg / 2 + seg * i + seg / 2);
  }
  ctx.lineTo(x, yTop + len - seg / 2);
  ctx.lineTo(x, yTop + len);
  ctx.stroke();
  ctx.restore();
}

function easeOutCubic(x: number) { return 1 - Math.pow(1 - Math.min(Math.max(x, 0), 1), 3); }

export function ElasticityCanvas({
  mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
  isRunning, isPaused, unloadKey, onSettled, onBroken, width = 640, height = 320,
}: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const t = useRef(0);            // time since the current phase began
  const hookePhase = useRef<HookePhase>('unloaded');
  const wirePhase = useRef<WirePhase>('unloaded');
  const eAtPhaseStart = useRef(0); // extension when the current phase began (for the unloading leg)
  const lastUnloadKey = useRef(unloadKey);
  const settledFired = useRef(false);
  const brokenFired = useRef(false);
  const sim = useRef({
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  });
  sim.current = {
    mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, breakingStressMPa,
    isRunning, isPaused, onSettled, onBroken,
  };

  // Physics parameters change -> start over from unloaded.
  useEffect(() => {
    t.current = 0;
    hookePhase.current = 'unloaded';
    wirePhase.current = 'unloaded';
    eAtPhaseStart.current = 0;
    lastFrameRef.current = null;
    settledFired.current = false;
    brokenFired.current = false;
  }, [mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, breakingStressMPa]);

  // "Remove load" trigger for the hooke mode, once settled.
  useEffect(() => {
    if (unloadKey !== lastUnloadKey.current) {
      lastUnloadKey.current = unloadKey;
      if (hookePhase.current === 'settled') {
        hookePhase.current = 'unloading';
        t.current = 0;
      }
    }
  }, [unloadKey]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) {
        dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.1);
      }
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#cbd5e1'; ctx.fillRect(0, 20, W, 10);
    ctx.strokeStyle = '#94a3b8';
    for (let x = 6; x < W; x += 14) {
      ctx.beginPath(); ctx.moveTo(x, 20); ctx.lineTo(x - 6, 12); ctx.stroke();
    }

    if (s.mode === 'hooke') {
      const eEq = plasticExtension(s.load, s.k, s.elasticLimitF);
      const eLimit = s.elasticLimitF / s.k;
      const beyondLimit = s.load > s.elasticLimitF;
      const ePermanent = permanentSet(s.load, s.k, s.elasticLimitF);
      const mass = s.load / G;
      const zeta = 0.28;
      const omega = Math.sqrt(s.k / Math.max(mass, 0.01));
      const settleTime = 3.91 / (zeta * omega); // time for the 2% decay envelope

      // Advance the phase's local clock, and step transitions.
      if (dt > 0) {
        if (hookePhase.current === 'unloaded' && s.isRunning) {
          hookePhase.current = 'settling'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (hookePhase.current === 'settling' && t.current >= settleTime) {
          hookePhase.current = 'settled';
          if (!settledFired.current) { settledFired.current = true; s.onSettled?.(); }
        }
        if (hookePhase.current === 'unloading') {
          const dropSettle = 3.91 / (zeta * omega); // same envelope shape for the release leg
          if (t.current >= dropSettle) {
            hookePhase.current = ePermanent > 0.0005 ? 'permanent' : 'recovered';
          }
        }
      }

      // Current extension as a pure function of phase + local time.
      let e: number;
      if (hookePhase.current === 'unloaded') e = 0;
      else if (hookePhase.current === 'settling') e = springStepResponse(t.current, eEq, s.k, mass, zeta);
      else if (hookePhase.current === 'settled') e = eEq;
      else if (hookePhase.current === 'unloading') {
        const drop = eEq - ePermanent;
        e = eEq - springStepResponse(t.current, drop, s.k, mass, zeta);
      } else e = ePermanent; // 'recovered' (0) or 'permanent'

      const eScale = 900; // px per metre
      const natural = 90;
      const xUnloaded = W / 2 - 130, xLoaded = W / 2 + 90;

      // Reference (unloaded) spring
      drawCoil(ctx, xUnloaded, 30, natural);
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(xUnloaded - 60, 30 + natural); ctx.lineTo(xLoaded + 80, 30 + natural); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#94a3b8'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('natural length', xUnloaded, 30 + natural + 18);

      // Loaded spring
      const stretch = Math.min(Math.max(e, 0) * eScale, H - 200);
      drawCoil(ctx, xLoaded, 30, natural + stretch);
      const showMass = hookePhase.current !== 'unloaded';
      if (showMass) {
        const mw = 56, mh = 40;
        const beyondNow = e * s.k > s.elasticLimitF + 0.01;
        ctx.fillStyle = beyondNow ? '#ef4444' : '#6366f1';
        ctx.fillRect(xLoaded - mw / 2, 30 + natural + stretch, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        const shownLoad = hookePhase.current === 'unloading' || hookePhase.current === 'recovered' || hookePhase.current === 'permanent' ? 0 : s.load;
        ctx.fillText(`${shownLoad.toFixed(0)}N`, xLoaded, 30 + natural + stretch + mh / 2 + 4);
      }

      // Extension bracket
      if (stretch > 6) {
        const bx = xLoaded + 60;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + natural); ctx.lineTo(bx, 30 + natural + stretch); ctx.stroke();
        [30 + natural, 30 + natural + stretch].forEach(y => {
          ctx.beginPath(); ctx.moveTo(bx - 4, y); ctx.lineTo(bx + 4, y); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(Math.max(e, 0) * 100).toFixed(1)} cm`, bx + 8, 30 + natural + stretch / 2 + 3);
      }
      // Elastic-limit marker, so the overshoot past it is visible during settling
      const limitStretch = eLimit * eScale;
      if (limitStretch > 4 && limitStretch < H - 200) {
        ctx.strokeStyle = '#f59e0b'; ctx.setLineDash([3, 3]); ctx.lineWidth = 1;
        ctx.beginPath(); ctx.moveTo(xLoaded - 40, 30 + natural + limitStretch); ctx.lineTo(xLoaded + 40, 30 + natural + limitStretch); ctx.stroke();
        ctx.setLineDash([]);
      }

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (hookePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load and watch it settle', W / 2, H - 30);
      } else if (hookePhase.current === 'settling') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Settling — a suddenly-applied load overshoots before it damps out', W / 2, H - 30);
      } else if (hookePhase.current === 'settled' && beyondLimit) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`BEYOND THE ELASTIC LIMIT (${s.elasticLimitF}N) — permanent deformation once unloaded`, W / 2, H - 30);
      } else if (hookePhase.current === 'settled') {
        ctx.fillStyle = '#059669';
        ctx.fillText(`Settled — energy stored = ½Fe = ${springEnergy(s.k, eEq).toFixed(2)} J`, W / 2, H - 30);
      } else if (hookePhase.current === 'unloading') {
        ctx.fillStyle = '#f59e0b';
        ctx.fillText('Load removed — recovering…', W / 2, H - 30);
      } else if (hookePhase.current === 'recovered') {
        ctx.fillStyle = '#059669';
        ctx.fillText('Fully recovered to natural length — within the elastic limit', W / 2, H - 30);
      } else {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`PERMANENT SET = ${(ePermanent * 100).toFixed(1)} cm — it never returns to natural length`, W / 2, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`k = ${s.k} N/m   equilibrium: F = ke → e = ${(eEq * 100).toFixed(1)} cm`, 8, H - 10);
    }

    if (s.mode === 'wire') {
      const A = Math.PI * Math.pow((s.wireDiamMm / 1000) / 2, 2);
      const eTarget = wireExtension(s.load, s.wireLength, A, s.youngE);
      const sg = stress(s.load, A);
      const sn = strain(eTarget, s.wireLength);
      const willBreak = sg / 1e6 > s.breakingStressMPa;
      const STRETCH_DURATION = 0.8;

      if (dt > 0) {
        if (wirePhase.current === 'unloaded' && s.isRunning) {
          wirePhase.current = willBreak ? 'breaking' : 'stretching'; t.current = 0;
        } else {
          t.current += dt;
        }
        if (wirePhase.current === 'stretching' && t.current >= STRETCH_DURATION) wirePhase.current = 'stretched';
        if (wirePhase.current === 'breaking' && t.current >= STRETCH_DURATION * 0.65) {
          wirePhase.current = 'broken';
          if (!brokenFired.current) { brokenFired.current = true; s.onBroken?.(); }
        }
      }

      const progress = wirePhase.current === 'breaking'
        ? easeOutCubic(t.current / (STRETCH_DURATION * 0.65))
        : easeOutCubic(t.current / STRETCH_DURATION);
      const e = wirePhase.current === 'unloaded' ? 0
        : wirePhase.current === 'broken' ? eTarget * 0.65
        : eTarget * Math.min(progress, 1);

      const x = W / 2 - 60;
      const naturalPx = H - 150;
      // Real extensions are fractions of a millimetre — magnified ×2000 on
      // screen so students can SEE it; true values printed below.
      const MAG = 2000;
      const stretchPx = Math.min(e * MAG, 90);

      // Reference end marker
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x - 70, 30 + naturalPx); ctx.lineTo(x + 150, 30 + naturalPx); ctx.stroke();
      ctx.setLineDash([]);

      if (wirePhase.current === 'broken') {
        // Snapped: two loose ends, load fallen away.
        const breakY = 30 + naturalPx * 0.55;
        const fall = Math.min((t.current - STRETCH_DURATION * 0.65) * 260, H);
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x - 3, breakY - 6); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(x + 4, breakY + 10 + fall); ctx.lineTo(x, 30 + naturalPx + stretchPx + fall); ctx.stroke();
        const mw = 60, mh = 40;
        ctx.fillStyle = '#ef4444';
        ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx + fall, mw, mh);
        ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
        ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + fall + mh / 2 + 4);
        ctx.fillStyle = '#ef4444'; ctx.font = 'bold 12px system-ui';
        ctx.fillText('💥 SNAPPED', x, breakY - 16);
      } else {
        ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
        ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 30 + naturalPx + stretchPx); ctx.stroke();
        if (wirePhase.current !== 'unloaded') {
          const mw = 60, mh = 40;
          ctx.fillStyle = '#6366f1';
          ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx, mw, mh);
          ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
          ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + mh / 2 + 4);
        }
        if (stretchPx > 3) {
          const bx = x + 70;
          ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
          ctx.beginPath(); ctx.moveTo(bx, 30 + naturalPx); ctx.lineTo(bx, 30 + naturalPx + stretchPx); ctx.stroke();
          ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
          ctx.fillText(`e = ${(e * 1000).toFixed(3)} mm (shown ×${MAG})`, bx + 8, 30 + naturalPx + stretchPx / 2 + 3);
        }
      }

      // Info card
      ctx.save();
      const cx0 = W - 250, cy0 = 46;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(cx0, cy0, 236, 134, 10); ctx.fill();
      ctx.strokeStyle = '#e2e8f0'; ctx.stroke();
      ctx.fillStyle = '#334155'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`${s.materialName} wire`, cx0 + 12, cy0 + 20);
      ctx.font = '10px monospace'; ctx.fillStyle = '#475569';
      const lines = [
        `L = ${s.wireLength} m,  d = ${s.wireDiamMm} mm`,
        `A = πd²/4 = ${(A * 1e6).toFixed(4)} mm²`,
        `stress σ = F/A = ${(sg / 1e6).toFixed(1)} MPa`,
        `strain ε = e/L = ${sn.toExponential(2)}`,
        `E = σ/ε = ${(s.youngE / 1e9).toFixed(0)} GPa`,
        `breaks at ${s.breakingStressMPa} MPa`,
      ];
      lines.forEach((l, i) => ctx.fillText(l, cx0 + 12, cy0 + 40 + i * 16));
      ctx.restore();

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (wirePhase.current === 'unloaded') {
        ctx.fillStyle = '#6366f1';
        ctx.fillText('Press Run to hang the load', W / 2 - 60, H - 30);
      } else if (willBreak) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`σ = ${(sg / 1e6).toFixed(0)} MPa exceeds ${s.materialName}'s breaking stress`, W / 2 - 60, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Young's modulus is a MATERIAL property — same E whatever the wire's size. e = FL/(AE)`, 8, H - 10);
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
