'use client';
import { useRef, useEffect, useCallback, useState, useId } from 'react';
import {
  AtomicParams, AtomicModel,
  generateThomsonElectrons, updateThomsonElectrons,
  createAlphaParticle, updateAlphaParticle,
  bohrEnergy, bohrRadius, bohrVelocity, transitionWavelength,
  wavelengthToRGB, generateOrbitalSlice, radialDistribution,
  type ThomsonElectron, type ScatteringParticle,
} from '@/lib/physics/atomicModels';
import './atomic-models.css';

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
  const wallFrameRef=useRef<number|null>(null);
  const wallDeltaRef=useRef(0);
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

  const [targetN, setTargetN] = useState(3);
  const targetId = useId();
  const [currentN, setCurrentN] = useState(1);
  const [lastTransition, setLastTransition] = useState<{from:number;to:number}|null>(null);
  const manualTransitionRef = useRef(false);
  const previousModelRef = useRef(params.model);
  const previousZRef = useRef(params.protonCount);
  useEffect(() => {
    if(previousModelRef.current !== params.model || previousZRef.current !== params.protonCount){
      bohrNRef.current=1;transitionRef.current=null;photonsRef.current=[];
      setCurrentN(1);setLastTransition(null);manualTransitionRef.current=false;
      previousModelRef.current=params.model;previousZRef.current=params.protonCount;
    }
  },[params.model,params.protonCount]);
  const getFont = () => 'system-ui, sans-serif';

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

  const drawThomson = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w-48, h-70) * 0.32 * Math.min(1.2,p.zoom);
    const r = scale;
    const g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r);
    g.addColorStop(0, 'rgba(244,63,94,0.45)');
    g.addColorStop(0.5, 'rgba(244,63,94,0.18)');
    g.addColorStop(1, 'rgba(244,63,94,0.02)');
    ctx.fillStyle = g;
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2); 
    ctx.fill();
    ctx.strokeStyle = 'rgba(190,18,60,0.7)'; 
    ctx.lineWidth = 2;
    ctx.beginPath(); 
    ctx.arc(cx, cy, r, 0, Math.PI * 2); 
    ctx.stroke();
    if (p.showLabels) {
      ctx.fillStyle = '#be123c'; 
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
        ctx.fillStyle = '#2563eb'; 
        ctx.beginPath(); 
        ctx.arc(ex, ey, sz, 0, Math.PI * 2); 
        ctx.fill();
        if (p.showLabels && i < 4) { 
          ctx.fillStyle = '#334155'; 
          ctx.font = '12px ' + getFont(); 
          ctx.fillText('e⁻', ex + 12, ey - 6); 
        }
      });
    }
  }, []);

  const drawRutherford = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w-48, h-70) * 0.40 * Math.min(1.2,p.zoom);
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

      ctx.fillStyle = '#b45309';
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.fill();

      // Hard-sphere rim
      ctx.strokeStyle = 'rgba(255,255,255,0.45)';
      ctx.lineWidth = 1.5;
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.stroke();

      if (p.showLabels) {
        ctx.fillStyle = '#b45309'; 
        ctx.font = 'bold 13px ' + getFont(); 
        ctx.textAlign = 'center';
        ctx.fillText(`Nucleus  (${A}, ${Z})`, cx, cy + nr + 20);
        ctx.fillStyle = '#92400e'; 
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
        ctx.strokeStyle = 'rgba(190,18,60,0.7)'; 
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

  }, []);

  const drawBohr = useCallback((ctx:CanvasRenderingContext2D,cx:number,cy:number,w:number,h:number,dt:number,p:AtomicParams) => {
    const Z=p.protonCount||1;
    // Shell spacing is deliberately schematic: physical radii grow as n²/Z.
    const outer=Math.max(24,Math.min(w/2-42,h/2-40)) * Math.min(1,Math.max(.3,p.zoom));
    const radius=(n:number)=>outer*(.17+.83*(n-1)/6);
    const tr=transitionRef.current;
    if(p.showOrbits)for(let n=1;n<=7;n++){
      const r=radius(n),active=n===bohrNRef.current;
      ctx.strokeStyle=active?'#2563eb':'#94a3b8';ctx.lineWidth=active?2.6:1.2;
      ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.stroke();
      if(p.showLabels){
        // Alternate sides and angles instead of stacking seven labels on one ray.
        const angle=n%2===0?-.65:Math.PI+.65;
        const x=cx+Math.cos(angle)*r,y=cy+Math.sin(angle)*r;
        ctx.fillStyle='#ffffff';ctx.fillRect(x-14,y-9,28,18);
        ctx.fillStyle=active?'#1d4ed8':'#334155';ctx.font='600 12px '+getFont();ctx.textAlign='center';ctx.fillText('n='+n,x,y+4);
      }
    }
    if(p.showNucleus){ctx.fillStyle='#f59e0b';ctx.strokeStyle='#92400e';ctx.lineWidth=2;ctx.beginPath();ctx.arc(cx,cy,9,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.fillStyle='#78350f';ctx.font='bold 13px '+getFont();ctx.textAlign='center';ctx.fillText('+',cx,cy+4);}
    if(dt>0&&p.showElectrons){
      bohrPhaseRef.current+=dt*p.speed*1.6/Math.sqrt(bohrNRef.current);
      if(!tr&&!manualTransitionRef.current&&Math.random()<dt*p.speed*.25){
        const fromN=bohrNRef.current,toN=fromN===1?3:1;
        transitionRef.current={fromN,toN,progress:0};setLastTransition({from:fromN,to:toN});
      }
    }
    const transition=transitionRef.current;
    if(transition&&(dt>0||manualTransitionRef.current)){
      transition.progress+= (manualTransitionRef.current ? wallDeltaRef.current : dt)*Math.max(.25,p.speed)*.65;
      if(transition.progress>=1){bohrNRef.current=transition.toN;setCurrentN(transition.toN);transitionRef.current=null;manualTransitionRef.current=false;}
    }
    const from=transition?.fromN??bohrNRef.current,to=transition?.toN??from,progress=Math.min(1,transition?.progress??0);
    const angle=bohrPhaseRef.current,r=radius(from)+(radius(to)-radius(from))*progress;
    const ex=cx+Math.cos(angle)*r,ey=cy+Math.sin(angle)*r;
    if(transition){
      const outward=to>from,color=outward?'#b45309':'#7c3aed';
      const start=radius(from),end=radius(to),sx=cx+Math.cos(angle)*start,sy=cy+Math.sin(angle)*start,tx=cx+Math.cos(angle)*end,ty=cy+Math.sin(angle)*end;
      ctx.strokeStyle=color;ctx.lineWidth=3;ctx.setLineDash([5,4]);ctx.beginPath();ctx.moveTo(sx,sy);ctx.lineTo(tx,ty);ctx.stroke();ctx.setLineDash([]);
      const a=Math.atan2(ty-sy,tx-sx);ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(tx,ty);ctx.lineTo(tx-11*Math.cos(a-.5),ty-11*Math.sin(a-.5));ctx.lineTo(tx-11*Math.cos(a+.5),ty-11*Math.sin(a+.5));ctx.closePath();ctx.fill();
      // A photon moves toward the electron for absorption and away for emission.
      const distance=outward?outer+30-(outer+30-r)*progress:r+(outer+30-r)*progress;
      const px=cx+Math.cos(angle)*distance,py=cy+Math.sin(angle)*distance;
      ctx.strokeStyle=color;ctx.lineWidth=3;ctx.beginPath();
      for(let i=0;i<25;i++){const along=i-12,offset=Math.sin(i*.8)*4,x=px+Math.cos(angle)*along-Math.sin(angle)*offset,y=py+Math.sin(angle)*along+Math.cos(angle)*offset;if(i===0)ctx.moveTo(x,y);else ctx.lineTo(x,y);}ctx.stroke();
    }
    if(p.showElectrons){ctx.fillStyle='#2563eb';ctx.strokeStyle='#ffffff';ctx.lineWidth=2;ctx.beginPath();ctx.arc(ex,ey,7,0,Math.PI*2);ctx.fill();ctx.stroke();if(p.showSpin){ctx.fillStyle='#be123c';ctx.font='bold 18px '+getFont();ctx.textAlign='center';ctx.fillText('↑',ex,ey-13);}}
    const now=performance.now();if(now-lastTickRef.current>120){lastTickRef.current=now;const n=bohrNRef.current;propsRef.current.onTick?.({energy:bohrEnergy(n,Z),radius:bohrRadius(n,Z),velocity:bohrVelocity(n,Z)/2.998e8,n,wavelength:transition?transitionWavelength(from,to,Z):0,shellConfig:''});}
  }, []);

  const drawQuantum = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w-48, h-70) * 0.32 * Math.min(1.2,p.zoom);
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
      ctx.fillStyle = '#b45309'; 
      ctx.beginPath(); 
      ctx.arc(cx, cy, nr, 0, Math.PI * 2); 
      ctx.fill();
      if (p.showLabels) { 
        ctx.fillStyle = '#b45309'; 
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
          ctx.fillStyle = `hsla(${hue}, 85%, 38%, ${alpha})`; 
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
    if (onTick) { const now = performance.now(); 
      if (now - lastTickRef.current > 80) { 
        lastTickRef.current = now; onTick({ energy: bohrEnergy(n, Z), radius: bohrRadius(n, Z), velocity: 0, n, wavelength: 0, shellConfig: `${n}${['s','p','d','f'][l] || '?'}` });
      } }
  }, [onTick]);

  const drawLoop = useCallback((timestamp?: number) => {
    const canvas = canvasRef.current, wrap = wrapRef.current;
    if (!canvas || !wrap) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const s = propsRef.current, p = s.params;
    resize();
    const rect = wrap.getBoundingClientRect(), w = rect.width, h = rect.height;
    if(w<1||h<1){rafRef.current=requestAnimationFrame(drawLoop);return;}
    wallDeltaRef.current=timestamp===undefined?0:Math.max(0,Math.min(.05,(timestamp-(wallFrameRef.current??timestamp))/1000));wallFrameRef.current=timestamp??null;
    let dt = 0;
    if (s.isRunning && !s.isPaused && timestamp !== undefined) { if (lastFrameRef.current !== null) dt = Math.min((timestamp - lastFrameRef.current) / 1000, 0.05); 
      lastFrameRef.current = timestamp; } else { lastFrameRef.current = timestamp ?? null; }
    if (dt > 0) timeRef.current += dt * p.speed;
    const t = timeRef.current;
    ctx.clearRect(0, 0, w, h); 
    ctx.fillStyle = '#f8fafc'; 
    ctx.fillRect(0, 0, w, h);

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
  }, [resize, drawThomson, drawRutherford, drawBohr, drawQuantum]);

  useEffect(() => { resize(); 
    rafRef.current = requestAnimationFrame(drawLoop); 
    const observer=new ResizeObserver(resize);if(wrapRef.current)observer.observe(wrapRef.current);
    window.addEventListener('resize', resize); 
    return () => { observer.disconnect();cancelAnimationFrame(rafRef.current); 
      window.removeEventListener('resize', resize); 
    }; 
  }, [drawLoop, resize]);

  const Z=params.protonCount||1;
  const transition=lastTransition;
  const wavelength=transition?transitionWavelength(transition.from,transition.to,Z):0;
  const emission=transition?transition.to<transition.from:false;
  const notes:Record<AtomicModel,{title:string;description:string;legend:string}>= {
    thomson:{title:'Thomson · positive sphere',description:'Electrons are embedded in a diffuse positive charge. This historical model could not explain large-angle alpha scattering.',legend:'Rose: positive charge · Blue: electrons'},
    rutherford:{title:'Rutherford · nuclear scattering',description:'Most alpha particles pass through empty space; close approaches to the positively charged nucleus produce stronger deflections. Sizes are exaggerated.',legend:'Amber: nucleus · Rose trails: alpha particles'},
    bohr:{title:'Bohr · quantised states',description:'A one-electron, hydrogen-like model. The electron absorbs energy to reach a higher n and emits a photon when it falls to a lower n. Jumps and shell spacing are schematic.',legend:'Blue: electron / occupied orbit · Amber: absorption · Violet: emission'},
    quantum:{title:'Quantum · probability density',description:'Colour intensity represents the relative electron probability density in a 2D orbital slice. An orbital is not an electron path.',legend:'Darker colour: greater relative probability · Amber: nucleus'},
  };
  const note=notes[params.model];
  const n=params.nQuantum||1,l=params.lQuantum||0;
  const radial=Array.from({length:81},(_,i)=>{const r=i/80*10*n;return{r,d:radialDistribution(n,l,r)};});
  const maxD=Math.max(...radial.map(p=>p.d),1e-12);
  return <div className="af-atomic-view" data-model={params.model}>
    <div className="af-atomic-layout">
      <div className="af-atomic-scene" ref={wrapRef}>
        <canvas ref={canvasRef} role="img" aria-label={`${note.title}. ${note.legend}. ${params.model==='bohr'?`Occupied state n=${currentN}.`:''}`} />
      </div>
      {params.model==='bohr'&&<aside className="af-atomic-panel" aria-label="Bohr states and photon transitions">
        <h3>Electron transitions</h3>
        <p>Occupied state <strong>n = {currentN}</strong></p>
        <div className="af-atomic-transition-controls"><label htmlFor={targetId}>Destination state</label><select id={targetId} value={targetN} onChange={e=>setTargetN(Number(e.target.value))}>{Array.from({length:7},(_,i)=><option key={i+1} value={i+1}>n = {i+1}</option>)}</select>
        <button type="button" disabled={!params.showElectrons||targetN===currentN} onClick={()=>{const from=bohrNRef.current;transitionRef.current={fromN:from,toN:targetN,progress:0};manualTransitionRef.current=true;setLastTransition({from,to:targetN});}}>Show transition</button></div>
        <p className="af-atomic-caption">Run animates sample transitions. Show transition plays your selected jump, including while paused. Disable electron display to hide the electron.</p>
        <div className={`af-atomic-transition ${transition?(emission?'is-emission':'is-absorption'):''}`} aria-live="polite">
          {transition?<><strong>{emission?'↓ Emission':'↑ Absorption'} · n = {transition.from} → {transition.to}</strong><span>{emission?'Photon released':'Photon energy supplied'} · {Math.abs(bohrEnergy(transition.to,Z)-bohrEnergy(transition.from,Z)).toFixed(3)} eV</span><span>λ = {wavelength.toFixed(1)} nm · {wavelength<380?'ultraviolet':wavelength>780?'infrared':'visible light'}</span></>:<span>Choose a different state to inspect a photon transition.</span>}
        </div>
        {params.showEnergyLevels&&<><h4>Energy levels · eV</h4><ol className="af-atomic-levels">{[7,6,5,4,3,2,1].map(level=><li key={level} data-active={level===currentN}><span>n = {level}</span><span className="af-atomic-level-line"/><strong>{bohrEnergy(level,Z).toFixed(3)}</strong></li>)}</ol><p className="af-atomic-caption">Listed in energy order; row spacing is schematic. Ionisation limit: 0 eV.</p></>}
        {params.showFineStructure&&<p className="af-atomic-caption">Fine structure requires relativistic and spin–orbit corrections. The displayed energies are unsplit Bohr values.</p>}
        {params.showZeeman&&<p className="af-atomic-caption">B = {params.magneticField} T. Normal Zeeman spacing μB·B ≈ {(5.788e-5*params.magneticField).toExponential(2)} eV; splitting is not resolved on these Bohr levels.</p>}
        {params.showSpectrum&&<div className="af-atomic-spectrum"><h4>Hydrogen Balmer reference · Z = 1</h4><div>{[[410.2,'Violet'],[434.0,'Blue-violet'],[486.1,'Blue-green'],[656.3,'Red']].map(([wl,color])=><span key={wl} style={{borderTop:`5px solid ${wavelengthToRGB(Number(wl))}`}}><strong>{wl} nm</strong>{color}</span>)}</div><p className="af-atomic-caption">Reference emission lines, not a continuous spectrum. Selected-ion wavelengths are reported above.</p></div>}
      </aside>}
    </div>
    {params.showLabels&&<section className="af-atomic-notes" aria-label="Model explanation"><h3>{note.title}</h3><p>{note.description}</p><p className="af-atomic-legend">{note.legend}</p><p className="af-atomic-caption">Diagram sizes are schematic; zoom is limited to keep the model and labels in view.</p></section>}
    {params.model==='quantum'&&params.showProbability&&<section className="af-atomic-notes"><h3>Radial probability · n = {n}, l = {l}</h3><svg viewBox="0 0 420 130" role="img" aria-label="Relative radial probability distribution" className="af-atomic-radial"><path d="M35 15V105H400" fill="none" stroke="#64748b"/><path d={radial.map((p,i)=>`${i?'L':'M'}${35+p.r/(10*n)*365} ${105-p.d/maxD*80}`).join(' ')} fill="none" stroke="#4f46e5" strokeWidth="3"/><text x="38" y="125" fontSize="12">0</text><text x="285" y="125" fontSize="12">r / a₀ → {10*n}</text></svg></section>}
  </div>;
}
