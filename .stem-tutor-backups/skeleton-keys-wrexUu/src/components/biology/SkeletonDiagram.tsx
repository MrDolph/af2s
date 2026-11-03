'use client';
import { Fragment, type ReactNode, useId } from 'react';
import { BONES, type Bone } from '@/lib/biology/skeleton';
type Props = { selected:string|null; division:string; view:'front'|'back'; labels:boolean; interactive:boolean; onSelect:(id:string)=>void };
const line = (x1:number,y1:number,x2:number,y2:number,w=9) => <path d={`M${x1} ${y1}L${x2} ${y2}`} fill="none" strokeWidth={w} strokeLinecap="round"/>;
function pair(node:ReactNode) { return <>{node}<g transform="translate(560 0) scale(-1 1)">{node}</g></>; }
function shape(id:string,back:boolean):ReactNode {
 switch(id) {
  case 'cranium':return <path d="M242 91 C230 38 246 28 280 28 C314 28 330 49 318 91 L305 104 L255 104Z"/>;
  case 'face':return <><path d="M248 93L256 119L269 124L291 124L304 119L312 93L298 86L280 95L262 86Z"/><ellipse cx="263" cy="100" rx="8" ry="6" fill="#1e293b"/><ellipse cx="297" cy="100" rx="8" ry="6" fill="#1e293b"/><path d="M280 105L274 116L286 116Z" fill="#1e293b"/></>;
  case 'mandible':return <path d="M250 110L256 134Q280 149 304 134L310 110L301 112L296 128Q280 135 264 128L259 112Z"/>;
  case 'ossicles':return pair(<g><circle cx="239" cy="92" r="4"/><circle cx="233" cy="94" r="3"/><circle cx="229" cy="97" r="2"/></g>);
  case 'hyoid':return <path d="M269 143Q280 155 291 143L292 150Q280 162 268 150Z"/>;
  case 'vertebrae':return <>{Array.from({length:24},(_,i)=><rect key={i} x={back?272:275} y={145+i*8.5} width={back?16:10} height="7" rx="2"/>)}<path d="M265 352L295 352L288 383L280 399L272 383Z"/></>;
  case 'ribs':return <>{Array.from({length:12},(_,i)=>{const y=181+i*9,w=i<8?48+i*2:66-(i-7)*10;return <Fragment key={i}>{pair(<path d={`M276 ${y} Q${280-w-24} ${y-12} ${280-w} ${y+10} Q${280-w+5} ${y+25} 274 ${y+17}`} strokeWidth="4" fill="none"/>)}</Fragment>;})}</>;
  case 'sternum':return <path d="M270 175L290 175L287 193L285 243L280 255L275 243L273 193Z"/>;
  case 'clavicles':return pair(<path d="M275 170Q250 158 231 173Q221 180 208 177" fill="none" strokeWidth="8" strokeLinecap="round"/>);
  case 'scapulae':return pair(<path d="M218 181L257 191L241 241L213 211Z"/>);
  case 'humeri':return pair(<>{line(207,197,177,303,13)}<circle cx="207" cy="192" r="12"/><ellipse cx="177" cy="306" rx="12" ry="8"/></>);
  case 'radii':return pair(<>{line(165,321,139,420,7)}<ellipse cx="139" cy="419" rx="7" ry="5"/></>);
  case 'ulnae':return pair(<>{line(179,316,151,419,7)}<path d="M173 306L184 307L180 321L171 320Z"/></>);
  case 'carpals':return pair(<>{Array.from({length:8},(_,i)=><circle key={i} cx={134+(i%4)*5} cy={429+Math.floor(i/4)*6} r="3"/>)}</>);
  case 'metacarpals':return pair(<>{Array.from({length:5},(_,i)=>line(134+i*4,440,122+i*6,460,3))}</>);
  case 'hand-phalanges':return pair(<>{Array.from({length:5},(_,finger)=>Array.from({length:finger===0?2:3},(_,j)=>line(122+finger*6-j*1.5,464+j*7,121+finger*6-j*1.5,469+j*7,3)))}</>);
  case 'hip-bones':return pair(<path d="M269 342Q238 331 218 349L214 373L227 395L257 405L270 385L251 378L260 359Z M239 381L251 387L240 395L231 388Z" fillRule="evenodd"/>);
  case 'femora':return pair(<><circle cx="255" cy="396" r="11"/>{line(250,405,238,516,14)}<path d="M236 406L239 395L248 402Z"/><ellipse cx="238" cy="520" rx="13" ry="9"/></>);
  case 'patellae':return pair(<path d="M230 528Q238 519 246 528L244 540L238 546L232 540Z"/>);
  case 'tibiae':return pair(<>{line(241,550,239,684,11)}<path d="M230 547L251 547L247 564L236 564Z"/></>);
  case 'fibulae':return pair(<>{line(224,551,225,684,5)}<circle cx="224" cy="550" r="5"/></>);
  case 'tarsals':return pair(<>{Array.from({length:7},(_,i)=><ellipse key={i} cx={230+(i%3)*6} cy={694+Math.floor(i/3)*6} rx="4" ry="3"/>)}</>);
  case 'metatarsals':return pair(<>{Array.from({length:5},(_,i)=>line(226+i*4,711,209+i*7,732,4))}</>);
  case 'foot-phalanges':return pair(<>{Array.from({length:5},(_,toe)=>Array.from({length:toe===4?2:3},(_,j)=>line(209+toe*7-j*2,735+j*4,206+toe*7-j*2,737+j*4,3)))}</>);
  default:return null;
 }
}
function shortName(b:Bone) { return b.id==='face'?'Facial bones':b.id==='vertebrae'?'Vertebral column':b.name; }
export function SkeletonDiagram({selected,division,view,labels,interactive,onSelect}:Props) {
 const title=useId(),desc=useId();
 return <svg viewBox="0 0 560 780" role="group" aria-labelledby={`${title} ${desc}`} className="bio-skeleton">
  <title id={title}>Human skeleton — {view} view</title><desc id={desc}>Simplified adult skeleton. Select bones with touch, mouse, Enter or Space. A separate bone list provides the same controls. Tiny ear bones and the hyoid are schematic callouts.</desc>
  <rect width="560" height="780" rx="18" fill="#f8fafc"/>
  <text x="280" y="19" textAnchor="middle" fontSize="12" fill="#475569">{view==='front'?'Anterior (front)':'Posterior (back)'} · grouped teaching diagram</text>
  {BONES.filter(b=>!b.view||b.view===view).sort((a,b)=>a.id==='vertebrae'?-1:b.id==='vertebrae'?1:0).map(b=>{
   const active=division==='all'||b.division===division,chosen=selected===b.id;
   return <g key={b.id} className="bio-bone" role={interactive?'button':undefined} tabIndex={interactive&&active?0:undefined} aria-label={`${b.name}, ${b.count} bones, ${b.division}`} aria-pressed={interactive?chosen:undefined}
    onClick={()=>{if(interactive&&active)onSelect(b.id);}} onKeyDown={e=>{if(interactive&&active&&(e.key==='Enter'||e.key===' ')){e.preventDefault();onSelect(b.id);}}}
    style={{opacity:active?1:.12,cursor:interactive&&active?'pointer':'default'}}>
    <title>{b.name}</title><g fill={chosen?'#fde68a':b.division==='axial'?'#dbeafe':'#ccfbf1'} stroke={chosen?'#b45309':b.division==='axial'?'#2563eb':'#0f766e'} strokeWidth={chosen?3:1.8}>{shape(b.id,view==='back')}</g>
    {labels&&active&&<g pointerEvents="none"><path d={`M${b.anchor[0]} ${b.anchor[1]}L${b.label[0]<280?152:389} ${b.label[1]-4}`} stroke="#94a3b8" strokeWidth=".8" fill="none"/><text x={b.label[0]} y={b.label[1]} fontSize="11" fontWeight={chosen?700:500} fill="#0f172a">{shortName(b)}</text></g>}
   </g>;
  })}
 </svg>;
}
