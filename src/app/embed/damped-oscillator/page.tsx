'use client';
import { useCallback,useEffect,useRef,useState } from 'react';
import { MinitabStage } from '@/components/simulation/MinitabStage';
import { DampedOscillatorCanvas } from '@/components/simulation/DampedOscillatorCanvas';
import { DampedOscillatorGraph } from '@/components/simulation/DampedOscillatorGraph';
import { SimulationControls } from '@/components/simulation/SimulationControls';
import { useResponsiveCanvasSize } from '@/hooks/useResponsiveCanvasSize';
import { dampedEmbedDefaults,dampedEmbedSettings } from '@/lib/physics/dampedEmbed';

export default function DampedOscillatorEmbed(){
 const [params,setParams]=useState(dampedEmbedDefaults),[controls,setControls]=useState(true);
 const [running,setRunning]=useState(false),[paused,setPaused]=useState(false),[time,setTime]=useState(0),[resetKey,setResetKey]=useState(0);
 const box=useRef<HTMLDivElement>(null),lastTick=useRef(0);
 const size=useResponsiveCanvasSize(box,380,300,1000);
 useEffect(()=>{setParams(dampedEmbedSettings(window.location.search));setControls(new URLSearchParams(window.location.search).get('controls')!=='0');},[]);
 useEffect(()=>{setRunning(false);setPaused(false);setTime(0);},[params]);
 const tick=useCallback((t:number)=>{const now=performance.now();if(now-lastTick.current>40||t===0){lastTick.current=now;setTime(t);}},[]);
 function reset(){setRunning(false);setPaused(false);setTime(0);setResetKey(k=>k+1);}
 return <main className="mx-auto max-w-6xl space-y-3 bg-gray-50 p-3 text-gray-900 sm:p-4">
 <h1 className="text-sm font-semibold">Damped oscillator</h1>
 <MinitabStage className="af-embed-stage space-y-3">
  <div data-stage-role="canvas" className="af-minitab-damped-scene space-y-3">
   <div ref={box} className="af-minitab-canvas-frame flex justify-center rounded-2xl border border-gray-200 bg-white p-3">
    <DampedOscillatorCanvas key={resetKey} {...params} isRunning={running} isPaused={paused} onTick={tick} width={size.width} height={size.height}/>
   </div>
   <div className="af-minitab-damped-graph rounded-2xl border border-gray-200 bg-white p-3">
    <p className="mb-2 text-xs text-gray-600">Displacement y(t) · time {time.toFixed(2)} s</p>
    <DampedOscillatorGraph {...params} currentT={time}/>
   </div>
  </div>
  {controls&&<div data-stage-role="parameters" className="flex flex-wrap gap-4 rounded-xl border border-gray-200 bg-white p-3">
   {([
    ['gamma','Damping γ',0,6,0.05,'1/s'],
    ['omega0','Natural frequency ω₀',0.5,6,0.05,'rad/s'],
    ['y0','Initial displacement',-2,2,0.1,''],
    ['yp0','Initial velocity',-4,4,0.1,'/s'],
   ] as const).map(([key,label,min,max,step,unit])=><label key={key} className="block text-xs text-gray-700">{label}: {params[key]} {unit}<input aria-label={label} className="block w-56 accent-indigo-600" type="range" min={min} max={max} step={step} value={params[key]} onChange={e=>setParams(p=>({...p,[key]:Number(e.target.value)}))}/></label>)}
  </div>}
  {controls&&<div data-stage-role="playback"><SimulationControls isRunning={running} isPaused={paused} onRun={()=>{setRunning(true);setPaused(false);}} onPause={()=>setPaused(p=>!p)} onReset={reset}/></div>}
 </MinitabStage>
 <a href="/minitab/damped-oscillator" target="_blank" rel="noreferrer" className="text-xs text-indigo-700 underline">Open full lesson</a>
 </main>;
}
