'use client';
import { Fragment } from 'react';
import { ClassificationModel } from './ClassificationModel';
import { lessons,type LessonId } from '@/lib/biology/lessons';
type Props={topic:LessonId;step:number;plant:boolean;crossing:boolean;orientation:boolean;index:number;phase:number;onSelect:(n:number)=>void;interactive:boolean;labels:boolean;primary?:number;comparison?:number};
export function BiologyModel({topic,step,plant,crossing,orientation,index,phase,onSelect,interactive,labels,primary,comparison}:Props){
 const lesson=lessons[topic];
 if(topic==='classification')return <ClassificationModel primary={primary} comparison={comparison} step={step} answers={labels}/>;
 if(topic==='life-processes')return <div className="bio-process-grid">{lesson.steps.map((s,i)=><button key={s.name} className="bio-button" aria-pressed={i===step} disabled={!interactive} onClick={()=>onSelect(i)}><span className="block text-xl" aria-hidden="true">{['↔','⚡','☀','◉','↗','↪','✧','⌛','⇄','🌿'][i]}</span>{s.name}</button>)}</div>;
 return <svg className="bio-model-svg" viewBox="0 0 800 460" role={topic==='cells'&&interactive?'group':'img'} aria-label={`${lesson.title}: ${lesson.steps[step].name}`}>
 <title>{`${lesson.title}: ${lesson.steps[step].name}`}</title><rect width="800" height="460" rx="20" fill="#f0fdfa"/>
 {topic==='cells'?<>
 {plant?<rect x="70" y="35" width="660" height="385" rx="45" fill="#dcfce7" stroke="#15803d" strokeWidth="12"/>:<ellipse cx="400" cy="225" rx="330" ry="190" fill="#fef3c7" stroke="#0f766e" strokeWidth="5"/>}
 {plant&&<rect x="82" y="47" width="636" height="361" rx="37" fill="none" stroke="#0f766e" strokeWidth="4"/>}
 {lesson.steps.map((s,i)=>{if(!plant&&i>=5)return null;const [x,y]=[[115,220],[210,125],[300,250],[545,125],[560,340],[680,225],[600,235],[445,270]][i];return <g key={s.name} role={interactive?'button':undefined} tabIndex={interactive?0:undefined} aria-label={s.name} aria-pressed={i===step} onClick={()=>interactive&&onSelect(i)} onKeyDown={e=>{if(interactive&&(e.key==='Enter'||e.key===' ')){e.preventDefault();onSelect(i);}}} className="bio-hotspot" style={{cursor:interactive?'pointer':undefined}}>
 <ellipse cx={x} cy={y} rx={i===2?63:i===7?70:38} ry={i===2?58:i===7?92:28} fill={['#99f6e4','#fde68a','#c4b5fd','#fdba74','#cbd5e1','#86efac','#4ade80','#bae6fd'][i]} stroke={i===step?'#b45309':'#334155'} strokeWidth={i===step?5:2}/>
 {i===3&&<path d={`M${x-22} ${y}q10 -20 20 0t20 0`} fill="none" stroke="#9a3412" strokeWidth="3"/>}{i===4&&[0,1,2,3].map(n=><circle key={n} cx={x-18+n*12} cy={y} r="5" fill="#475569"/>)}
 {labels&&<text x={x} y={y+6} textAnchor="middle" fontSize="16" fill="#0f172a" fontWeight="600">{s.name}</text>}</g>;})}<text x="400" y="445" textAnchor="middle" fontSize="17">{plant?'Photosynthetic plant cell':'Typical animal cell'} · selected structures, not to scale</text>
 </>:topic==='transpiration'?<>
 <path d="M400 390V155M400 240L285 175M400 275L525 195" stroke="#166534" strokeWidth="20" fill="none"/>
 <ellipse cx="280" cy="160" rx="95" ry="45" transform="rotate(25 280 160)" fill="#86efac" stroke="#15803d" strokeWidth="3"/><ellipse cx="525" cy="180" rx="100" ry="47" transform="rotate(-25 525 180)" fill="#86efac" stroke="#15803d" strokeWidth="3"/>
 <path d="M400 390L325 435M400 390L460 435M400 400V445" stroke="#92400e" strokeWidth="7"/><path d="M110 395H690" stroke="#92400e" strokeWidth="3"/>
 {Array.from({length:12},(_,i)=>{const t=(i/12+phase*index/100)%1;return <circle key={i} cx={400} cy={385-t*205} r="5" fill="#0284c7" opacity={index>0?0.85:0}/>;})}
 {Array.from({length:6},(_,i)=><circle key={i} cx={560+((phase+i/6)%1)*90} cy={130-((phase+i/6)%1)*85} r="5" fill="#0284c7" opacity={index>0?Math.min(1,index/30):0}/>)}
 <text x="110" y="370" fontSize="20">Roots → xylem → leaf → air</text><text x="470" y="75" fontSize="20">Water vapour</text><text x="80" y="40" fontSize="20">Relative index: {index.toFixed(1)}</text><text x="80" y="450" fontSize="16">Blue dots illustrate flow; they are not counted water molecules.</text>
 </>:<Division topic={topic as 'mitosis'|'meiosis'} step={step} crossing={crossing} orientation={orientation}/>}
 </svg>;
}
function Division({topic,step,crossing,orientation}:{topic:'mitosis'|'meiosis';step:number;crossing:boolean;orientation:boolean}){
 const mei=topic==='meiosis',replicated=step>0,firstSplit=mei&&step>=5,finished=mei?step===8:step===5,anaphase=mei?(step===4||step===7):step===4;
 const cells=finished?(mei?4:2):firstSplit?2:1;
 const centres=cells===1?[[400,225]]:cells===2?[[215,225],[585,225]]:[[200,120],[600,120],[200,340],[600,340]];
 const colour=(h:number)=>h?'#c2410c':'#1d4ed8';
 function chromosome(x:number,y:number,pair:number,h:number,single:boolean,recombined:boolean,key:string){const length=pair===0?48:30;return <g key={key} data-chromosome data-chromatids={single?1:2} transform={`translate(${x} ${y})`} stroke={colour(h)} strokeWidth="7" strokeLinecap="round">
 {single?<path d={`M0 ${-length/2}V${length/2}`}/>:<><path d={`M-9 ${-length/2}L9 ${length/2}`}/><path d={`M9 ${-length/2}L-9 ${length/2}`}/></>}
 {recombined&&<path d={single?`M0 ${length/2-10}V${length/2}`:`M5 ${length/2-10}L9 ${length/2}`} stroke={colour(1-h)}/>}<circle r="3" fill="#111827" stroke="none"/></g>;}
 return <>
 {centres.map(([cx,cy],cell)=>{const radius=cells===4?96:cells===2?155:185;const haploid=mei&&(firstSplit||finished);const members=haploid||(mei&&step===4)?2:4;
 return <Fragment key={cell}><ellipse cx={cx} cy={cy} rx={radius} ry={cells===4?90:radius} fill="#fff" stroke="#0f766e" strokeWidth="3"/>
 {Array.from({length:members},(_,i)=>{const pair=haploid||(mei&&step===4)?i:Math.floor(i/2);let h=haploid?(cell%2):i%2;if(mei&&pair===1&&orientation)h=1-h;
 const align=mei?(step===3||step===6):step===3;
 const x=cx+(align?(haploid?0:(i%2?18:-18)):haploid?(i?30:-30):(i%2?45:-45));const y=cy+(pair?36:-36);
 const single=!replicated||finished;
 if(anaphase){return <Fragment key={i}>{[-1,1].map((pole,j)=>chromosome(cx+pole*radius*0.55+(!mei?(h?10:-10):0),y,pair,mei&&step===4?(pair===1&&orientation?1-j:j):h,mei&&step===4?false:true,mei&&crossing&&step>=2&&pair===0&&(j===1),`${i}-${j}`))}</Fragment>;}
 return chromosome(x,y,pair,h,single,mei&&crossing&&step>=2&&pair===0&&(finished?cell>=2:true),String(i));})}
 {labelsForCell(mei,step,cell,cx,cy,radius)}
 </Fragment>;})}
 <text x="400" y="25" textAnchor="middle" fontSize="18">Long + short chromosomes · blue/coral parental origins</text>
 </>;
}
function labelsForCell(mei:boolean,step:number,cell:number,x:number,y:number,r:number){const text=mei?(step===8?'n = 2 · 2 DNA molecules':step>=5?'n = 2 · 4 DNA molecules':step===0?'2n = 4 · 4 DNA molecules':step===4?'Each pole: n = 2, replicated':'2n = 4 · 8 DNA molecules'):(step===0||step===5?'2n = 4 · 4 DNA molecules':step===4?'Each pole: 4 chromosomes':'2n = 4 · 8 DNA molecules');return <text x={x} y={y+r-15} textAnchor="middle" fontSize={r<100?13:16} fill="#0f172a">{text}</text>;}
