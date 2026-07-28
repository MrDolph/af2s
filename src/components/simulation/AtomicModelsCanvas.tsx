'use client';
import { useRef, useEffect, useCallback } from 'react';
import {
  AtomicParams, AtomicModel,
  generateThomsonElectrons, updateThomsonElectrons,
  createAlphaParticle, updateAlphaParticle,
  bohrEnergy, bohrRadius, bohrVelocity, transitionWavelength,
  wavelengthToRGB, generateOrbitalSlice, radialDistribution,
  type ThomsonElectron, type ScatteringParticle,
} from '@/lib/physics/atomicModels';

interface Props {
  params: AtomicParams;
  isRunning: boolean;
  isPaused: boolean;
  onTick?: (stats: { 
    energy: number; 
    radius: number; 
    velocity: number; 
    n: number; 
    wavelength: number; 
    shellConfig: string 
  }) => void;
}

export function AtomicModelsCanvas({ params, isRunning, isPaused, onTick }: Props) {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const wrapRef = useRef<HTMLDivElement | null>(null);
  const rafRef = useRef<number>(0);
  const lastFrameRef = useRef<number | null>(null);
  const timeRef = useRef(0);
  const lastTickRef = useRef(0);
  const propsRef = useRef({ params, isRunning, isPaused, onTick });
  propsRef.current = { params, isRunning, isPaused, onTick };

  const thomsonRef = useRef<ThomsonElectron[]>([]);
  const scatterRef = useRef<ScatteringParticle[]>([]);
  const bohrPhaseRef = useRef(0);
  const bohrNRef = useRef(1);
  const transitionRef = useRef<{ fromN: number; toN: number; progress: number } | null>(null);
  const photonsRef = useRef<{ x: number; y: number; angle: number; wavelength: number; life: number }[]>([]);
  const orbitalGridRef = useRef<{ x: number; z: number; prob: number }[][] | null>(null);
  const orbitalCacheKeyRef = useRef('');
  const quantumPulseRef = useRef(0);

  const getFont = () => 'var(--kimi-font-sans, system-ui, sans-serif)';

  const resize = useCallback(() => {
    const canvas = canvasRef.current;
    const wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const dpr = window.devicePixelRatio || 1;
    const rect = wrap.getBoundingClientRect();
    const w = Math.floor(rect.width);
    const h = Math.floor(rect.height);
    if (canvas.width !== w * dpr || canvas.height !== h * dpr) {
      canvas.width = w * dpr;
      canvas.height = h * dpr;
    }
    canvas.style.width = w + 'px';
    canvas.style.height = h + 'px';
    const ctx = canvas.getContext('2d');
    if (ctx) ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
  }, []);

  const drawStarfield = useCallback((ctx: CanvasRenderingContext2D, w: number, h: number, t: number) => {
    for (let i = 0; i < 50; i++) {
      const sx = ((i * 137.5 + t * 1.5) % w + w) % w;
      const sy = ((i * 89.7 + Math.sin(t * 0.08 + i) * 8) % h + h) % h;
      const br = 0.3 + 0.4 * Math.sin(t * 0.4 + i * 2.3);
      const sz = 0.6 + (i % 3) * 0.6;
      ctx.fillStyle = `rgba(255,255,255,${br * 0.3})`;
      ctx.beginPath(); ctx.arc(sx, sy, sz, 0, Math.PI * 2); ctx.fill();
    }
  }, []);

  const drawInfoBox = useCallback((ctx: CanvasRenderingContext2D, w: number, h: number, lines: string[]) => {
    const isMobile = w < 520;
    const bw = isMobile ? Math.min(w - 24, 260) : Math.min(300, w * 0.42);
    const lineHeight = isMobile ? 13 : 17;
    const fontSize = isMobile ? 10 : 12;
    const pad = isMobile ? 8 : 10;
    const bh = lines.length * lineHeight + pad * 2 + 4;
    const bx = w - bw - 12;
    // Mobile: pin to top-right so it never overlaps the central nucleus / particles
    // Desktop: keep at bottom-right
    const by = isMobile ? 12 : h - bh - 12;

    ctx.fillStyle = isMobile ? 'rgba(15,23,42,0.82)' : 'rgba(15,23,42,0.65)';
    ctx.fillRect(bx, by, bw, bh);
    ctx.strokeStyle = 'rgba(148,163,184,0.25)';
    ctx.strokeRect(bx, by, bw, bh);
    ctx.fillStyle = '#94a3b8';
    ctx.font = `${fontSize}px ` + getFont();
    ctx.textAlign = 'left';
    lines.forEach((line, i) => ctx.fillText(line, bx + pad, by + pad + 4 + i * lineHeight));
  }, []);

  const drawThomson = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.38 * p.zoom;
    const r = scale;
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    g.addColorStop(0, 'rgba(244,63,94,0.45)');
    g.addColorStop(0.5, 'rgba(244,63,94,0.18)');
    g.addColorStop(1, 'rgba(244,63,94,0.02)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2); 
    ctx.fill();
    ctx.strokeStyle = 'rgba(244,63,94,0.35)'; 
    ctx.lineWidth = 2;
    ctx.beginPath(); 
    ctx.arc(cx, cy, r, 0, Math.PI * 2); 
    ctx.stroke();
    if (p.showLabels) {
      ctx.fillStyle = '#fb7185'; 
      ctx.font = 'bold 14px ' + getFont(); 
      ctx.textAlign = 'center';
      ctx.fillText('Positive charge sphere', cx, cy - r - 16);
    }
    if (p.showElectrons) {
      if (thomsonRef.current.length === 0) thomsonRef.current = generateThomsonElectrons(8);
      if (dt > 0) thomsonRef.current = updateThomsonElectrons(thomsonRef.current, dt, p.speed);
      thomsonRef.current.forEach((e, i) => {
        const ex = cx + Math.cos(e.angle) * e.radius * r;
        const ey = cy + Math.sin(e.angle) * e.radius * r * 0.65;
        const sz = 5 + Math.sin(e.phase) * 2;
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, sz * 4);
        glow.addColorStop(0, 'rgba(59,130,246,0.7)');
        glow.addColorStop(1, 'rgba(59,130,246,0)');
        ctx.fillStyle = glow; 
        ctx.beginPath(); 
        ctx.arc(ex, ey, sz * 4, 0, Math.PI * 2); 
        ctx.fill();
        ctx.fillStyle = '#93c5fd'; 
        ctx.beginPath(); 
        ctx.arc(ex, ey, sz, 0, Math.PI * 2); 
        ctx.fill();
        if (p.showLabels && i < 4) { 
          ctx.fillStyle = '#cbd5e1'; 
          ctx.font = '12px ' + getFont(); 
          ctx.fillText('e⁻', ex + 12, ey - 6); 
        }
      });
    }
    if (p.showLabels) drawInfoBox(ctx, w, h, ['J.J. Thomson (1897)', '• Atom = sphere of positive charge', '• Electrons embedded like raisins', '• Could NOT explain scattering data']);
  }, [drawInfoBox]);

  const drawRutherford = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.42 * p.zoom;
    const Z = p.protonCount || 79;
    const A = Z + (p.neutronCount || 0);

    if (p.showNucleus) {
      const nuclearFm = 1.2 * Math.pow(A, 1 / 3);
      const nr = Math.max(6, scale * 0.018 * Math.pow(A, 1 / 3));

      // Coulomb field halo
      const fieldR = nr * (3 + Math.log10(Math.max(Z, 1)));
      const fieldGrad = ctx.createRadialGradient(cx, cy, nr, cx, cy, fieldR);
      fieldGrad.addColorStop(0, `rgba(251,191,36,${0.08 + Z / 2000})`);
      fieldGrad.addColorStop(0.6, 'rgba(251,191,36,0.03)');
      fieldGrad.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = fieldGrad;
      ctx.beginPath(); 
      ctx.arc(cx, cy, fieldR, 0, Math.PI * 2); 
      ctx.fill();

      // Dense core
      const coreGlow = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 2.5);
      coreGlow.addColorStop(0, 'rgba(255,255,255,0.95)');
      coreGlow.addColorStop(0.25, 'rgba(251,191,36,0.85)');
      coreGlow.addColorStop(0.7, 'rgba(245,158,11,0.35)');
      coreGlow.addColorStop(1, 'rgba(245,158,11,0)');
      ctx.fillStyle = coreGlow;
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr * 2.5, 0, Math.PI * 2); 
      ctx.fill();

      ctx.fillStyle = '#fbbf24';
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.fill();

      // Hard-sphere rim
      ctx.strokeStyle = 'rgba(255,255,255,0.45)';
      ctx.lineWidth = 1.5;
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.stroke();

      if (p.showLabels && w >= 520) {
        ctx.fillStyle = '#fbbf24'; 
        ctx.font = 'bold 13px ' + getFont(); 
        ctx.textAlign = 'center';
        ctx.fillText(`Nucleus  (${A}, ${Z})`, cx, cy + nr + 20);
        ctx.fillStyle = 'rgba(251,191,36,0.7)'; 
        ctx.font = '11px ' + getFont();
        ctx.fillText(`r ≈ ${nuclearFm.toFixed(1)} fm`, cx, cy + nr + 36);
      }
    }

    // Alpha spawn / update
    if (dt > 0 && propsRef.current.isRunning && !propsRef.current.isPaused) {
      if (Math.random() < 0.04 * p.speed) {
        const b = (Math.random() - 0.5) * 400;
        scatterRef.current.push(createAlphaParticle(b, p.alphaEnergy || 5));
      }
      scatterRef.current = scatterRef.current
        .map(part => updateAlphaParticle(part, dt, p.protonCount))
        .filter(part => part.active);
    }

    let recoilIntensity = 0;

    scatterRef.current.forEach(part => {
      const px = cx + part.x * scale * 0.0018;
      const py = cy + part.y * scale * 0.0018;
      const dx = px - cx;
      const dy = py - cy;
      const dist = Math.sqrt(dx * dx + dy * dy);

      if (part.active && dist < scale * 0.08) {
        recoilIntensity = Math.max(recoilIntensity, 1 - dist / (scale * 0.08));
      }

      if (part.trail.length > 1) {
        ctx.strokeStyle = 'rgba(244,63,94,0.4)'; 
        ctx.lineWidth = 1.5; 
        ctx.beginPath();
        part.trail.forEach((pt, i) => {
          const tx = cx + pt.x * scale * 0.0018;
          const ty = cy + pt.y * scale * 0.0018;
          if (i === 0) ctx.moveTo(tx, ty); else ctx.lineTo(tx, ty);
        });
        ctx.stroke();
      }

      const glow = ctx.createRadialGradient(px, py, 0, px, py, 10);
      glow.addColorStop(0, 'rgba(244,63,94,0.6)'); 
      glow.addColorStop(1, 'rgba(244,63,94,0)');
      ctx.fillStyle = glow; 
      ctx.beginPath(); 
      ctx.arc(px, py, 10, 0, Math.PI * 2); 
      ctx.fill();
      ctx.fillStyle = '#f43f5e'; 
      ctx.beginPath(); 
      ctx.arc(px, py, 4, 0, Math.PI * 2); 
      ctx.fill();
    });

    // Recoil flash
    if (recoilIntensity > 0) {
      const flashNr = Math.max(6, scale * 0.018 * Math.pow(A, 1 / 3));
      const flashR = flashNr * 5;
      const flashGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, flashR);
      flashGrad.addColorStop(0, `rgba(255,255,255,${recoilIntensity * 0.35})`);
      flashGrad.addColorStop(0.4, `rgba(251,191,36,${recoilIntensity * 0.2})`);
      flashGrad.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = flashGrad;
      ctx.globalCompositeOperation = 'screen';
      ctx.beginPath(); ctx.arc(cx, cy, flashR, 0, Math.PI * 2); ctx.fill();
      ctx.globalCompositeOperation = 'source-over';
    }

    if (p.showLabels) drawInfoBox(ctx, w, h, ['Ernest Rutherford (1911)', '• Most α pass through → atom is EMPTY', '• Some bend → nucleus is charged', '• Rare rebound → nucleus is TINY & DENSE', '• Classical problem: orbiting e⁻ radiates']);
  }, [drawInfoBox]);

  const drawBohr = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.20 * p.zoom;
    const maxN = 7, Z = p.protonCount || 1;
    if (p.showNucleus) {
      const nr = 7, ng = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 3);
      ng.addColorStop(0, 'rgba(251,191,36,0.9)'); 
      ng.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = ng; 
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr * 3, 0, Math.PI * 2); 
      ctx.fill();
      ctx.fillStyle = '#fbbf24'; 
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.fill();
    }
    if (p.showEnergyLevels) {
      const eL = Math.min(55, w * 0.08), eT = 50, eH = h - 140, eMax = Math.abs(bohrEnergy(maxN, Z)) * 1.3;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; 
      ctx.fillRect(eL - 10, eT - 10, 100, eH + 20);
      ctx.strokeStyle = 'rgba(148,163,184,0.18)'; 
      ctx.strokeRect(eL - 10, eT - 10, 100, eH + 20);
      ctx.fillStyle = '#94a3b8'; 
      ctx.font = 'bold 12px ' + getFont(); 
      ctx.textAlign = 'center'; 
      ctx.fillText('Energy (eV)', eL + 40, eT - 2);
      for (let n = 1; n <= maxN; n++) {
        const y = eT + eH - (Math.abs(bohrEnergy(n, Z)) / eMax) * eH;
        ctx.strokeStyle = 'rgba(99,102,241,0.45)'; 
        ctx.lineWidth = 1.5; 
        ctx.beginPath(); 
        ctx.moveTo(eL, y); 
        ctx.lineTo(eL + 75, y); 
        ctx.stroke();
        ctx.fillStyle = '#818cf8'; 
        ctx.font = '11px ' + getFont(); 
        ctx.textAlign = 'right'; 
        ctx.fillText(`n=${n}`, eL - 5, y + 3);
        if (p.showFineStructure && n > 1) { 
          ctx.strokeStyle = 'rgba(244,63,94,0.35)'; 
          ctx.beginPath(); ctx.moveTo(eL, y - 3); 
          ctx.lineTo(eL + 75, y - 3); 
          ctx.stroke(); 
          ctx.strokeStyle = 'rgba(59,130,246,0.35)'; 
          ctx.beginPath(); 
          ctx.moveTo(eL, y + 3); 
          ctx.lineTo(eL + 75, y + 3); 
          ctx.stroke(); }
      }
      if (p.showZeeman && p.magneticField > 0) { 
        ctx.fillStyle = 'rgba(16,185,129,0.5)'; 
        ctx.font = '11px ' + getFont(); 
        ctx.textAlign = 'left'; 
        ctx.fillText(`B = ${p.magneticField} T`, eL + 4, eT + eH + 16); }
    }
    if (p.showOrbits) {
      for (let n = 1; n <= maxN; n++) {
        const r = bohrRadius(n, Z) * scale * 0.14;
        ctx.strokeStyle = `rgba(99,102,241,${0.15 + 0.1 * (maxN - n) / maxN})`; 
        ctx.lineWidth = 1.2; 
        ctx.beginPath(); 
        ctx.arc(cx, cy, r, 0, Math.PI * 2); 
        ctx.stroke();
        if (p.showLabels) { 
          ctx.fillStyle = 'rgba(129,140,248,0.5)'; 
          ctx.font = '11px ' + getFont(); 
          ctx.textAlign = 'center'; 
          ctx.fillText(`n=${n}`, cx + r + 16, cy); }
      }
    }
    if (p.showElectrons) {
      if (dt > 0 && propsRef.current.isRunning && !propsRef.current.isPaused) {
        bohrPhaseRef.current += dt * p.speed * (2.2 / bohrNRef.current);
        if (!transitionRef.current && Math.random() < 0.01 * p.speed) {
          const fromN = bohrNRef.current, delta = Math.random() < 0.5 ? -1 : 1;
          const toN = Math.max(1, Math.min(maxN, fromN + delta * Math.floor(Math.random() * 2 + 1)));
          if (fromN !== toN) transitionRef.current = { fromN, toN, progress: 0 };
        }
        if (transitionRef.current) {
          transitionRef.current.progress += dt * p.speed * 2.2;
          if (transitionRef.current.progress >= 1) {
            bohrNRef.current = transitionRef.current.toN;
            photonsRef.current.push({ x: cx, y: cy, angle: Math.random() * Math.PI * 2, wavelength: transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z), life: 1 });
            transitionRef.current = null;
          }
        }
      }
      const curN = transitionRef.current ? transitionRef.current.fromN : bohrNRef.current;
      const tgtN = transitionRef.current ? transitionRef.current.toN : curN;
      const prog = transitionRef.current ? transitionRef.current.progress : 0;
      const rFrom = bohrRadius(curN, Z) * scale * 0.14, rTo = bohrRadius(tgtN, Z) * scale * 0.14;
      const curR = rFrom + (rTo - rFrom) * prog;
      const ex = cx + Math.cos(bohrPhaseRef.current) * curR, ey = cy + Math.sin(bohrPhaseRef.current) * curR;
      if (transitionRef.current) {
        const col = wavelengthToRGB(transitionWavelength(curN, tgtN, Z));
        const glow = ctx.createRadialGradient(ex, ey, 0, ex, ey, 28);
        glow.addColorStop(0, col.replace('rgb', 'rgba').replace(')', ', 0.5)'));
        glow.addColorStop(1, col.replace('rgb', 'rgba').replace(')', ', 0)'));
        ctx.fillStyle = glow; ctx.beginPath(); ctx.arc(ex, ey, 28, 0, Math.PI * 2); ctx.fill();
      }
      const eg = ctx.createRadialGradient(ex, ey, 0, ex, ey, 14);
      eg.addColorStop(0, 'rgba(59,130,246,0.9)'); 
      eg.addColorStop(1, 'rgba(59,130,246,0)');
      ctx.fillStyle = eg; 
      ctx.beginPath(); 
      ctx.arc(ex, ey, 14, 0, Math.PI * 2); 
      ctx.fill();
      ctx.fillStyle = '#93c5fd'; 
      ctx.beginPath(); 
      ctx.arc(ex, ey, 6, 0, Math.PI * 2); 
      ctx.fill();
      if (p.showSpin) { 
        ctx.strokeStyle = '#f43f5e'; 
        ctx.lineWidth = 2; 
        ctx.beginPath(); 
        ctx.moveTo(ex - 5, ey - 12); 
        ctx.lineTo(ex + 5, ey - 12); 
        ctx.stroke(); 
        ctx.beginPath(); 
        ctx.moveTo(ex, ey - 12); 
        ctx.lineTo(ex, ey - 18); 
        ctx.stroke(); 
        ctx.beginPath(); 
        ctx.moveTo(ex - 4, ey - 16); 
        ctx.lineTo(ex, ey - 18); 
        ctx.lineTo(ex + 4, ey - 16); 
        ctx.stroke(); }
      if (p.showLabels) { 
        ctx.fillStyle = '#cbd5e1'; 
        ctx.font = '12px ' + getFont(); 
        ctx.textAlign = 'center'; 
        ctx.fillText(`e⁻ n=${Math.round(curN + (tgtN - curN) * prog)}`, ex, ey - 18); }
    }
    if (dt > 0 && propsRef.current.isRunning && !propsRef.current.isPaused) { 
      for (let i = photonsRef.current.length - 1; i >= 0; i--) { 
        const p = photonsRef.current[i]; 
      p.x += Math.cos(p.angle) * 220 * dt * params.speed; 
      p.y += Math.sin(p.angle) * 220 * dt * params.speed; 
      p.life -= dt * params.speed * 0.55; 
      if (p.life <= 0) photonsRef.current.splice(i, 1); } }
    photonsRef.current.forEach(p => { const col = wavelengthToRGB(p.wavelength); 
      ctx.globalAlpha = Math.max(0, p.life); 
      ctx.strokeStyle = col; 
      ctx.lineWidth = 3; 
      ctx.beginPath(); 
      ctx.moveTo(p.x - Math.cos(p.angle) * 12, p.y - Math.sin(p.angle) * 12); 
      ctx.lineTo(p.x + Math.cos(p.angle) * 12, p.y + Math.sin(p.angle) * 12); 
      ctx.stroke(); 
      ctx.globalAlpha = 1; });
    if (p.showSpectrum) {
      const bY = h - 28, bW = w - 140, bX = 120;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; 
      ctx.fillRect(bX - 5, bY - 14, bW + 10, 26);
      ctx.strokeStyle = 'rgba(148,163,184,0.2)'; 
      ctx.strokeRect(bX - 5, bY - 14, bW + 10, 26);
      ctx.fillStyle = '#94a3b8'; 
      ctx.font = '11px ' + getFont(); 
      ctx.textAlign = 'left'; 
      ctx.fillText('Spectrum (nm)', bX, bY - 18);
      for (let wl = 380; wl <= 780; wl += 40) { const xx = bX + ((wl - 380) / 400) * bW; 
        ctx.fillStyle = wavelengthToRGB(wl); 
        ctx.fillRect(xx, bY - 10, 4, 18); }
      photonsRef.current.forEach(p => { if (p.wavelength >= 380 && p.wavelength <= 780) { const xx = bX + ((p.wavelength - 380) / 400) * bW; 
        ctx.fillStyle = wavelengthToRGB(p.wavelength); 
        ctx.globalAlpha = Math.max(0, p.life); 
        ctx.fillRect(xx - 2, bY - 14, 5, 24); 
        ctx.globalAlpha = 1; } });
    }
    if (p.showLabels) drawInfoBox(ctx, w, h, ['Niels Bohr (1913)', '• Stationary states: no radiation', '• L = nℏ (quantized angular momentum)', '• Eₙ = -13.6 Z²/n² eV', '• ΔE = hν (photon emission/absorption)']);
    if (onTick) { const now = performance.now(); 
      if (now - lastTickRef.current > 80) { 
        lastTickRef.current = now; 
        const n = bohrNRef.current; 
        onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: bohrVelocity(n, Z) / 2.998e8, n, wavelength: transitionRef.current ? transitionWavelength(transitionRef.current.fromN, transitionRef.current.toN, Z) : 0, shellConfig: '' }); } }
  }, [drawInfoBox, onTick, params.speed]);

  const drawQuantum = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w, h) * 0.38 * p.zoom;
    const n = p.nQuantum || 1, l = p.lQuantum || 0, m = p.mQuantum || 0, Z = p.protonCount || 1;
    quantumPulseRef.current += dt * p.speed * 1.5;
    if (p.showNucleus) {
      const nr = 6, ng = ctx.createRadialGradient(cx, cy, 0, cx, cy, nr * 3);
      ng.addColorStop(0, 'rgba(251,191,36,1)'); 
      ng.addColorStop(1, 'rgba(251,191,36,0)');
      ctx.fillStyle = ng; 
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr * 3, 0, Math.PI * 2); 
      ctx.fill();
      ctx.fillStyle = '#fbbf24'; 
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.fill();
      if (p.showLabels) { 
        ctx.fillStyle = '#fbbf24'; 
        ctx.font = 'bold 12px ' + getFont();
        ctx.textAlign = 'center'; 
        ctx.fillText(`Z=${Z}`, cx, cy + nr + 18); 
      }
    }
    if (p.showProbability) {
      const cacheKey = `${n},${l},${m},${scale}`;
      if (orbitalCacheKeyRef.current !== cacheKey) { 
        orbitalGridRef.current = generateOrbitalSlice(n, l, m, 60); 
        orbitalCacheKeyRef.current = cacheKey; 
      }
      const grid = orbitalGridRef.current;
      if (grid) {
        let maxP = 0; 
        grid.forEach(row => row.forEach(pt => { if (pt.prob > maxP) maxP = pt.prob; }));
        const cellW = (scale * 2.6) / grid[0].length, cellH = (scale * 2.6) / grid.length;
        const pulse = 0.7 + 0.3 * Math.sin(quantumPulseRef.current);
        grid.forEach((row, ri) => { row.forEach((pt, ci) => { const prob = pt.prob / (maxP || 1); 
          if (prob < 0.02) return; 
          const px = cx + (pt.x / (10 * n)) * scale * 1.3, py = cy - (pt.z / (10 * n)) * scale * 1.3; 
          const alpha = Math.min(0.65, prob * 2.5 * pulse); 
          const hue = 200 + prob * 100 + Math.sin(quantumPulseRef.current + ci * 0.1) * 15; 
          ctx.fillStyle = `hsla(${hue}, 90%, 60%, ${alpha})`; 
          ctx.fillRect(px - cellW / 2, py - cellH / 2, cellW + 1, cellH + 1); }); 
        });
        const scanY = cy - scale * 1.3 + ((Math.sin(quantumPulseRef.current * 0.5) * 0.5 + 0.5) * scale * 2.6);
        ctx.strokeStyle = 'rgba(255,255,255,0.12)'; 
        ctx.lineWidth = 1; 
        ctx.beginPath(); 
        ctx.moveTo(cx - scale * 1.3, scanY); 
        ctx.lineTo(cx + scale * 1.3, scanY); 
        ctx.stroke();
      }
    }
    if (p.showProbability) {
      const px = w - 130, py = 45, pw = 110, ph = 110;
      ctx.fillStyle = 'rgba(15,23,42,0.55)'; 
      ctx.fillRect(px - 6, py - 18, pw + 12, ph + 28);
      ctx.strokeStyle = 'rgba(148,163,184,0.15)'; 
      ctx.strokeRect(px - 6, py - 18, pw + 12, ph + 28);
      ctx.fillStyle = '#94a3b8'; 
      ctx.font = '11px ' + getFont(); 
      ctx.textAlign = 'center'; 
      ctx.fillText('Radial dist.', px + pw / 2, py - 6);
      const rMax = 10 * n; let maxD = 0; const samples: { r: number; d: number }[] = [];
      for (let i = 0; i <= 40; i++) { const r = (i / 40) * rMax, d = radialDistribution(n, l, r); samples.push({ r, d }); if (d > maxD) maxD = d; }
      ctx.strokeStyle = 'rgba(99,102,241,0.85)'; 
      ctx.lineWidth = 2; 
      ctx.beginPath();
      samples.forEach((s, i) => { const xx = px + (s.r / rMax) * pw, yy = py + ph - (s.d / (maxD || 1)) * ph; 
        if (i === 0) ctx.moveTo(xx, yy); 
        else ctx.lineTo(xx, yy); 
      });
      ctx.stroke();
      const a0x = px + (n * n * 0.529 / rMax) * pw;
      ctx.strokeStyle = 'rgba(244,63,94,0.5)'; 
      ctx.setLineDash([3, 3]); 
      ctx.beginPath(); 
      ctx.moveTo(a0x, py); 
      ctx.lineTo(a0x, py + ph); 
      ctx.stroke(); 
      ctx.setLineDash([]);
    }
    if (p.showLabels) { const labels = ['s', 'p', 'd', 'f']; 
      drawInfoBox(ctx, w, h, ['Schrödinger (1926)', '• Ψ = probability amplitude', '• |Ψ|² = probability density', '• No orbit — only probability cloud', `• n=${n} l=${l} (${labels[l]}) m=${m}`]); }
    if (onTick) { const now = performance.now(); 
      if (now - lastTickRef.current > 80) { 
        lastTickRef.current = now; onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: 0, n, wavelength: 0, shellConfig: `${n}${['s','p','d','f'][l] || '?'}` });
      } }
  }, [drawInfoBox, onTick]);

  const drawLoop = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current, p = s.params;
    resize();
    const rect = wrap.getBoundingClientRect(), w = rect.width, h = rect.height;
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) { if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05); 
      lastFrameRef.current = timestamp; } else { lastFrameRef.current = timestamp ?? null; }
    if (dt > 0) timeRef.current += dt * p.speed;
    const t = timeRef.current;
    ctx.clearRect(0, 0, w, h); 
    ctx.fillStyle = '#0b1021'; 
    ctx.fillRect(0, 0, w, h);
    drawStarfield(ctx, w, h, t);
    const cx = w / 2, cy = h / 2;
    switch (p.model) { case 'thomson': drawThomson(ctx, cx, cy, w, h, dt, p); 
      break; 
      case 'rutherford': drawRutherford(ctx, cx, cy, w, h, dt, p); 
      break; 
      case 'bohr': drawBohr(ctx, cx, cy, w, h, dt, p); 
      break; 
      case 'quantum': drawQuantum(ctx, cx, cy, w, h, dt, p); 
      break; 
      }
    rafRef.current = requestAnimationFrame(drawLoop);
  }, [resize, drawStarfield, drawThomson, drawRutherford, drawBohr, drawQuantum]);

  useEffect(() => { resize(); 
    rafRef.current = requestAnimationFrame(drawLoop); 
    window.addEventListener('resize', resize); 
    return () => { cancelAnimationFrame(rafRef.current); 
      window.removeEventListener('resize', resize); 
    }; 
  }, [drawLoop, resize]);

  return (
    <div ref={wrapRef} style={{ width: '100%', position: 'relative', borderRadius: 12, overflow: 'hidden', border: '1px solid var(--kimi-color-border-secondary, #e5e7eb)', background: '#0b1021', aspectRatio: '16 / 10', minHeight: 260 }}>
      <canvas ref={canvasRef} style={{ display: 'block', width: '100%', height: '100%' }} />
    </div>
  );
}