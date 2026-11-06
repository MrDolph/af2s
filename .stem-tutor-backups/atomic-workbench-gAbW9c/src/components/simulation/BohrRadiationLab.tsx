'use client';
import {useEffect,useId,useRef,useState} from 'react';
import {bohrEnergy,bohrRadius,bohrVelocity,type AtomicParams} from '@/lib/physics/atomicModels';
import {BohrCalculations} from './BohrCalculations';
import {atomViewBox,orbitRadius,viewZoom} from '@/lib/physics/bohrWorkbench';
import {advanceLesson,energyY,initialLesson,lessonPhoton,nextLesson,occupiedLevel,phaseDuration,spacedEnergyLabels,startLesson,type LessonState} from '@/lib/physics/bohrLesson';
type Stats={energy:number;radius:number;velocity:number;n:number;wavelength:number;shellConfig:string};
type Props={params:AtomicParams;interactive?:boolean;viewReset?:number;onTick?:(stats:Stats)=>void};
const phases=['ready','incoming','excited','emitting','complete'];
const titles:Record<string,string>={ready:'1 · Atom in its lower state',incoming:'2 · Incoming photon',excited:'3 · Absorbed → excited atom',emitting:'4 · Relaxation → emitted photon',complete:'5 · Lower state restored',missed:'Photon not absorbed'};
function Packet({x,y,angle,color}:{x:number;y:number;angle:number;color:string}){return <g transform={`translate(${x} ${y}) rotate(${angle})`}><path d={Array.from({length:49},(_,i)=>`${i?'L':'M'}${i-24} ${Math.sin(i*Math.PI/8)*8*Math.sin(i/48*Math.PI)}`).join(' ')} fill="none" stroke={color} strokeWidth="4" strokeLinecap="round"/><path d="M25 -5L34 0L25 5" fill="none" stroke={color} strokeWidth="2.5"/></g>;}
export function BohrRadiationLab({params:p,onTick,interactive=true,viewReset=0}:Props){
 const [lower,setLower]=useState(1),[upper,setUpper]=useState(2),[matched,setMatched]=useState(true),[state,setState]=useState<LessonState>(initialLesson),[playing,setPlaying]=useState(false);
 const [pan,setPan]=useState({x:0,y:0}),[angle,setAngle]=useState(Math.PI),[repeat,setRepeat]=useState(false),[cueAge,setCueAge]=useState(0);
 useEffect(()=>{setCueAge(0);},[state.phase]);
 const emissionOrigin=useRef({x:130,y:220});
 const drag=useRef<{x:number;y:number;pan:{x:number;y:number}}|null>(null);
 const phaseRef=useRef(state.phase);phaseRef.current=state.phase;
 const orbitAngleRef=useRef(Math.PI);
 useEffect(()=>{setPan({x:0,y:0});},[viewReset]);
 const uid=useId().replace(/:/g,''),pairId=uid+'pair',photonId=uid+'photon';
 const onTickRef=useRef(onTick);onTickRef.current=onTick;
 const energyBox=useRef<HTMLDivElement>(null);const [energyHeight,setEnergyHeight]=useState(260);
 const Z=p.protonCount||1,photon=lessonPhoton(lower,upper,Z,matched),n=occupiedLevel(state,lower,upper),progress=Math.min(1,state.age/phaseDuration[state.phase]);
 useEffect(()=>{setState(initialLesson());setPlaying(false);orbitAngleRef.current=Math.PI;setAngle(Math.PI);},[lower,upper,Z]);
 useEffect(()=>{if(!p.showElectrons)setPlaying(false);},[p.showElectrons]);
 useEffect(()=>{const el=energyBox.current;if(!el)return;const observer=new ResizeObserver(()=>setEnergyHeight(Math.max(60,el.getBoundingClientRect().height)));observer.observe(el);return()=>observer.disconnect();},[p.showEnergyLevels]);
 useEffect(()=>{if(!playing||p.speed<=0)return;let frame=0,last:number|null=null;const tick=(now:number)=>{const dt=last===null?0:Math.min(.05,(now-last)/1000)*p.speed;last=now;setState(old=>advanceLesson(old,dt));setCueAge(v=>v+dt);if(phaseRef.current!=='incoming'&&phaseRef.current!=='missed'){orbitAngleRef.current-=dt*.9;setAngle(orbitAngleRef.current);}frame=requestAnimationFrame(tick);};frame=requestAnimationFrame(tick);return()=>cancelAnimationFrame(frame);},[playing,p.speed]);
 useEffect(()=>{if(state.phase==='complete'&&repeat&&state.cycle){setState(startLesson(true,matched));orbitAngleRef.current=Math.PI;setAngle(Math.PI);return;}if(state.phase==='complete'||state.phase==='ready'||(state.phase==='excited'&&!state.cycle))setPlaying(false);},[state.phase,state.cycle,repeat,matched]);
 useEffect(()=>{onTickRef.current?.({n,energy:bohrEnergy(n,Z),radius:bohrRadius(n,Z),velocity:bohrVelocity(n,Z)/2.998e8,wavelength:['incoming','emitting'].includes(state.phase)?photon.wavelength:0,shellConfig:''});},[n,Z,state.phase,photon.wavelength]);
 function begin(cycle:boolean){orbitAngleRef.current=Math.PI;setAngle(Math.PI);setState(startLesson(cycle,matched));setPlaying(true);}
 function step(){setPlaying(false);if(state.phase==='ready'||state.phase==='complete'){orbitAngleRef.current=Math.PI;setAngle(Math.PI);}setState(old=>old.phase==='ready'||old.phase==='complete'?startLesson(false,matched):nextLesson(old));}
 const incoming=state.phase==='incoming',excited=state.phase==='excited',emitting=state.phase==='emitting',missed=state.phase==='missed';
 const shellMax=Math.min(7,Math.max(3,upper+1)),rLower=orbitRadius(lower,shellMax),rUpper=orbitRadius(upper,shellMax);
 const a=incoming||missed?Math.PI:angle,oldRadius=excited?rLower:rUpper,newRadius=excited?rUpper:rLower;
 const currentRadius=orbitRadius(n,shellMax),electronX=300+Math.cos(a)*currentRadius,electronY=220+Math.sin(a)*currentRadius;
 const jumpVisible=(excited||emitting)&&cueAge<1.2;
 const box=atomViewBox(p.zoom,pan),absorbX=300-rLower,emitX=emissionOrigin.current.x,emitY=emissionOrigin.current.y;
 useEffect(()=>{if(state.phase==='emitting')emissionOrigin.current={x:300+Math.cos(orbitAngleRef.current)*rUpper,y:220+Math.sin(orbitAngleRef.current)*rUpper};},[state.phase,rUpper]);
 const outgoingAngle=-.65;
 const levelRows=spacedEnergyLabels(lower,upper,Z,energyHeight);
 const text= incoming?'The atom remains in its lower state while the photon approaches.':excited?`The photon has disappeared: its energy raised the atom from n = ${lower} to n = ${upper}.`:emitting?`The electron is back at n = ${lower}. The energy difference leaves as one photon, travelling away from the atom.`:missed?'The photon energy does not match this or another bound-state gap in this idealised example. It passes without excitation.':state.phase==='complete'?'The outgoing photon carries the energy previously stored in the excited atom. Play again or choose another pair of states.':`Begin with an atom at n = ${lower}. A matching photon supplies the exact energy needed for excitation.`;
 const lightColor=matched?'#c2410c':'#64748b';
 return <section className="af-bohr-lesson" aria-label="Photon absorption, excitation and relaxation">
  {interactive&&<header className="af-bohr-controls">
   <label className="af-bohr-pair" htmlFor={pairId}>States<select id={pairId} aria-label="Transition pair" value={`${lower}-${upper}`} onChange={e=>{const [a,b]=e.target.value.split('-').map(Number);setLower(a);setUpper(b);}}>{[1,2,3,4,5,6].flatMap(a=>[2,3,4,5,6,7].filter(b=>b>a).map(b=><option key={`${a}-${b}`} value={`${a}-${b}`}>n={a} ↔ n={b}</option>))}</select></label>
   <label className="af-bohr-photon-choice" htmlFor={photonId}>Photon<select id={photonId} value={matched?'matched':'detuned'} disabled={playing||excited} onChange={e=>{setMatched(e.target.value==='matched');setState(initialLesson());}}><option value="matched">Matching energy</option><option value="detuned">Off-resonance</option></select></label>
   <div className="af-bohr-actions"><button type="button" onClick={()=>begin(true)} disabled={playing||excited||!p.showElectrons} aria-label="Play full absorption and emission cycle">▶ Cycle</button><button type="button" onClick={()=>begin(false)} disabled={playing||excited||!p.showElectrons}>Send photon</button><button type="button" disabled={!excited||!p.showElectrons} onClick={()=>{setState(old=>({...old,phase:'emitting',age:0}));setPlaying(true);}} aria-label="Let atom relax">Relax</button><button type="button" disabled={!p.showElectrons||['ready','complete'].includes(state.phase)} onClick={()=>setPlaying(v=>!v)}>{playing?'Pause':excited&&!state.cycle?'Orbit motion':'Resume'}</button><button type="button" disabled={!p.showElectrons} onClick={step} aria-label="Next stage">Step</button><button type="button" onClick={()=>{setState(initialLesson());setPlaying(false);orbitAngleRef.current=Math.PI;setAngle(Math.PI);}}>Reset</button></div><label className="af-bohr-repeat"><input type="checkbox" checked={repeat} onChange={e=>setRepeat(e.target.checked)}/> Repeat cycle</label>
  </header>}
  <div className="af-bohr-metrics"><span>ΔE <strong>{photon.gap.toFixed(3)} eV</strong></span><span>Photon <strong>{photon.energy.toFixed(3)} eV</strong></span><span>λ <strong>{photon.wavelength.toFixed(1)} nm · {photon.region}</strong></span><span>State <strong>n = {n}{n===1?' · ground':' · excited'}</strong></span></div>
  <ol className="af-bohr-story" aria-label="Radiation sequence">{['Lower state','Photon arrives','Excited atom','Photon emitted','Lower state'].map((label,i)=><li key={i} data-active={phases.indexOf(state.phase)===i}><span>{i+1}</span>{label}</li>)}</ol>
  <div className="af-bohr-workspace">
  <div className="af-bohr-diagrams" data-levels={p.showEnergyLevels}>
   <figure className="af-bohr-atom"><figcaption>Atom · {excited?`n=${lower} → n=${upper}`:emitting?`n=${upper} → n=${lower}`:`n=${n}`} <small>Blue electron · amber nucleus · drag to pan · {viewZoom(p.zoom).toFixed(1)}×</small></figcaption><svg viewBox={`${box.x} ${box.y} ${box.width} ${box.height}`} className="af-bohr-zoom-scene" onPointerDown={e=>{drag.current={x:e.clientX,y:e.clientY,pan};e.currentTarget.setPointerCapture(e.pointerId);}} onPointerMove={e=>{if(!drag.current)return;const scale=e.currentTarget.getScreenCTM()?.a||1;setPan({x:drag.current.pan.x-(e.clientX-drag.current.x)/scale,y:drag.current.pan.y-(e.clientY-drag.current.y)/scale});}} onPointerUp={()=>{drag.current=null;}} onPointerCancel={()=>{drag.current=null;}} role="img" aria-label={`Electron in state n=${n}. ${titles[state.phase]}`}>
    <defs><radialGradient id={uid+'bg'}><stop offset="0" stopColor="#fff"/><stop offset="1" stopColor="#eff6ff"/></radialGradient></defs>
    <ellipse cx="300" cy="220" rx="205" ry="202" fill={`url(#${uid}bg)`}/>
    {p.showOrbits&&Array.from({length:shellMax},(_,i)=>i+1).map(shell=><g key={shell}><circle cx="300" cy="220" r={orbitRadius(shell,shellMax)} fill="none" stroke={n===shell?'#2563eb':shell===upper?'#a78bfa':'#cbd5e1'} strokeWidth={n===shell?3.5:1.3}/>{p.showLabels&&<text x={300+orbitRadius(shell,shellMax)*Math.cos(-.65)} y={220+orbitRadius(shell,shellMax)*Math.sin(-.65)} fill={n===shell?'#1e40af':'#475569'} stroke="#f8fafc" strokeWidth="5" paintOrder="stroke" fontSize="15" fontWeight="600">n={shell}</text>}</g>)}
    {p.showNucleus&&<g><circle cx="300" cy="220" r="16" fill="#f59e0b" stroke="#92400e" strokeWidth="2"/><text x="300" y="227" textAnchor="middle" fill="#78350f" fontSize="24" fontWeight="700" className="af-bohr-nuclear-sign">+</text></g>}
    {p.showLabels&&<text x="300" y="253" textAnchor="middle" fill="#92400e" fontSize="15">Z={Z}</text>}
    {jumpVisible&&<g className="af-bohr-orbit-jump" aria-label={excited?'Excitation on orbital structure':'Relaxation on orbital structure'}>
      <defs><marker id={uid+'jump'} markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0 0L6 3L0 6" fill={excited?'#c2410c':'#7c3aed'}/></marker></defs>
      <circle cx={300+Math.cos(a)*oldRadius} cy={220+Math.sin(a)*oldRadius} r="10" fill="none" stroke={excited?'#2563eb':'#7c3aed'} strokeWidth="2" strokeDasharray="3 3" opacity=".65"/>
      <path d={`M${300+Math.cos(a)*oldRadius} ${220+Math.sin(a)*oldRadius} Q${300+Math.cos(a)*(oldRadius+newRadius)/2-Math.sin(a)*28} ${220+Math.sin(a)*(oldRadius+newRadius)/2+Math.cos(a)*28} ${electronX} ${electronY}`} stroke={excited?'#c2410c':'#7c3aed'} strokeWidth="3" fill="none" strokeDasharray="5 4" markerEnd={`url(#${uid}jump)`}/>
    </g>}
    {p.showElectrons&&<g transform={`translate(${electronX} ${electronY})`}><circle r="14" fill={excited?'#7c3aed':'#2563eb'} stroke="#fff" strokeWidth="3"/><path d="M-6 0H6" stroke="#fff" strokeWidth="2.5"/>{p.showSpin&&<text x="0" y="-21" fill="#be123c" fontSize="24">↑</text>}</g>}
    {incoming&&<Packet x={25+(absorbX-25)*progress} y={220} angle={0} color={lightColor}/>}
    {missed&&<Packet x={absorbX+(560-absorbX)*progress} y={220} angle={0} color="#64748b"/>}
    {emitting&&<Packet x={emitX+Math.cos(outgoingAngle)*340*progress} y={emitY+Math.sin(outgoingAngle)*340*progress} angle={outgoingAngle*180/Math.PI} color="#7c3aed"/>}
    {(incoming||missed)&&<text x="105" y="178" fill={lightColor} textAnchor="middle" fontSize="19" fontWeight="600">Incoming photon</text>}
    {emitting&&<text x="420" y="35" fill="#6d28d9" textAnchor="middle" fontSize="19" fontWeight="600">Outgoing photon</text>}
    {excited&&<g><circle cx={electronX} cy={electronY} r="23" fill="none" stroke="#7c3aed" strokeWidth="2"/><text x="300" y="423" textAnchor="middle" fill="#6d28d9" fontSize="20" fontWeight="600">Excited n={upper} · +{photon.gap.toFixed(3)} eV stored</text></g>}
   </svg></figure>
   {p.showEnergyLevels&&<figure className="af-bohr-energy"><figcaption>Energy states <small>Selected levels · energy ↑</small></figcaption><div ref={energyBox} className="af-bohr-energy-plot">
    <svg width="100%" height="100%" aria-hidden="true"><defs><marker id={uid+'arrow'} markerWidth="8" markerHeight="8" refX="6" refY="3" orient="auto"><path d="M0 0L6 3L0 6" fill={emitting?'#7c3aed':'#c2410c'}/></marker></defs><line x1="12%" x2="68%" y1="8" y2="8" stroke="#cbd5e1" strokeDasharray="4 4"/>
    {levelRows.map(row=><g key={row.n}><line x1="12%" x2="58%" y1={row.y} y2={row.y} stroke={n===row.n?'#2563eb':'#94a3b8'} strokeWidth={n===row.n?3:1.5}/><line x1="58%" x2="64%" y1={row.y} y2={row.labelY} stroke="#94a3b8"/></g>)}
    {(excited||emitting)&&<line x1={excited?'30%':'47%'} x2={excited?'30%':'47%'} y1={energyY(excited?lower:upper,Z,energyHeight)} y2={energyY(excited?upper:lower,Z,energyHeight)} stroke={excited?'#c2410c':'#7c3aed'} strokeWidth="3" markerEnd={`url(#${uid}arrow)`}/>}
    <circle cx="20%" cy={energyY(n,Z,energyHeight)} r="5" fill="#2563eb"/>
    </svg>
    {energyHeight>150&&<span className="af-bohr-zero">0 eV · free electron</span>}
    {levelRows.map(row=><span className="af-bohr-energy-label" key={row.n} style={{top:row.labelY}}><strong>n = {row.n}</strong>{bohrEnergy(row.n,Z).toFixed(3)} eV</span>)}
   </div><p>Arrow = energy change,<br/>not a path through space.</p></figure>}
  </div>
  <BohrCalculations lower={lower} upper={upper} Z={Z} n={n} emission={emitting||state.phase==='complete'} missed={missed} photonEnergy={photon.energy}/>
  </div>
  <footer className="af-bohr-narration" data-phase={state.phase}><strong aria-live="polite">{titles[state.phase]}</strong><p>{text}</p><small>{p.showElectrons?'Radii are compressed; dashed orbital arrows cue a state jump, not travel through intermediate energies. Timing is illustrative.':'Enable electrons to run the lesson.'}</small></footer>
 </section>;
}
