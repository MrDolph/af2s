'use client';
import {useEffect,useRef,useState} from 'react';
import {bohrEnergy,bohrRadius,bohrVelocity,transitionWavelength,wavelengthToRGB,type AtomicParams} from '@/lib/physics/atomicModels';
import {advanceMotion,beginTransition,displayOrbit,effectiveCharge,fineSeparation,initialMotion,movingRadius,zeemanShifts} from '@/lib/physics/atomicExtensions';
import {viewZoom} from '@/lib/physics/bohrWorkbench';
import {BohrCalculations} from './BohrCalculations';
type Stats={energy:number;radius:number;velocity:number;n:number;wavelength:number;shellConfig:string};
type Props={params:AtomicParams;interactive?:boolean;viewReset?:number;isRunning?:boolean;isPaused?:boolean;controls?:{run:()=>void;pause:()=>void;reset:()=>void};onTick?:(s:Stats)=>void};
type Snapshot={n:number;from:number;to:number;kind:'orbit'|'absorption'|'emission';transitioning:boolean;wavelength:number};
const initialSnapshot:Snapshot={n:1,from:1,to:3,kind:'orbit',transitioning:false,wavelength:0};
const lightColour=(wl:number)=>wl<380?'#7c3aed':wl>780?'#b45309':wavelengthToRGB(wl);
function photonWave(ctx:CanvasRenderingContext2D,x:number,y:number,angle:number,colour:string){
 ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.strokeStyle=colour;ctx.fillStyle=colour;ctx.lineWidth=2.8;ctx.beginPath();for(let i=0;i<=48;i++){const px=-24+i,py=4*Math.sin(i/48*Math.PI*6);if(i===0)ctx.moveTo(px,py);else ctx.lineTo(px,py);}ctx.stroke();ctx.beginPath();ctx.moveTo(30,0);ctx.lineTo(21,-6);ctx.lineTo(21,6);ctx.closePath();ctx.fill();ctx.restore();
}
export function BohrRadiationLab({params:p,interactive=true,viewReset=0,isRunning=false,isPaused=false,controls,onTick}:Props){
 const canvas=useRef<HTMLCanvasElement>(null),wrap=useRef<HTMLDivElement>(null),motion=useRef(initialMotion()),pan=useRef({x:0,y:0}),drag=useRef<{x:number;y:number;pan:{x:number;y:number}}|null>(null);
 const photons=useRef<{x:number;y:number;angle:number;life:number;wavelength:number}[]>([]),pending=useRef(0),autoTime=useRef(0);
 const [target,setTarget]=useState(3),[auto,setAuto]=useState(true),[snap,setSnap]=useState<Snapshot>(initialSnapshot);
 const props=useRef({p,isRunning,isPaused,onTick,auto});props.current={p,isRunning,isPaused,onTick,auto};
 const {sigma,Zeff}=effectiveCharge(p.protonCount||1,p.screening),Z=p.protonCount||1;
 useEffect(()=>{pan.current={x:0,y:0};},[viewReset]);
 useEffect(()=>{motion.current={...motion.current,transition:null};photons.current=[];autoTime.current=0;setSnap(s=>({...s,transitioning:false,wavelength:0}));},[Z,sigma]);
 useEffect(()=>{
  const element=canvas.current,box=wrap.current;if(!element||!box)return;
  let frame=0,last:number|null=null,lastReport=0;let latest={...initialSnapshot};
  function draw(now:number){
   const el=element!,container=box!,ctx=el.getContext('2d');if(!ctx)return;
   const {p,isRunning,isPaused,onTick,auto}=props.current,q=effectiveCharge(p.protonCount||1,p.screening).Zeff;
   const {width:w,height:h}=container.getBoundingClientRect(),dpr=Math.min(2,window.devicePixelRatio||1);
   if(w<1||h<1){frame=requestAnimationFrame(draw);return;}
   const cw=Math.round(w*dpr),ch=Math.round(h*dpr);if(el.width!==cw||el.height!==ch){el.width=cw;el.height=ch;}ctx.setTransform(dpr,0,0,dpr,0,0);
   const elapsed=last===null?0:Math.min(.05,(now-last)/1000);last=now;const dt=isRunning&&!isPaused?elapsed:0;
   const R=Math.max(20,Math.min(w,h)*.43),cx=w/2,cy=h/2;
   if(pending.current){motion.current=beginTransition(motion.current,pending.current);pending.current=0;autoTime.current=0;}
   if(dt>0&&p.showElectrons){
    if(!motion.current.transition&&auto){autoTime.current+=dt*p.speed;if(autoTime.current>2.8){autoTime.current=0;const current=motion.current.n;let to=Math.max(1,Math.min(7,current+(Math.random()<.5?-1:1)*(1+Math.floor(Math.random()*2))));if(to===current)to=current===1?3:1;motion.current=beginTransition(motion.current,to);}}
    const result=advanceMotion(motion.current,dt,p.speed);motion.current=result.state;
    if(result.completed){const t=result.completed,wl=transitionWavelength(t.from,t.to,q);latest={n:t.to,from:t.from,to:t.to,kind:t.to<t.from?'emission':'absorption',transitioning:false,wavelength:wl};
     if(t.to<t.from){const r=displayOrbit(t.to,R,q);photons.current.push({x:cx+Math.cos(t.angle)*r,y:cy+Math.sin(t.angle)*r,angle:t.angle+1.1+Math.random()*.7,life:1,wavelength:wl});}autoTime.current=0;
    }
    photons.current=photons.current.map(ray=>({...ray,x:ray.x+Math.cos(ray.angle)*180*dt*p.speed,y:ray.y+Math.sin(ray.angle)*180*dt*p.speed,life:ray.life-dt*p.speed*.4})).filter(ray=>ray.life>0);
   }
   const s=motion.current,t=s.transition,angle=t?.angle??s.angle;
   if(t)latest={n:s.n,from:t.from,to:t.to,kind:t.to<t.from?'emission':'absorption',transitioning:true,wavelength:transitionWavelength(t.from,t.to,q)};
   else latest={...latest,n:s.n,transitioning:false,wavelength:latest.wavelength?transitionWavelength(latest.from,latest.to,q):0};
   ctx.clearRect(0,0,w,h);ctx.fillStyle='#f8fafc';ctx.fillRect(0,0,w,h);
   ctx.save();ctx.translate(cx+pan.current.x,cy+pan.current.y);ctx.scale(viewZoom(p.zoom),viewZoom(p.zoom));ctx.translate(-cx,-cy);
   if(p.showOrbits)for(let n=1;n<=7;n++){const r=displayOrbit(n,R,q);ctx.strokeStyle=n===s.n?'#2563eb':'#94a3b8';ctx.lineWidth=n===s.n?2.5:1.1;ctx.beginPath();ctx.arc(cx,cy,r,0,Math.PI*2);ctx.stroke();if(p.showLabels&&w>=420&&h>=280){const a=n%2?-.6:Math.PI+.6,x=cx+Math.cos(a)*r,y=cy+Math.sin(a)*r;ctx.fillStyle='#f8fafc';ctx.fillRect(x-14,y-9,28,18);ctx.fillStyle=n===s.n?'#1d4ed8':'#334155';ctx.font='600 12px system-ui';ctx.textAlign='center';ctx.fillText(`n=${n}`,x,y+4);}}
   if((p.screening||0)>0){const g=ctx.createRadialGradient(cx,cy,7,cx,cy,34);g.addColorStop(0,'rgba(59,130,246,.03)');g.addColorStop(.65,`rgba(59,130,246,${.12+Math.min(.3,(p.screening||0)/(p.protonCount||1)*.3)})`);g.addColorStop(1,'rgba(59,130,246,0)');ctx.fillStyle=g;ctx.beginPath();ctx.arc(cx,cy,34,0,Math.PI*2);ctx.fill();}
   if(p.showNucleus){ctx.fillStyle='#f59e0b';ctx.strokeStyle='#92400e';ctx.lineWidth=1.5;ctx.beginPath();ctx.arc(cx,cy,7,0,Math.PI*2);ctx.fill();ctx.stroke();ctx.fillStyle='#78350f';ctx.font='bold 13px system-ui';ctx.textAlign='center';ctx.fillText('+',cx,cy+4);}
   const r=t?movingRadius(t.from,t.to,t.progress,R,q):displayOrbit(s.n,R,q),ex=cx+Math.cos(angle)*r,ey=cy+Math.sin(angle)*r;
   if(t){const r1=displayOrbit(t.from,R,q),r2=displayOrbit(t.to,R,q);ctx.strokeStyle=t.to>t.from?'#c2410c':'#7c3aed';ctx.setLineDash([5,4]);ctx.lineWidth=2;ctx.beginPath();ctx.moveTo(cx+Math.cos(angle)*r1,cy+Math.sin(angle)*r1);ctx.lineTo(cx+Math.cos(angle)*r2,cy+Math.sin(angle)*r2);ctx.stroke();ctx.setLineDash([]);
    if(t.to>t.from&&t.progress<.3){const endX=cx+Math.cos(angle)*r1,endY=cy+Math.sin(angle)*r1,pr=t.progress/.3;const sx=endX-R*.8,sy=endY-R*.55,px=sx+(endX-sx)*pr,py=sy+(endY-sy)*pr,a=Math.atan2(endY-sy,endX-sx);photonWave(ctx,px,py,a,lightColour(transitionWavelength(t.from,t.to,q)));}
   }
   if(p.showElectrons){ctx.fillStyle='#2563eb';ctx.strokeStyle='#fff';ctx.lineWidth=2;ctx.beginPath();ctx.arc(ex,ey,7,0,Math.PI*2);ctx.fill();ctx.stroke();if(p.showSpin){ctx.fillStyle='#be123c';ctx.font='bold 19px system-ui';ctx.textAlign='center';ctx.fillText(p.spinProjection===-0.5?'↓':'↑',ex,ey-14);}}
   photons.current.forEach(ray=>{ctx.globalAlpha=Math.max(0,ray.life);photonWave(ctx,ray.x,ray.y,ray.angle,lightColour(ray.wavelength));ctx.globalAlpha=1;});ctx.restore();
   if(now-lastReport>90){lastReport=now;setSnap({...latest});onTick?.({n:s.n,energy:bohrEnergy(s.n,q),radius:bohrRadius(s.n,q),velocity:bohrVelocity(s.n,q)/2.998e8,wavelength:latest.wavelength,shellConfig:''});}
   frame=requestAnimationFrame(draw);
  }
  frame=requestAnimationFrame(draw);return()=>cancelAnimationFrame(frame);
 },[]);
 const pairLow=Math.min(snap.from,snap.to),pairHigh=Math.max(snap.from,snap.to),inspectN=Math.max(2,snap.n),fine=fineSeparation(inspectN,Zeff),zeeman=5.788e-5*p.magneticField;
 return <section className="af-bohr-lesson af-bohr-original" aria-label="Original Bohr orbital simulation">
  {interactive&&<header className="af-original-transport"><button type="button" onClick={isRunning?controls?.pause:controls?.run}>{!isRunning?'Run':isPaused?'Resume':'Pause'}</button><button type="button" onClick={controls?.reset}>Reset</button><label><input type="checkbox" checked={auto} onChange={e=>setAuto(e.target.checked)}/> Auto transitions</label><label>Target n<select aria-label="Transition target" value={target} onChange={e=>{const to=Number(e.target.value);setTarget(to);}}>{[1,2,3,4,5,6,7].map(n=><option key={n} value={n}>{n}</option>)}</select></label><button type="button" disabled={snap.transitioning||target===snap.n||!p.showElectrons} onClick={()=>{pending.current=target;if(!isRunning||isPaused)controls?.run();}}>Transition</button><strong>{snap.transitioning?`${snap.kind==='absorption'?'Absorbing':'Emitting'} · n=${snap.from} → ${snap.to}`:`Orbiting state n=${snap.n}`}</strong></header>}
  <div className="af-original-physics"><span>Zeff = Z − σ = <strong>{Z} − {sigma.toFixed(2)} = {Zeff.toFixed(2)}</strong></span>{p.showZeeman&&<span>Zeeman μB·B = <strong>{(zeeman*1e6).toFixed(2)} μeV</strong></span>}{p.showFineStructure&&<span>Fine split n={inspectN}: <strong>{(fine*1e6).toFixed(2)} μeV</strong></span>}{p.showSpin&&<span>Spin: <strong>{p.spinProjection===-0.5?'↓ mₛ = −½':'↑ mₛ = +½'}</strong> · projection, not rotation</span>}<span>λ: <strong>{snap.wavelength?snap.wavelength.toFixed(2)+' nm':'—'}</strong></span></div>
  <div className="af-bohr-workspace"><div className="af-bohr-diagrams" data-levels={p.showEnergyLevels}>
   <figure className="af-bohr-atom"><figcaption>Bohr orbits · n={snap.n}<small>Drag to pan · straight transition paths are schematic</small></figcaption><div className="af-original-canvas" ref={wrap}><canvas ref={canvas} role="img" aria-label={`Electron orbiting nucleus Z=${Z}; effective charge ${Zeff.toFixed(2)}; current state n=${snap.n}`} onPointerDown={e=>{drag.current={x:e.clientX,y:e.clientY,pan:{...pan.current}};e.currentTarget.setPointerCapture(e.pointerId);}} onPointerMove={e=>{const d=drag.current;if(d)pan.current={x:d.pan.x+e.clientX-d.x,y:d.pan.y+e.clientY-d.y};}} onPointerUp={()=>{drag.current=null;}} onPointerCancel={()=>{drag.current=null;}}/></div></figure>
   {p.showEnergyLevels&&<figure className="af-bohr-energy af-original-levels"><figcaption>Energy levels<small>Level spacing schematic · splitting enlarged</small></figcaption><div className="af-original-level-list">{[7,6,5,4,3,2,1].map(n=><div className="af-original-level" key={n} data-active={n===snap.n}><span>n={n}</span><svg viewBox="0 0 80 28" role="img" aria-label={`n=${n}: ${bohrEnergy(n,Zeff).toFixed(4)} eV${p.showZeeman&&n>1?'; Zeeman triplet enlarged':''}`}><line x1="2" x2="78" y1="14" y2="14" stroke="#94a3b8" strokeWidth={n===snap.n?2.5:1}/>{p.showFineStructure&&n>1&&[-1,1].map(sign=><line key={sign} x1="3" x2="34" y1={14+sign*3} y2={14+sign*3} stroke="#2563eb" strokeWidth="2"/>)}{p.showZeeman&&n>1&&[-1,0,1].map(m=><line key={m} x1="42" x2="78" y1={14-m*p.magneticField*1.5} y2={14-m*p.magneticField*1.5} stroke="#a21caf" strokeWidth="2"/>)}</svg><strong>{Math.abs(bohrEnergy(n,Zeff))<10000?bohrEnergy(n,Zeff).toFixed(3):bohrEnergy(n,Zeff).toExponential(2)}</strong></div>)}</div><p>eV · blue: fine · magenta: normal Zeeman. Separate schematic illustrations.</p></figure>}
   </div><BohrCalculations lower={pairLow} upper={pairHigh} Z={Zeff} n={snap.n} emission={snap.kind==='emission'} missed={false} chargeSymbol={sigma>0?'Zeff':'Z'} photonEnergy={Math.abs(bohrEnergy(snap.to,Zeff)-bohrEnergy(snap.from,Zeff))}/></div>
  {p.showSpectrum&&<section className="af-transition-spectra" aria-label="Absorption and emission spectra" data-active={snap.transitioning?snap.kind:'idle'}>{(['absorption','emission'] as const).map(kind=><div className="af-spectrum-row" key={kind} data-highlight={snap.transitioning&&snap.kind===kind}><span>{kind==='absorption'?'Absorption':'Emission'}{snap.transitioning&&snap.kind===kind?' · active':''}</span><div className={`af-spectrum-band af-spectrum-${kind}`} role="img" aria-label={`${kind} spectrum: ${snap.wavelength?snap.wavelength.toFixed(2)+' nm':'no transition yet'}${snap.wavelength&&(snap.wavelength<380||snap.wavelength>780)?'; outside visible band':''}`}>{snap.wavelength>=380&&snap.wavelength<=780&&<i style={{left:((snap.wavelength-380)/400*100)+'%',background:kind==='absorption'?'#080b12':lightColour(snap.wavelength)}}/>}</div></div>)}<small>Visible band 380–780 nm · {snap.wavelength?snap.wavelength.toFixed(2)+' nm':'choose a transition'}{snap.wavelength>0&&(snap.wavelength<380||snap.wavelength>780)?' · outside visible band; ray uses false colour':''}. Dark line: removed light; bright line: emitted light. Schematic single transition.</small>{p.showZeeman&&<div className="af-original-zeeman-spectrum"><span>Normal-Zeeman triplet · enlarged</span><svg viewBox="0 0 180 22" role="img" aria-label={`Three line shifts: ${zeemanShifts(p.magneticField).map(s=>(s.shift*1e6).toFixed(2)).join(', ')} microelectronvolts`}>{[-1,0,1].map(m=><line key={m} x1={90+m*p.magneticField*12} x2={90+m*p.magneticField*12} y1="2" y2="20" stroke="#a21caf" strokeWidth="3"/>)}</svg></div>}</section>}
  <footer className="af-bohr-narration"><aside className="af-bohr-model-brief" aria-label="Niels Bohr model brief"><strong>Niels Bohr (1913)</strong><span>Stationary states: no radiation</span><span>L = nℏ · quantised angular momentum</span><span>Eₙ = −13.606 Z²/n² eV · hydrogen-like atom</span><span>Eγ = hν = |ΔE| · absorption / emission</span>{sigma>0&&<span>Screening approximation: replace Z with Zeff = Z − σ</span>}</aside><strong>{snap.transitioning?`${snap.kind==='absorption'?'Energy absorbed':'Energy released'} · n=${snap.from} → ${snap.to}`:'Circular motion in an allowed Bohr orbit'}</strong><small>Orbit spacing and transition paths are schematic. Screening uses a chosen σ in a hydrogenic approximation; normal Zeeman and fine-structure illustrations are separate. UV/IR rays use false colour.</small></footer>
 </section>;
}
