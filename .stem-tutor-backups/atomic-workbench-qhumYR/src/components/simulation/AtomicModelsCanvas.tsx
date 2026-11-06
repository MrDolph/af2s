'use client';
import { useRef, useEffect, useCallback, useState } from 'react';
import {
  AtomicParams, AtomicModel,
  generateThomsonElectrons, updateThomsonElectrons,
  createAlphaParticle, updateAlphaParticle,
  bohrEnergy, bohrRadius, bohrVelocity, transitionWavelength,
  wavelengthToRGB, generateOrbitalSlice, radialDistribution,
  type ThomsonElectron, type ScatteringParticle,
} from '@/lib/physics/atomicModels';
import './atomic-models.css';
import {viewZoom} from '@/lib/physics/bohrWorkbench';
import {BohrRadiationLab} from './BohrRadiationLab';

interface Props {
  params: AtomicParams;
  isRunning: boolean;
  isPaused: boolean;
  onModelChange?: (model:AtomicModel)=>void;
  onSpeedChange?: (speed:number)=>void;
  onZoomChange?: (zoom:number)=>void;
  onParamsChange?: (patch:Partial<AtomicParams>)=>void;
  controls?: {run:()=>void;pause:()=>void;reset:()=>void};
  interactive?: boolean;
  onTick?: (stats: { 
    energy: number; 
    radius: number; 
    velocity: number; 
    n: number; 
    wavelength: number; 
    shellConfig: string 
  }) => void;
}

export function AtomicModelsCanvas({ params, isRunning, isPaused, onTick, onModelChange, onSpeedChange, onZoomChange, onParamsChange, controls, interactive=true }: Props) {
  const [viewReset,setViewReset]=useState(0);
  const canvasPan=useRef({x:0,y:0});
  const canvasDrag=useRef<{x:number;y:number;pan:{x:number;y:number}}|null>(null);
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
  const orbitalGridRef = useRef<{ x: number; z: number; prob: number }[][] | null>(null);
  const orbitalCacheKeyRef = useRef('');
  const quantumPulseRef = useRef(0);

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

  const drawThomson=useCallback((ctx:CanvasRenderingContext2D,cx:number,cy:number,w:number,h:number,dt:number,p:AtomicParams)=>{
    const r=Math.max(15,Math.min(w-44,h-40)*.43);
    const pudding=ctx.createRadialGradient(cx-r*.3,cy-r*.35,r*.05,cx,cy,r);
    pudding.addColorStop(0,'#fff1d6');pudding.addColorStop(.55,'#fda4af');pudding.addColorStop(1,'#e11d48');
    ctx.fillStyle=pudding;ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.fill();
    ctx.strokeStyle='#9f1239';ctx.lineWidth=2.5;ctx.stroke();
    // Plus signs are symbols for a continuous positive medium, not protons.
    ctx.save();ctx.beginPath();ctx.arc(cx,cy,r-3,0,Math.PI*2);ctx.clip();
    ctx.strokeStyle='#9f1239';ctx.lineWidth=1.6;
    const spacing=Math.max(18,r/3.5);
    for(let x=-r;x<=r;x+=spacing)for(let y=-r;y<=r;y+=spacing){if(x*x+y*y>r*r*.92)continue;const px=cx+x,py=cy+y;ctx.beginPath();ctx.moveTo(px-4,py);ctx.lineTo(px+4,py);ctx.moveTo(px,py-4);ctx.lineTo(px,py+4);ctx.stroke();}
    if(p.showElectrons){
      const plums=[[-.58,-.32],[-.1,-.64],[.42,-.4],[.66,.08],[.22,.45],[-.3,.56],[-.66,.15],[0,0]];
      plums.forEach(([x,y],i)=>{const oscillation=Math.sin(timeRef.current*1.2+i)*.012*r,ex=cx+x*r+oscillation,ey=cy+y*r;
        const radius=Math.max(6,Math.min(13,r*.075));ctx.fillStyle='#1e40af';ctx.strokeStyle='#eff6ff';ctx.lineWidth=2;ctx.beginPath();ctx.arc(ex,ey,radius,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.strokeStyle='#fff';ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(ex-radius*.4,ey);ctx.lineTo(ex+radius*.4,ey);ctx.stroke();});
    }
    ctx.restore();
  },[]);

  const drawRutherford = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w-48, h-70) * 0.40;
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

  const drawQuantum = useCallback((ctx: CanvasRenderingContext2D, cx: number, cy: number, w: number, h: number, dt: number, p: AtomicParams) => {
    const scale = Math.min(w-48, h-70) * 0.32;
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
    const magnification=viewZoom(p.zoom),drawingParams={...p,zoom:1};
    ctx.save();ctx.translate(cx+canvasPan.current.x,cy+canvasPan.current.y);ctx.scale(magnification,magnification);ctx.translate(-cx,-cy);
    switch (p.model) { case 'thomson': drawThomson(ctx, cx, cy, w, h, dt, drawingParams); 
      break; 
      case 'rutherford': drawRutherford(ctx, cx, cy, w, h, dt, drawingParams); 
      break; 
      case 'bohr': break;
      case 'quantum': drawQuantum(ctx, cx, cy, w, h, dt, drawingParams); 
      break; 
      }
    ctx.restore();
    rafRef.current = requestAnimationFrame(drawLoop);
  }, [resize, drawThomson, drawRutherford, drawQuantum]);

  useEffect(() => { resize(); 
    rafRef.current = requestAnimationFrame(drawLoop); 
    const observer=new ResizeObserver(resize);if(wrapRef.current)observer.observe(wrapRef.current);
    window.addEventListener('resize', resize); 
    return () => { observer.disconnect();cancelAnimationFrame(rafRef.current); 
      window.removeEventListener('resize', resize); 
    }; 
  }, [drawLoop, resize, params.model]);

  const notes:Record<AtomicModel,{title:string;description:string;legend:string}>= {
    thomson:{title:'Thomson · plum-pudding atom',description:'The pink pudding is a continuous sphere of positive charge. Blue negative electrons are the embedded plums. The + symbols mark the positive medium, not separate protons; this model has no nucleus.',legend:'Pink pudding: distributed positive charge · Blue plums: negative electrons'},
    rutherford:{title:'Rutherford · nuclear scattering',description:'Most alpha particles pass through empty space; close approaches to the positively charged nucleus produce stronger deflections. Sizes are exaggerated.',legend:'Amber: nucleus · Rose trails: alpha particles'},
    bohr:{title:'Bohr · quantised states',description:'A one-electron, hydrogen-like model. The electron absorbs energy to reach a higher n and emits a photon when it falls to a lower n. Jumps and shell spacing are schematic.',legend:'Blue: electron / occupied orbit · Amber: absorption · Violet: emission'},
    quantum:{title:'Quantum · probability density',description:'Colour intensity represents the relative electron probability density in a 2D orbital slice. An orbital is not an electron path.',legend:'Darker colour: greater relative probability · Amber: nucleus'},
  };
  const note=notes[params.model];
  const n=params.nQuantum||1,l=params.lQuantum||0;
  const radial=Array.from({length:81},(_,i)=>{const r=i/80*10*n;return{r,d:radialDistribution(n,l,r)};});
  const maxD=Math.max(...radial.map(p=>p.d),1e-12);
  return <div className="af-atomic-view" data-model={params.model}>
    <header className="af-atomic-toolbar"><strong>Atomic laboratory</strong>
      {onModelChange&&interactive?<label>Model<select aria-label="Atomic model" value={params.model} onChange={e=>onModelChange(e.target.value as AtomicModel)}><option value="thomson">Thomson · plum pudding</option><option value="rutherford">Rutherford · scattering</option><option value="bohr">Bohr · radiation & states</option><option value="quantum">Quantum · probability</option></select></label>:<span>{note.title}</span>}
      {onSpeedChange&&interactive&&<label>Speed<select aria-label="Lesson speed" value={params.speed} onChange={e=>onSpeedChange(Number(e.target.value))}>{Array.from(new Set([0,.5,1,1.5,2,3,params.speed])).sort((a,b)=>a-b).map(v=><option key={v} value={v}>{v}×</option>)}</select></label>}
      {interactive&&onParamsChange&&(params.model==='bohr'||params.model==='quantum')&&<label>Z<input aria-label="Nuclear charge Z" type="number" min="1" max="92" value={params.protonCount} onChange={e=>{const v=Number(e.target.value);if(Number.isInteger(v)&&v>=1&&v<=92)onParamsChange({protonCount:v});}}/></label>}
      {interactive&&onParamsChange&&params.model==='quantum'&&<div className="af-quantum-controls" aria-label="Quantum parameters">{(['n','l','m'] as const).map(key=>{const value=key==='n'?n:key==='l'?l:params.mQuantum||0;const values=key==='n'?[1,2,3,4]:key==='l'?Array.from({length:n},(_,i)=>i):Array.from({length:2*l+1},(_,i)=>i-l);return <label key={key}>{key}<select aria-label={`Quantum ${key}`} value={value} onChange={e=>{const v=Number(e.target.value);if(key==='n')onParamsChange({nQuantum:v,lQuantum:Math.min(l,v-1),mQuantum:Math.max(-Math.min(l,v-1),Math.min(params.mQuantum||0,Math.min(l,v-1)))});else if(key==='l')onParamsChange({lQuantum:v,mQuantum:Math.max(-v,Math.min(params.mQuantum||0,v))});else onParamsChange({mQuantum:v});}}>{values.map(v=><option key={v} value={v}>{v}</option>)}</select></label>;})}<span>{n}{['s','p','d','f'][l]} · {n-l-1} radial / {l} angular nodes · E={bohrEnergy(n,params.protonCount).toFixed(3)} eV</span></div>}
      {interactive&&onZoomChange&&<label className="af-atomic-zoom">Zoom<input aria-label="View zoom" type="range" min="0.3" max="3" step="0.1" value={params.zoom} onChange={e=>onZoomChange(Number(e.target.value))}/><output>{viewZoom(params.zoom).toFixed(1)}×</output><button type="button" onClick={()=>{onZoomChange(1);canvasPan.current={x:0,y:0};setViewReset(v=>v+1);}}>Fit</button></label>}
      {interactive&&onParamsChange&&params.model==='bohr'&&<><label title="Chosen screening constant; Zeff=Z−σ. Hydrogenic approximation.">σ<input aria-label="Screening constant" type="number" min="0" max={Math.max(0,params.protonCount-1)} step="0.1" disabled={params.protonCount<=1} value={params.screening??0} onChange={e=>{const v=Number(e.target.value);if(Number.isFinite(v)&&v>=0&&v<=params.protonCount-1)onParamsChange({screening:v});}}/></label>{params.showZeeman&&<label>B (T)<input aria-label="Magnetic field B" type="range" min="0" max="5" step="0.1" value={params.magneticField} onChange={e=>onParamsChange({magneticField:Number(e.target.value)})}/><output>{params.magneticField.toFixed(1)}</output></label>}</>}
      {interactive&&onParamsChange&&<details className="af-atomic-display"><summary>Physics options</summary><div>{([['showOrbits','Orbits'],['showElectrons','Electrons'],['showNucleus','Nucleus'],['showEnergyLevels','Energy levels'],['showLabels','Labels'],...(params.model==='bohr'?[['showSpectrum','Spectrum'],['showSpin','Electron spin'],['showFineStructure','Fine structure'],['showZeeman','Zeeman effect']]:[]),...(params.model==='quantum'?[['showProbability','Probability cloud']]:[])] as [keyof AtomicParams,string][]).map(([key,label])=><label key={key}><input type="checkbox" checked={!!params[key]} onChange={e=>onParamsChange({[key]:e.target.checked})}/>{label}</label>)}</div></details>}
      {params.model!=='bohr'&&controls&&interactive&&<div className="af-atomic-playback"><button type="button" onClick={isRunning?controls.pause:controls.run}>{!isRunning?'Run':isPaused?'Resume':'Pause'}</button><button type="button" onClick={controls.reset}>Reset</button></div>}
    </header>
    {params.model==='bohr'?<BohrRadiationLab params={params} onTick={onTick} interactive={interactive} viewReset={viewReset} isRunning={isRunning} isPaused={isPaused} controls={controls}/>:<>
    <div className="af-atomic-layout">
      <div className="af-atomic-scene" ref={wrapRef}>
        <canvas ref={canvasRef} onPointerDown={e=>{canvasDrag.current={x:e.clientX,y:e.clientY,pan:{...canvasPan.current}};e.currentTarget.setPointerCapture(e.pointerId);}} onPointerMove={e=>{const d=canvasDrag.current;if(d)canvasPan.current={x:d.pan.x+e.clientX-d.x,y:d.pan.y+e.clientY-d.y};}} onPointerUp={()=>{canvasDrag.current=null;}} onPointerCancel={()=>{canvasDrag.current=null;}} role="img" aria-label={`${note.title}. ${note.legend}.`} />
      </div>
    </div>
    {params.showLabels&&<section className="af-atomic-notes" aria-label="Model explanation"><h3>{note.title}</h3><p>{note.description}</p><p className="af-atomic-legend">{note.legend}</p><p className="af-atomic-caption">Diagram sizes are schematic. Zoom magnifies the view; drag to pan and use Fit to restore framing.</p></section>}
    {params.model==='quantum'&&params.showProbability&&<section className="af-atomic-notes"><h3>Radial probability · n = {n}, l = {l}</h3><svg viewBox="0 0 420 130" role="img" aria-label="Relative radial probability distribution" className="af-atomic-radial"><path d="M35 15V105H400" fill="none" stroke="#64748b"/><path d={radial.map((p,i)=>`${i?'L':'M'}${35+p.r/(10*n)*365} ${105-p.d/maxD*80}`).join(' ')} fill="none" stroke="#4f46e5" strokeWidth="3"/><text x="38" y="125" fontSize="12">0</text><text x="285" y="125" fontSize="12">r / a₀ → {10*n}</text></svg></section>}
    </>}
  </div>;
}
