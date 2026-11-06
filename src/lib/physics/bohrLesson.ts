import {bohrEnergy,transitionWavelength} from './atomicModels';
export type LessonPhase='ready'|'incoming'|'excited'|'emitting'|'complete'|'missed';
export type LessonState={phase:LessonPhase;age:number;cycle:boolean;matched:boolean};
export const initialLesson=():LessonState=>({phase:'ready',age:0,cycle:false,matched:true});
export const phaseDuration={incoming:1.8,excited:2.2,emitting:2,missed:1.2,complete:1,ready:1};
export function occupiedLevel(state:LessonState,lower:number,upper:number){return state.phase==='excited'?upper:lower;}
export function startLesson(cycle:boolean,matched=true):LessonState{return{phase:'incoming',age:0,cycle,matched};}
export function nextLesson(state:LessonState):LessonState{
 const phase:LessonPhase=state.phase==='incoming'?(state.matched?'excited':'missed'):state.phase==='excited'?'emitting':state.phase==='emitting'?'complete':state.phase==='missed'?'ready':state.phase==='complete'?'ready':'incoming';
 return{...state,phase,age:0};
}
export function advanceLesson(state:LessonState,dt:number):LessonState{
 if(!Number.isFinite(dt)||dt<=0||['ready','complete'].includes(state.phase)||(state.phase==='excited'&&!state.cycle))return state;
 const age=state.age+dt;return age>=phaseDuration[state.phase]?nextLesson(state):{...state,age};
}
export function lessonPhoton(lower:number,upper:number,Z:number,matched=true){
 const gap=bohrEnergy(upper,Z)-bohrEnergy(lower,Z);
 // Off-resonance lies strictly between adjacent upper levels, below ionisation.
 const energy=matched?gap:(gap+bohrEnergy(upper+1,Z)-bohrEnergy(lower,Z))/2;
 return{gap,energy,wavelength:matched?transitionWavelength(upper,lower,Z):1240/energy,region:1240/energy<380?'ultraviolet':1240/energy>780?'infrared':'visible'};
}
export function energyY(n:number,Z:number,height:number){const floor=bohrEnergy(1,Z);return 12+(bohrEnergy(n,Z)/floor)*(Math.max(24,height)-24);}
export function spacedEnergyLabels(lower:number,upper:number,Z:number,height:number){
 const rows=[upper,lower].map(n=>({n,y:energyY(n,Z,height),labelY:energyY(n,Z,height)})).sort((a,b)=>a.y-b.y);
 const gap=Math.min(30,Math.max(18,(height-20)/2));rows[0].labelY=Math.max(12,Math.min(rows[0].y,height-gap-12));rows[1].labelY=Math.max(rows[0].labelY+gap,Math.min(rows[1].y,height-12));return rows;
}
