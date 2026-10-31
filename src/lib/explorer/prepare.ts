import { getTopic, isLanguage, normalize, topics, type Language, type Topic } from './catalog';
import { conceptExplanation, ui } from './locales';
export class ExplorerError extends Error { constructor(message:string, public status=422) { super(message); } }
export type ExplorerResult = { topicId:string; title:string; route:string; language:Language; params:Record<string,number>; modes:Record<string,string>; requested:string[]; explanation:string; calculation:string|null; url:string; mode:'demo' };
const aliasOverrides: Record<string,Record<string,string[]>> = {
 'mathematics-unit-circle': {angleDeg:['angle']},
 'simulations-ohms-law': {V:['voltage','supply voltage'],r1:['resistance','r','resistor']},
 'simulations-newtons-laws': {mass2:['mass'],applied:['force','applied force'],friction2:['friction','mu']},
 'simulations-projectile-motion': {v0:['speed','velocity','initial speed','initial velocity'],angle:['launch angle','igun','kusurwa','nkuku'],g:['gravity'],h0:['height']},
 'simulations-waves': {f:['frequency'],lambda:['wavelength'],A:['amplitude']},
 'simulations-radioactive-decay': {n0:['initial population'],halfLife:['half life']},
};
const units:Record<string,Record<string,string>>={
 'mathematics-unit-circle':{angleDeg:'°|degrees?'},
 'simulations-ohms-law':{V:'V',r1:'Ω|ohms?'},'simulations-newtons-laws':{mass2:'kg',applied:'N'},
 'simulations-projectile-motion':{g:'m/s²|m/s\\^2',v0:'m/s',angle:'°|degrees?'},
 'simulations-waves':{f:'Hz',lambda:'m'},'simulations-polarization':{polarizerAngle:'°|degrees?'},
};
function escape(s:string) { return s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'); }
export function detectTopic(prompt:string):Topic|undefined {
 const s=' '+normalize(prompt)+' ';
 const matches=topics.flatMap(topic=>topic.aliases.filter(a=>s.includes(' '+normalize(a)+' ')).map(a=>({topic,score:normalize(a).length})));
 matches.sort((a,b)=>b.score-a.score);
 return matches[0]?.topic;
}
export function validateSettings(topic:Topic, raw:unknown, rawModes:unknown) {
 const params:Record<string,number>={}, modes:Record<string,string>={};
 if(!raw || typeof raw!=='object' || Array.isArray(raw)) throw new ExplorerError('Invalid settings.');
 for(const [key,value] of Object.entries(raw)) {const p=topic.parameters.find(p=>p.key===key);if(!p||typeof value!=='number'||!Number.isFinite(value)||value<p.min||value>p.max||(p.integer&&!Number.isInteger(value)))throw new ExplorerError(`${key}: ${p?`${p.min}–${p.max} ${p.unit}`:'unsupported parameter'}`);params[key]=value;}
 if(!rawModes||typeof rawModes!=='object'||Array.isArray(rawModes))throw new ExplorerError('Invalid mode.');
 for(const [key,value] of Object.entries(rawModes)) {const m=topic.modes.find(m=>m.key===key);if(!m||typeof value!=='string'||!m.options.includes(value))throw new ExplorerError('Unsupported mode: '+key);modes[key]=value;}
 return {params,modes};
}
export function calculate(topic:Topic,p:Record<string,number>,m:Record<string,string>):string|null {
 const n=(x:number)=>Number(x.toPrecision(5));
 if(topic.id==='mathematics-unit-circle'){const r=p.angleDeg*Math.PI/180;return `sin ${p.angleDeg}° = ${n(Math.sin(r))}; cos ${p.angleDeg}° = ${n(Math.cos(r))}. Angle measured anticlockwise from positive x-axis.`;}
 if(topic.id==='simulations-ohms-law') {const R=m.mode==='series'?p.r1+p.r2+p.r3:m.mode==='parallel'?1/(1/p.r1+1/p.r2+1/p.r3):p.r1;if(m.mode==='non-ohmic')return null;return `I = V/R = ${p.V}/${n(R)} = ${n(p.V/R)} A; P = VI = ${n(p.V*p.V/R)} W. Ohmic resistors at fixed physical conditions.`;}
 if(topic.id==='simulations-newtons-laws'&&m.law==='2nd') {const friction=p.friction2*p.mass2*9.81;return `a = max(0, F − μmg)/m = ${n(Math.max(0,p.applied-friction)/p.mass2)} m/s². Block initially at rest on a horizontal surface; g = 9.81 m/s²; simplified friction model.`;}
 if(topic.id==='simulations-waves'&&m.mode!=='standing'&&m.mode!=='superposition')return `v = fλ = ${p.f} × ${p.lambda} = ${n(p.f*p.lambda)} m/s; T = 1/f = ${n(1/p.f)} s.`;
 if(topic.id==='simulations-projectile-motion'&&m.mode==='standard'){const r=p.angle*Math.PI/180,vy=p.v0*Math.sin(r),time=(vy+Math.sqrt(vy*vy+2*p.g*p.h0))/p.g;return `T = ${n(time)} s; horizontal range = ${n(p.v0*Math.cos(r)*time)} m. Standard launch from h₀ = ${p.h0} m; no air resistance; landing at y = 0.`;}
 return null;
}
export function prepare(input:{prompt?:unknown;topicId?:unknown;language?:unknown;params?:unknown;modes?:unknown}):ExplorerResult {
 const language=isLanguage(input.language)?input.language:'en';
 if(input.language!==undefined&&!isLanguage(input.language))throw new ExplorerError('Unsupported language.',400);
 if(input.prompt!==undefined&&typeof input.prompt!=='string')throw new ExplorerError('Invalid prompt.',400);
 const prompt=typeof input.prompt==='string'?input.prompt.trim():'';
 if(prompt.length>1200)throw new ExplorerError('Prompt too long.',400);
 const topic=typeof input.topicId==='string'&&input.topicId?getTopic(input.topicId):detectTopic(prompt);
 if(!topic)throw new ExplorerError(ui[language].noMatch);
 const params:Record<string,number>=Object.fromEntries(topic.parameters.map(p=>[p.key,p.default]));
 const modes:Record<string,string>=Object.fromEntries(topic.modes.map(m=>[m.key,m.default]));
 const provided=validateSettings(topic,input.params??{},input.modes??{});Object.assign(params,provided.params);Object.assign(modes,provided.modes);
 if(topic.id==='simulations-newtons-laws'&&!provided.modes.law) {
  if (/\b(first|1st)\b/i.test(prompt)) modes.law='1st';
  else if (/\b(third|3rd)\b/i.test(prompt)) modes.law='3rd';
  else if (/\b(second|2nd)\b/i.test(prompt)||/\d/.test(prompt)) modes.law='2nd';
 }
 for(const mode of topic.modes) {
  const pattern=new RegExp('(?:^|[\\s,;])'+escape(mode.key)+'\\s*=\\s*([a-z0-9-]+)','gi');
  const explicit=[...prompt.matchAll(pattern)];
  if(explicit.length>1||(explicit.length&&provided.modes[mode.key]))throw new ExplorerError('Repeated mode: '+mode.key);
  if(explicit.length){const value=explicit[0][1];if(!mode.options.includes(value))throw new ExplorerError('Unsupported mode: '+value);modes[mode.key]=value;}
  else if(!provided.modes[mode.key]) {const text=' '+normalize(prompt)+' ';const matches=mode.options.filter(value=>text.includes(' '+normalize(value)+' '));if(matches.length===1)modes[mode.key]=matches[0];}
 }
 const effectiveLaw=typeof provided.modes.law==='string'?provided.modes.law:(/law\s*=\s*(1st|2nd|3rd)/i.exec(prompt)?.[1]||modes.law);
 const newtonAliases=effectiveLaw==='1st'?{mass1:['mass'],force1:['force'],friction1:['friction','mu']}:effectiveLaw==='3rd'?{mass3a:['mass'],force3:['force']}:aliasOverrides[topic.id];
 const aliases=topic.id==='simulations-newtons-laws'?newtonAliases:(topic.id==='simulations-projectile-motion'&&modes.mode!=='standard'?{}:aliasOverrides[topic.id]);
 const unitMap=topic.id==='simulations-projectile-motion'&&modes.mode!=='standard'?{}:topic.id==='simulations-newtons-laws'?(effectiveLaw==='1st'?{mass1:'kg',force1:'N'}:effectiveLaw==='3rd'?{mass3a:'kg',force3:'N'}:units[topic.id]):units[topic.id];
const requested=new Set(Object.keys(provided.params));
 let remaining=prompt.normalize('NFC');
 const number='([-+]?(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:e[-+]?\\d+)?)';
 // Exact key=value assignments work for every registered numeric control.
 for(const p of [...topic.parameters].sort((a,b)=>b.key.length-a.key.length)) {
  const names=[p.key,...((aliases as Record<string,string[]>|undefined)?.[p.key]||[])];
  const expression=new RegExp('(?:^|[\\s,;])(?:'+names.map(escape).join('|')+')\\s*(?:=|:)\\s*'+number+'(?![\\d.])','gi');
  remaining=remaining.replace(expression,(whole,value:string)=>{if(requested.has(p.key))throw new ExplorerError('Repeated setting: '+p.key);const checked=validateSettings(topic,{[p.key]:Number(value)},{});params[p.key]=checked.params[p.key];requested.add(p.key);return ' '.repeat(whole.length);});
 }
 for(const mode of topic.modes){const expr=new RegExp('(?:^|[\\s,;])'+escape(mode.key)+'\\s*=\\s*([a-z0-9-]+)','gi');remaining=remaining.replace(expr,(whole,value:string)=>{if(!mode.options.includes(value))throw new ExplorerError('Unsupported mode: '+value);modes[mode.key]=value;return ' '.repeat(whole.length);});}
 for(const [key,unit] of Object.entries(unitMap||{})) {
  const expr=new RegExp('(?<![a-z0-9.])'+number+'\\s*(?:'+unit+')(?![a-z0-9²^])','gi');
  remaining=remaining.replace(expr,(whole,value:string)=>{if(requested.has(key))throw new ExplorerError('Repeated setting: '+key);const checked=validateSettings(topic,{[key]:Number(value)},{});params[key]=checked.params[key];requested.add(key);return ' '.repeat(whole.length);});
 }
 // Remove topic identifiers before detecting unparsed numbers in scientific names.
 for(const alias of [...topic.aliases,topic.id].sort((a,b)=>b.length-a.length))remaining=remaining.replace(new RegExp(escape(alias),'gi'),' ');
 if(topic.id==='simulations-newtons-laws')remaining=remaining.replace(/\b(first|second|third|1st|2nd|3rd)\b/gi,' ');
 if(/\d/.test(remaining))throw new ExplorerError(ui[language].invalid);

 const query=new URLSearchParams({afTopic:topic.id,afLang:language,afParams:JSON.stringify(params),afModes:JSON.stringify(modes)});
 return {topicId:topic.id,title:topic.title,route:topic.route,language,params,modes,requested:[...requested],explanation:conceptExplanation(topic.concept,language,topic.description),calculation:calculate(topic,params,modes),url:topic.route+'?'+query.toString(),mode:'demo'};
}
export function presetFromSearch(id:string,search:string) {
 const topic=getTopic(id);if(!topic)return null;const q=new URLSearchParams(search);if(q.get('afTopic')!==id)return null;
 try {const raw=q.get('afParams')||'{}',m=q.get('afModes')||'{}';if(raw.length>12000||m.length>2000)return null;return validateSettings(topic,JSON.parse(raw),JSON.parse(m));}catch{return null;}
}
