export function gradientCoordinate(value:number){return Math.round(Math.max(-3,Math.min(3,value))*10000)/10000;}
export function gradientAngle(value:number){return (Math.round(((value%360+360)%360)*100)/100)%360;}
export function gradientNumber(value:number,digits=4){return (Number(value.toFixed(digits))===0?0:value).toFixed(digits);}
export function unitDirection(angle:number){const r=angle*Math.PI/180;return{x:Math.cos(r),y:Math.sin(r)};}
export function gradientSubstitution(fieldIndex:number,x:number,y:number,value:number){
 const a=`(${gradientNumber(x)})`,b=`(${gradientNumber(y)})`;
 const expression=[`${a}² + ${b}²`,`${a}² − ${b}²`,`${a}² + 4 × ${b}²`,`${a} × ${b}`][fieldIndex];
 return `φ = ${expression} = ${gradientNumber(value,8)}`;
}
