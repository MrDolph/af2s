'use client';
import {useEffect,useState} from 'react';
import {FIELDS} from '@/lib/physics/gradientField';
import {gradientCoordinate,gradientAngle,gradientNumber as f,gradientSubstitution,unitDirection} from '@/lib/physics/gradientReadout';
type Props={fieldIndex:number;point:{x:number;y:number};angleDeg:number;onPointChange:(p:{x:number;y:number})=>void;onAngleChange:(v:number)=>void};
export function GradientReadout({fieldIndex,point,angleDeg,onPointChange,onAngleChange}:Props){
 const field=FIELDS[fieldIndex],phi=field.f(point.x,point.y),gx=field.gx(point.x,point.y),gy=field.gy(point.x,point.y),a=unitDirection(angleDeg),directional=gx*a.x+gy*a.y,magnitude=Math.hypot(gx,gy);
 const alpha=magnitude>0?Math.acos(Math.max(-1,Math.min(1,directional/magnitude)))*180/Math.PI:null;
 return <>
 <div className="af-gradient-inputs flex flex-wrap items-end gap-3 rounded-xl border border-gray-200 bg-white p-3">
  <ExactInput label="Point x" value={point.x} step={0.0001} sanitize={gradientCoordinate} min={-3} max={3} commit={x=>onPointChange({...point,x:gradientCoordinate(x)})}/>
  <ExactInput label="Point y" value={point.y} step={0.0001} sanitize={gradientCoordinate} min={-3} max={3} commit={y=>onPointChange({...point,y:gradientCoordinate(y)})}/>
  <ExactInput label="Direction θ (degrees)" value={angleDeg} step={0.01} sanitize={gradientAngle} commit={n=>onAngleChange(gradientAngle(n))}/>
  <button type="button" className="min-h-11 rounded-lg border border-indigo-200 px-3 text-xs font-medium text-indigo-700" onClick={()=>{onPointChange({x:1,y:1});onAngleChange(90);}}>Set P = (1, 1), θ = 90°</button>
  <p className="text-xs text-gray-600">Press Enter or Tab to apply typed values.</p>
 </div>
 <div className="af-gradient-angle-control rounded-xl border border-gray-200 bg-white p-3">
  <label className="text-xs text-gray-700">Direction θ: {f(angleDeg,2)}°<input aria-label="Unit vector direction in degrees" type="range" min={0} max={359.99} step={0.01} value={angleDeg} onChange={e=>onAngleChange(gradientAngle(Number(e.target.value)))} className="block w-full accent-amber-600"/></label>
 </div>
 <div className="af-minitab-live-readout af-gradient-readout rounded-2xl border border-gray-100 bg-white p-4 space-y-2">
  <p className="mb-2 text-xs font-medium uppercase tracking-wide text-gray-500">Live readout · {field.name}</p>
  {[
   ['Position P = (x, y)',`(${f(point.x)}, ${f(point.y)})`],
   ['Scalar value φ(P)',f(phi,8)],
   ['Gradient ∇φ(P)',`(${f(gx)}, ${f(gy)})`],
   ['Gradient magnitude |∇φ|',f(magnitude)],
   ['Direction angle θ',`${f(angleDeg,2)}°`],
   ['Unit vector â = (cos θ, sin θ)',`(${f(a.x)}, ${f(a.y)})`],
   ['Rate along â: D_âφ',f(directional)],
  ].map(([label,value])=><div key={label} className="af-minitab-stat flex justify-between gap-3 rounded-lg bg-gray-50 px-3 py-2"><span className="text-xs text-gray-600">{label}</span><span className="text-xs font-semibold tabular-nums text-indigo-800">{value}</span></div>)}
 </div>
 <details className="af-gradient-working rounded-xl border border-indigo-100 bg-indigo-50 p-3 text-xs leading-6 text-indigo-950">
  <summary className="cursor-pointer font-semibold">How these quantities connect · calculation and direction</summary>
  <p className="mt-2 font-mono">{gradientSubstitution(fieldIndex,point.x,point.y,phi)}</p>
  <p className="mt-2">θ is measured anticlockwise from the positive x-axis. It gives a direction, not a position or a path. The same direction in component form is â = (cos θ, sin θ), with length 1.</p>
  <p className="mt-2 font-mono">â = (cos {f(angleDeg,2)}°, sin {f(angleDeg,2)}°) ≈ ({f(a.x)}, {f(a.y)})</p>
  <p className="mt-2 font-mono">D_âφ = ({f(gx)}) × ({f(a.x)}) + ({f(gy)}) × ({f(a.y)}) ≈ {f(directional)}</p>
  <p className="mt-2">The alternative formula is D_âφ = |∇φ| cos α. Here α is the angle between ∇φ and â, whereas θ is measured from the x-axis. {alpha===null?'At zero gradient, α is undefined and every directional derivative is zero.':`For these settings, α ≈ ${f(alpha,2)}°.`}</p>
  <p className="mt-2">P tells you where to evaluate the scalar field. φ is its value there. ∇φ points towards steepest increase; it need not point along â. D_âφ is the rate of change in the direction you chose.</p>
  <p className="mt-2">For example, θ = 90° gives â = (0, 1). Conversely, a unit vector (aₓ, aᵧ) gives θ = atan2(aᵧ, aₓ), converted to degrees. atan2 uses both signs to choose the correct quadrant.</p>
  <p className="mt-2">Displayed coordinates are the values used in the calculation, to four decimal places. Dragging uses this same precision. Direction is set to 0.01°. Trigonometric components and the other results are rounded for display.</p>
 </details>
 </>;
}
function ExactInput({label,value,step,min,max,sanitize,commit}:{label:string;value:number;step:number;min?:number;max?:number;sanitize:(v:number)=>number;commit:(v:number)=>void}){
 const [draft,setDraft]=useState(String(value));useEffect(()=>setDraft(String(value)),[value]);
 function apply(){if(draft.trim()&&Number.isFinite(Number(draft))){const n=sanitize(Number(draft));setDraft(String(n));commit(n);}else setDraft(String(value));}
 return <label className="block text-xs text-gray-700">{label}<input aria-label={label} type="number" min={min} max={max} step={step} value={draft} onChange={e=>setDraft(e.target.value)} onBlur={apply} onKeyDown={e=>{if(e.key==='Enter')e.currentTarget.blur();}} className="mt-1 block w-32 rounded-lg border border-gray-300 bg-white p-2 text-gray-900"/></label>;
}
