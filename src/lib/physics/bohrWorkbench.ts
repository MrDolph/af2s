import {bohrEnergy,bohrRadius,bohrVelocity} from './atomicModels';
export const PLANCK_EV_SECONDS=4.135667696e-15;
export function viewZoom(value:number){return Number.isFinite(value)?Math.max(.3,Math.min(3,value)):1;}
export function atomViewBox(zoom:number,pan={x:0,y:0}){const z=viewZoom(zoom);return{x:300-300/z+pan.x,y:220-220/z+pan.y,width:600/z,height:440/z};}
export function orbitRadius(n:number,maxShell:number){return 175*n/Math.max(3,maxShell);}
export function bohrWorkings(lower:number,upper:number,Z:number,current:number,emission=false){
 const from=emission?upper:lower,to=emission?lower:upper,Ei=bohrEnergy(from,Z),Ef=bohrEnergy(to,Z),delta=Ef-Ei,photon=Math.abs(delta);
 return{from,to,Ei,Ef,delta,photon,frequency:photon/PLANCK_EV_SECONDS,wavelength:1240/photon,currentEnergy:bohrEnergy(current,Z),radius:bohrRadius(current,Z),velocity:bohrVelocity(current,Z),stored:bohrEnergy(current,Z)-bohrEnergy(lower,Z)};
}

export function scientific(value:number){const [a,b]=value.toExponential(3).split('e');const superscripts:Record<string,string>={'-':'⁻','0':'⁰','1':'¹','2':'²','3':'³','4':'⁴','5':'⁵','6':'⁶','7':'⁷','8':'⁸','9':'⁹'};return a+'×10'+String(Number(b)).split('').map(c=>superscripts[c]).join('');}
