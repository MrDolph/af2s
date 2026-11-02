'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  BandTheoryParams, MaterialType,
  MATERIALS, generateCarriers, updateCarriers,
  kT_eV, intrinsicConcentration, dopedFermiLevel, carrierConcentrations, fermiDirac,
  type Carrier, type BandTheoryStats,
} from '@/lib/physics/bandTheory';

interface Props {
  params: BandTheoryParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: BandTheoryStats) => void;
  width?: number;
  height?: number;
}

export function BandTheoryCanvas({ params, isRunning, isPaused, onTick, width = 720, height = 500 }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, isRunning, isPaused, onTick });
  propsRef.current = { params, isRunning, isPaused, onTick };

  const carriersRef = useRef<Carrier[]>([]);
  const initCarriers = useCallback(() => {
    const p = propsRef.current.params;
    const mat = MATERIALS[p.material];
    if (!mat) return;
    const conc = Math.pow(10, p.dopingConcentration);
    carriersRef.current = generateCarriers(mat, p.temperature, p.dopingType, conc, 100);
  }, []);

  useEffect(() => {
    initCarriers();
  }, [initCarriers, params.material, params.temperature, params.dopingType, params.dopingConcentration]);

  const draw = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current;

    const dpr = window.devicePixelRatio || 1;
    const displayW = width;
    const displayH = height;
    if (canvas.width !== Math.floor(displayW * dpr) || canvas.height !== Math.floor(displayH * dpr)) {
      canvas.width = Math.floor(displayW * dpr);
      canvas.height = Math.floor(displayH * dpr);
    }
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) {
      if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05);
      lastFrameRef.current = timestamp;
    } else {
      lastFrameRef.current = timestamp ?? null;
    }

    const p = s.params;
    const mat = MATERIALS[p.material];
    if (!mat) { rafRef.current = requestAnimationFrame(draw); return; }

    const Eg = mat.bandGap;
    const isConductor = mat.type === 'conductor';
    const kT = kT_eV(p.temperature);
    const conc = Math.pow(10, p.dopingConcentration);
    const Ef = isConductor ? mat.fermiLevel : dopedFermiLevel(Eg, p.temperature, p.dopingType, conc);

    // Evolution
    if (dt > 0 && s.isRunning && !s.isPaused && p.animateCarriers) {
      carriersRef.current = updateCarriers(carriersRef.current, dt, p.temperature, p.speed);
      timeRef.current += dt * p.speed;

    }

    // Background
    ctx.clearRect(0, 0, displayW, displayH);
    ctx.fillStyle = '#0b1021';
    ctx.fillRect(0, 0, displayW, displayH);

    drawGrid(ctx, displayW, displayH);

    const marginL = 50;
    const marginR = 20;
    const marginT = 40;
    const marginB = 125;
    const distributionW = p.showDOS ? Math.min(125, displayW * 0.28) : 0;
    const plotW = displayW - marginL - marginR - distributionW;
    const plotH = displayH - marginT - marginB;

    // Energy scale: max 8 eV visible
    const E_MIN = isConductor ? 0 : -2;
    const E_MAX = (isConductor ? mat.fermiLevel + 1 : Eg + 2) / p.zoom;
    const eScale = plotH / (E_MAX - E_MIN);
    const toY = (E: number) => marginT + plotH - (E - E_MIN) * eScale;
    const toX = (x: number) => marginL + (x / 60) * plotW;

    // Draw lattice sites (vertical lines)
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.08)';
    ctx.lineWidth = 1;
    for (let i = 0; i <= 20; i++) {
      const x = toX(i * 3);
      ctx.beginPath(); ctx.moveTo(x, marginT); ctx.lineTo(x, marginT + plotH); ctx.stroke();
    }

    // Draw bands
    if (!isConductor) {
      // Valence band (filled purple-blue)
      const vbTop = toY(0);
      const vbBot = toY(-2);
      const gradV = ctx.createLinearGradient(0, vbTop, 0, vbBot);
      gradV.addColorStop(0, 'rgba(99, 102, 241, 0.35)');
      gradV.addColorStop(1, 'rgba(99, 102, 241, 0.08)');
      ctx.fillStyle = gradV;
      ctx.fillRect(marginL, vbTop, plotW, vbBot - vbTop);
      ctx.strokeStyle = 'rgba(99, 102, 241, 0.6)';
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(marginL, vbTop); ctx.lineTo(marginL + plotW, vbTop); ctx.stroke();

      // Conduction band (filled blue-cyan)
      const cbBot = toY(Eg);
      const cbTop = toY(Eg + 2);
      const gradC = ctx.createLinearGradient(0, cbBot, 0, cbTop);
      gradC.addColorStop(0, 'rgba(6, 182, 212, 0.35)');
      gradC.addColorStop(1, 'rgba(6, 182, 212, 0.08)');
      ctx.fillStyle = gradC;
      ctx.fillRect(marginL, cbBot, plotW, cbTop - cbBot);
      ctx.strokeStyle = 'rgba(6, 182, 212, 0.6)';
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(marginL, cbBot); ctx.lineTo(marginL + plotW, cbBot); ctx.stroke();

      // Band gap label
      if (p.showBandGap) {
        ctx.fillStyle = 'rgba(251, 191, 36, 0.7)';
        ctx.font = 'bold 11px system-ui';
        ctx.textAlign = 'left';
        ctx.fillText(`Eg = ${Eg.toFixed(2)} eV`, marginL + 6, toY(Eg / 2) + 4);
        // Arrow
        ctx.strokeStyle = 'rgba(251, 191, 36, 0.5)';
        ctx.lineWidth = 1;
        const ax = marginL + plotW - 30;
        ctx.beginPath(); ctx.moveTo(ax, vbTop); ctx.lineTo(ax, cbBot); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(ax - 3, vbTop + 5); ctx.lineTo(ax, vbTop); ctx.lineTo(ax + 3, vbTop + 5); ctx.stroke();
        ctx.beginPath(); ctx.moveTo(ax - 3, cbBot - 5); ctx.lineTo(ax, cbBot); ctx.lineTo(ax + 3, cbBot - 5); ctx.stroke();
      }
    } else {
      // Conductor: overlapping bands
      const overlapTop = toY(Math.min(E_MAX, mat.fermiLevel + 1));
      const overlapBot = toY(0);
      const gradO = ctx.createLinearGradient(0, overlapTop, 0, overlapBot);
      gradO.addColorStop(0, 'rgba(245, 158, 11, 0.25)');
      gradO.addColorStop(1, 'rgba(245, 158, 11, 0.08)');
      ctx.fillStyle = gradO;
      ctx.fillRect(marginL, overlapTop, plotW, overlapBot - overlapTop);
      ctx.strokeStyle = 'rgba(245, 158, 11, 0.6)';
      ctx.lineWidth = 2;
      ctx.beginPath(); ctx.moveTo(marginL, toY(0)); ctx.lineTo(marginL + plotW, toY(0)); ctx.stroke();
      ctx.fillStyle = 'rgba(245, 158, 11, 0.7)';
      ctx.font = 'bold 11px system-ui';
      ctx.textAlign = 'left';
      ctx.fillText('Overlapping bands — no gap', marginL + 6, toY(0.5));
    }

    // Fermi level
    if (p.showFermiLevel) {
      const efY = toY(Ef);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.4)';
      ctx.setLineDash([5, 3]);
      ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.moveTo(marginL, efY); ctx.lineTo(marginL + plotW, efY); ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = 'rgba(255, 255, 255, 0.6)';
      ctx.font = 'bold 10px system-ui';
      ctx.textAlign = 'right';
      ctx.fillText(`Ef = ${Ef.toFixed(2)} eV`, marginL + plotW, efY - 5);
    }

    // Thermal energy indicator
    if (p.showThermalEnergy && p.temperature > 0) {
      const ktY = toY(Ef + kT);
      ctx.strokeStyle = 'rgba(244, 63, 94, 0.3)';
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(marginL + plotW - 60, toY(Ef)); ctx.lineTo(marginL + plotW - 60, ktY); ctx.stroke();
      ctx.fillStyle = 'rgba(244, 63, 94, 0.5)';
      ctx.font = '9px system-ui';
      ctx.textAlign = 'left';
      ctx.fillText(`kT = ${kT.toFixed(3)} eV`, marginL + plotW - 55, toY(Ef) - (toY(Ef) - ktY) / 2 + 3);
    }

    ctx.save(); ctx.beginPath(); ctx.rect(marginL, marginT, plotW, plotH); ctx.clip();
    // Carriers
    const carriers = carriersRef.current;
    if (p.showElectrons) {
      carriers.filter((c) => c.type === 'electron').forEach((c) => {
        const cx = toX(c.x);
        const cy = toY(c.y);
        const glow = ctx.createRadialGradient(cx, cy, 0, cx, cy, 5);
        glow.addColorStop(0, 'rgba(59, 130, 246, 0.6)');
        glow.addColorStop(1, 'rgba(59, 130, 246, 0)');
        ctx.fillStyle = glow;
        ctx.beginPath(); ctx.arc(cx, cy, 5, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#60a5fa';
        ctx.beginPath(); ctx.arc(cx, cy, 2, 0, Math.PI * 2); ctx.fill();
      });
    }
    if (p.showHoles) {
      carriers.filter((c) => c.type === 'hole').forEach((c) => {
        const cx = toX(c.x);
        const cy = toY(c.y);
        ctx.strokeStyle = 'rgba(244, 63, 94, 0.6)';
        ctx.lineWidth = 1.5;
        ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI * 2); ctx.stroke();
        ctx.fillStyle = 'rgba(244, 63, 94, 0.3)';
        ctx.beginPath(); ctx.arc(cx, cy, 4, 0, Math.PI * 2); ctx.fill();
        ctx.fillStyle = '#f43f5e';
        ctx.font = 'bold 7px system-ui';
        ctx.textAlign = 'center';
        ctx.fillText('+', cx, cy + 2);
      });
    }

    ctx.restore();
    // Axis labels
    ctx.fillStyle = 'rgba(148, 163, 184, 0.5)';
    ctx.font = '10px system-ui';
    ctx.textAlign = 'right';
    for (let e = E_MIN; e <= E_MAX; e += 1) {
      const y = toY(e);
      ctx.fillText(`${e} eV`, marginL - 6, y + 3);
      ctx.strokeStyle = 'rgba(148, 163, 184, 0.15)';
      ctx.lineWidth = 1;
      ctx.beginPath(); ctx.moveTo(marginL, y); ctx.lineTo(marginL + plotW, y); ctx.stroke();
    }
    ctx.fillStyle = 'rgba(148, 163, 184, 0.4)';
    ctx.font = '9px system-ui';
    ctx.textAlign = 'center';
    for (let i = 0; i <= 6; i++) {
      const x = toX(i * 10);
      ctx.fillText(`${i * 10}`, x, marginT + plotH + 14);
    }

    if (distributionW) {
      const dx = marginL + plotW + 25, dw = distributionW - 35;
      ctx.fillStyle = '#cbd5e1'; ctx.font = '10px system-ui'; ctx.textAlign = 'center';
      ctx.fillText('f(E)', dx + dw/2, marginT - 10);
      ctx.fillText('0        1', dx + dw/2, marginT + plotH + 16);
      ctx.beginPath();
      for(let i=0;i<=200;i++) {
        const e = E_MIN + (E_MAX-E_MIN)*i/200;
        const x = dx + fermiDirac(e,Ef,p.temperature)*dw;
        if(i===0) ctx.moveTo(x,toY(e)); else ctx.lineTo(x,toY(e));
      }
      ctx.strokeStyle='#fbbf24';ctx.lineWidth=2;ctx.stroke();
    }
    const rowY = displayH - 65, sites = displayW < 450 ? 7 : 10;
    const spacing = (displayW - 90)/(sites-1), left = 45;
    const step = Math.floor(timeRef.current) % (sites-1);
    const progress = timeRef.current % 1;
    const hole = sites - 1 - step, source = hole - 1;
    ctx.font='10px system-ui';ctx.textAlign='center';ctx.fillStyle='#cbd5e1';
    ctx.fillText(isConductor ? 'Metal: partly filled band; nearby empty states' : 'Electron fills a vacancy → the vacancy shifts left', displayW/2,rowY-24,displayW-16);
    if(!isConductor) {
      for(let i=0;i<sites;i++) {
        const x=left+i*spacing;
        ctx.beginPath();ctx.arc(x,rowY,8,0,Math.PI*2);ctx.strokeStyle='#64748b';ctx.lineWidth=1;ctx.stroke();
        if(i!==hole && i!==source && p.showElectrons) {ctx.beginPath();ctx.arc(x,rowY,4,0,Math.PI*2);ctx.fillStyle='#60a5fa';ctx.fill();}
      }
      if(p.showElectrons) {const x=left+(source+progress)*spacing;ctx.beginPath();ctx.arc(x,rowY,4,0,Math.PI*2);ctx.fillStyle='#60a5fa';ctx.fill();}
      if(p.showHoles) {ctx.beginPath();ctx.arc(left+hole*spacing,rowY,10,0,Math.PI*2);ctx.strokeStyle='#fb7185';ctx.lineWidth=2;ctx.stroke();}
    }
    ctx.fillStyle='#94a3b8';ctx.font='9px system-ui';
    ctx.fillText('Schematic states; counts amplified. Hop illustration, not net drift.',displayW/2,displayH-14,displayW-16);

    // Status
    ctx.font = 'bold 11px system-ui'; ctx.textAlign = 'center';
    if (!s.isRunning) { ctx.fillStyle = '#94a3b8'; ctx.fillText('Press Run to animate electrons', displayW / 2, 28); }
    else if (s.isPaused) { ctx.fillStyle = '#f59e0b'; ctx.fillText('⏸ Paused', displayW / 2, 28); }
    else { ctx.fillStyle = '#10b981'; ctx.fillText('● Evolving', displayW / 2, 28); }

    // Stats tick
    if (s.onTick && timestamp !== undefined) {
      const now = performance.now();
      if (now - lastTickRef.current > 80) {
        lastTickRef.current = now;
        const concentrations = carrierConcentrations(Eg, p.temperature, p.dopingType, conc);
        const ni = isConductor ? 1e22 : concentrations.ni;
        s.onTick({
          bandGap: Eg,
          temperature: p.temperature,
          kT: kT,
          fermiLevel: Ef,
          intrinsicConc: ni,
          electronConc: isConductor ? 1e22 : concentrations.n,
          holeConc: isConductor ? 0 : concentrations.p,
          conductivity: mat.type === 'conductor' ? 'Very high' : mat.type === 'insulator' ? 'Negligible' : 'Moderate',
        });
      }
    }

    rafRef.current = requestAnimationFrame(draw);
  }, [width, height, initCarriers]);

  useEffect(() => {
    rafRef.current = requestAnimationFrame(draw);
    return () => cancelAnimationFrame(rafRef.current);
  }, [draw]);

  function drawGrid(ctx: CanvasRenderingContext2D, w: number, h: number) {
    ctx.strokeStyle = 'rgba(148, 163, 184, 0.06)';
    ctx.lineWidth = 1;
    for (let i = 0; i < w; i += 40) {
      ctx.beginPath(); ctx.moveTo(i, 0); ctx.lineTo(i, h); ctx.stroke();
    }
    for (let j = 0; j < h; j += 40) {
      ctx.beginPath(); ctx.moveTo(0, j); ctx.lineTo(w, j); ctx.stroke();
    }
  }

  return <canvas ref={canvasRef} width={width} height={height} className="w-full rounded-xl border border-gray-700 bg-slate-900" style={{ display: 'block' }} />;
}