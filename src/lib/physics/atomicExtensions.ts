import {bohrEnergy,BOHR_MAGNETON,FINE_STRUCTURE} from './atomicModels';
export function effectiveCharge(Z:number,screening=0){const sigma=Math.max(0,Math.min(Number.isFinite(screening)?screening:0,Math.max(0,Z-1)));return{sigma,Zeff:Z-sigma};}
export function zeemanShifts(B:number){return[-1,0,1].map(m=>({m,shift:m*BOHR_MAGNETON*Math.max(0,B)}));}
export function fineEnergy(n:number,j:number,Zeff:number){const E=bohrEnergy(n,Zeff);return E*(1+(Zeff*FINE_STRUCTURE)**2/n*(1/(j+.5)-3/(4*n)));}
export function fineSeparation(n:number,Zeff:number){return Math.abs(fineEnergy(Math.max(2,n),.5,Zeff)-fineEnergy(Math.max(2,n),1.5,Zeff));}
export function displayOrbit(n:number,R:number,Zeff:number){return R*(.14+.86*(n-1)/6)/(1+.13*Math.log(Math.max(1,Zeff)));}
export type OriginalMotion={n:number;angle:number;transition:{from:number;to:number;progress:number;angle:number}|null};
export function initialMotion():OriginalMotion{return{n:1,angle:0,transition:null};}
export function beginTransition(state:OriginalMotion,to:number):OriginalMotion{if(state.transition||to===state.n||!Number.isInteger(to)||to<1||to>7)return state;return{...state,transition:{from:state.n,to,progress:0,angle:state.angle}};}
export function advanceMotion(state:OriginalMotion,dt:number,speed:number){
 if(dt<=0||speed<=0)return{state,completed:null};
 if(!state.transition)return{state:{...state,angle:state.angle+dt*speed*2.2/state.n},completed:null};
 const t={...state.transition,progress:state.transition.progress+dt*speed*.8};
 if(t.progress>=1)return{state:{n:t.to,angle:t.angle,transition:null},completed:{from:t.from,to:t.to,angle:t.angle}};
 return{state:{...state,transition:t},completed:null};
}
export function movingRadius(from:number,to:number,progress:number,R:number,Zeff:number){const start=displayOrbit(from,R,Zeff),end=displayOrbit(to,R,Zeff);const t=to>from?Math.max(0,(progress-.3)/.7):progress;return start+(end-start)*Math.min(1,t);}
