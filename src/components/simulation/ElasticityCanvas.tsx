'use client';
import { useRef, useEffect, useCallback } from 'react';
import { extension, springEnergy, wireExtension, stress, strain } from '@/lib/physics/elasticity';

export type ElasticityMode = 'hooke' | 'wire';

interface Props {
  mode: ElasticityMode;
  load: number;         // N
  k: number;            // N/m (hooke mode)
  elasticLimitF: number;
  // wire mode:
  wireLength: number;   // m
  wireDiamMm: number;   // mm
  youngE: number;       // Pa
  materialName: string;
  width?: number; height?: number;
}

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

export function ElasticityCanvas({ mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName, width = 640, height = 320 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const sim = useRef({ mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName });
  sim.current = { mode, load, k, elasticLimitF, wireLength, wireDiamMm, youngE, materialName };

  const draw = useCallback(() => {
    const canvas = canvasRef.current; if (!canvas) return;
    const ctx = canvas.getContext('2d'); if (!ctx) return;
    const s = sim.current;
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);
    ctx.fillStyle = '#f8fafc'; ctx.fillRect(0, 0, W, H);

    // Ceiling
    ctx.fillStyle = '#cbd5e1'; ctx.fillRect(0, 20, W, 10);
    ctx.strokeStyle = '#94a3b8';
    for (let x = 6; x < W; x += 14) {
      ctx.beginPath(); ctx.moveTo(x, 20); ctx.lineTo(x - 6, 12); ctx.stroke();
    }

    if (s.mode === 'hooke') {
      const e = extension(s.load, s.k);                 // metres
      const beyondLimit = s.load > s.elasticLimitF;
      const eScale = 900;                                // px per metre
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
      const stretch = Math.min(e * eScale, H - 200);
      drawCoil(ctx, xLoaded, 30, natural + stretch);
      // Mass
      const mw = 56, mh = 40;
      ctx.fillStyle = beyondLimit ? '#ef4444' : '#6366f1';
      ctx.fillRect(xLoaded - mw / 2, 30 + natural + stretch, mw, mh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui';
      ctx.fillText(`${s.load.toFixed(0)}N`, xLoaded, 30 + natural + stretch + mh / 2 + 4);

      // Extension bracket
      if (stretch > 6) {
        const bx = xLoaded + 60;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + natural); ctx.lineTo(bx, 30 + natural + stretch); ctx.stroke();
        [30 + natural, 30 + natural + stretch].forEach(y => {
          ctx.beginPath(); ctx.moveTo(bx - 4, y); ctx.lineTo(bx + 4, y); ctx.stroke();
        });
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(e * 100).toFixed(1)} cm`, bx + 8, 30 + natural + stretch / 2 + 3);
      }

      ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      if (beyondLimit) {
        ctx.fillStyle = '#ef4444';
        ctx.fillText(`BEYOND THE ELASTIC LIMIT (${s.elasticLimitF}N) — permanent deformation, Hooke's law no longer holds`, W / 2, H - 30);
      } else {
        ctx.fillStyle = '#059669';
        ctx.fillText(`Hooke's law: e ∝ F   —   energy stored = ½Fe = ${springEnergy(s.k, e).toFixed(2)} J`, W / 2, H - 30);
      }
      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`k = ${s.k} N/m   F = ke check: ${s.load.toFixed(0)}N / ${s.k} = ${(e * 100).toFixed(1)} cm`, 8, H - 10);
    }

    if (s.mode === 'wire') {
      const A = Math.PI * Math.pow((s.wireDiamMm / 1000) / 2, 2);  // m²
      const e = wireExtension(s.load, s.wireLength, A, s.youngE);   // metres (tiny!)
      const sg = stress(s.load, A);
      const sn = strain(e, s.wireLength);

      const x = W / 2 - 60;
      const naturalPx = H - 150;
      // Real extensions are fractions of a millimetre — magnified ×2000 on
      // screen so students can SEE it; true values printed below.
      const MAG = 2000;
      const stretchPx = Math.min(e * MAG, 90);

      // Wire (thickness from diameter)
      ctx.strokeStyle = '#64748b'; ctx.lineWidth = Math.max(1.5, s.wireDiamMm * 3);
      ctx.beginPath(); ctx.moveTo(x, 30); ctx.lineTo(x, 30 + naturalPx + stretchPx); ctx.stroke();
      // Original end marker
      ctx.strokeStyle = '#cbd5e1'; ctx.setLineDash([4, 4]); ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(x - 70, 30 + naturalPx); ctx.lineTo(x + 150, 30 + naturalPx); ctx.stroke();
      ctx.setLineDash([]);
      // Load
      const mw = 60, mh = 40;
      ctx.fillStyle = '#6366f1';
      ctx.fillRect(x - mw / 2, 30 + naturalPx + stretchPx, mw, mh);
      ctx.fillStyle = 'white'; ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
      ctx.fillText(`${s.load.toFixed(0)}N`, x, 30 + naturalPx + stretchPx + mh / 2 + 4);
      // Extension bracket (magnified)
      if (stretchPx > 3) {
        const bx = x + 70;
        ctx.strokeStyle = '#10b981'; ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.moveTo(bx, 30 + naturalPx); ctx.lineTo(bx, 30 + naturalPx + stretchPx); ctx.stroke();
        ctx.fillStyle = '#059669'; ctx.font = 'bold 10px system-ui'; ctx.textAlign = 'left';
        ctx.fillText(`e = ${(e * 1000).toFixed(3)} mm (shown ×${MAG})`, bx + 8, 30 + naturalPx + stretchPx / 2 + 3);
      }

      // Info card
      ctx.save();
      const cx0 = W - 250, cy0 = 46;
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath(); ctx.roundRect(cx0, cy0, 236, 118, 10); ctx.fill();
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
      ];
      lines.forEach((l, i) => ctx.fillText(l, cx0 + 12, cy0 + 40 + i * 16));
      ctx.restore();

      ctx.fillStyle = '#64748b'; ctx.font = '10px system-ui'; ctx.textAlign = 'left';
      ctx.fillText(`Young's modulus is a MATERIAL property — same E whatever the wire's size. e = FL/(AE)`, 8, H - 10);
    }
  }, []);

  useEffect(() => { draw(); });

  return (
    <canvas ref={canvasRef} width={width} height={height}
      className="w-full rounded-xl border border-gray-200 bg-white" style={{ display: 'block' }} />
  );
}
