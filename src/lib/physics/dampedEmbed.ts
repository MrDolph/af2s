export const dampedEmbedDefaults={gamma:0.8,omega0:2,y0:1,yp0:0};
export function dampedEmbedSettings(search:string){
 const q=new URLSearchParams(search);
 const n=(key:keyof typeof dampedEmbedDefaults,min:number,max:number)=>{
  const text=q.get(key);const value=text?.trim()?Number(text):NaN;
  return Number.isFinite(value)?Math.max(min,Math.min(max,value)):dampedEmbedDefaults[key];
 };
 return {gamma:n('gamma',0,6),omega0:n('omega0',0.5,6),y0:n('y0',-2,2),yp0:n('yp0',-4,4)};
}
