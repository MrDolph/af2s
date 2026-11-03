'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { SimulationStage } from '@/components/simulation/SimulationStage';
import { EmbedButton } from '@/components/ui/EmbedButton';
import { ReadAloud } from '@/components/accessibility/ReadAloud';
import { isLanguage, type Language } from '@/lib/explorer/catalog';
import { languageNames } from '@/lib/explorer/locales';
import { useTopicPreset } from '@/lib/explorer/use-topic-preset';
import { BONES, EXERCISES, SOURCES, challengeBone, type Bone } from '@/lib/biology/skeleton';
import { biologyText } from '@/lib/biology/languages';
import { SkeletonDiagram } from './SkeletonDiagram';
import './biology.css';
type Task='explore'|'identify'|'classify';
export function SkeletalActivity({embed=false}:{embed?:boolean}) {
 const [view,setView]=useState<'front'|'back'>('front'),[division,setDivision]=useState('all'),[labels,setLabels]=useState(true),[selected,setSelected]=useState(0);
 const [task,setTask]=useState<Task>('explore'),[language,setLanguage]=useState<Language>('en'),[controls,setControls]=useState(true),[zoom,setZoom]=useState(100);
 const [question,setQuestion]=useState(0),[answered,setAnswered]=useState(false),[revealed,setRevealed]=useState(false),[feedback,setFeedback]=useState(''),[score,setScore]=useState({correct:0,total:0});
 const [tab,setTab]=useState<'student'|'teacher'>('student');
 const bone=BONES[selected],target=challengeBone(question),text=biologyText[language];
 function selectBone(id:string) {
  const i=BONES.findIndex(b=>b.id===id);if(i<0)return;
  if(task==='identify'){answer(id===target.id);return;}
  setSelected(i);const b=BONES[i];if(b.view)setView(b.view);
 }
 function answer(correct:boolean) {
  if(answered)return;setAnswered(true);setScore(s=>({correct:s.correct+(correct?1:0),total:s.total+1}));
  setFeedback(correct?'Correct. Explain the location or function to a partner.':'Not quite. Use Reveal to review the answer, then try the next challenge.');
 }
 function startTask(value:Task){setTask(value);setQuestion(0);setAnswered(false);setRevealed(false);setFeedback('');if(value!=='explore'){setDivision('all');}if(value!=='explore'){const t=challengeBone(0);setView(t.view||'front');}}
 function next(){const t=challengeBone(question+1);setQuestion(q=>q+1);setAnswered(false);setRevealed(false);setFeedback('');setView(t.view||'front');}
 function reveal(){setRevealed(true);if(!answered){setAnswered(true);setScore(s=>({...s,total:s.total+1}));}setFeedback(`Answer: ${target.name} — ${target.division}. ${target.function}`);}
 function reset(){setView('front');setDivision('all');setLabels(true);setSelected(0);setZoom(100);setTask('explore');setQuestion(0);setAnswered(false);setRevealed(false);setFeedback('');setScore({correct:0,total:0});}
 useEffect(()=>{
  const q=new URLSearchParams(window.location.search);
  const v=q.get('view');if(v==='front'||v==='back')setView(v);
  const d=q.get('division');if(d&&['all','axial','appendicular'].includes(d))setDivision(d);
  if(q.get('labels')==='0')setLabels(false);
  const index=Number(q.get('bone'));if(q.has('bone')&&Number.isInteger(index)&&index>=0&&index<BONES.length){setSelected(index);if(BONES[index].view)setView(BONES[index].view!);}
  const t=q.get('task');if(t==='identify'||t==='classify')startTask(t);
  if(embed&&q.get('controls')==='0'){setControls(false);setTask('explore');}
  try{const saved=q.get('afLang')||q.get('lang')||localStorage.getItem('afactor-simulation-language-v1');if(isLanguage(saved))setLanguage(saved);}catch{}
 },[embed]);
 useTopicPreset('biology-skeletal-system',{boneIndex:v=>{const n=Math.max(0,Math.min(BONES.length-1,Math.trunc(v)));setSelected(n);}}, {
  view:v=>setView(v as 'front'|'back'),division:setDivision,labels:v=>setLabels(v==='on'),activity:v=>startTask(v as Task),
 });
 function changeLanguage(value:Language){setLanguage(value);try{localStorage.setItem('afactor-simulation-language-v1',value);}catch{}}
 const challenge=task!=='explore',shown:Bone=challenge?target:bone;
 const heading=task==='identify'?`Find and select: ${target.name}`:task==='classify'?`Classify: ${target.name}`:bone.name;
 const showAnswer=!challenge||revealed||task==='classify';
 return <div className="bio-page" style={{colorScheme:'light'}}>
  {!embed&&<AppHeader/>}
  <main className={embed?'bio-embed':'mx-auto max-w-7xl px-3 py-6 sm:px-6'}>
   {!embed&&<><Link href="/biology" className="text-sm text-teal-800 underline">← Biology</Link><h1 className="mt-2 text-2xl font-semibold">{text.title}</h1><p className="my-3 max-w-3xl text-sm leading-7">{text.instruction}</p></>}
   <SimulationStage className={`af-biology-stage ${embed?'af-embed-stage':''} space-y-3`}>
    <div data-stage-role="canvas" className="bio-scene">
     <div className="bio-figure"><div className="bio-zoom" style={{height:`${zoom}%`}}><SkeletonDiagram selected={challenge?(revealed||task==='classify'?target.id:null):bone.id} division={challenge?'all':division} view={view} labels={challenge?revealed:labels} interactive={controls&&(task==='explore'||(task==='identify'&&!answered))} onSelect={selectBone}/></div></div>
     <aside className="bio-info" lang="en">
      <p className="text-xs font-semibold uppercase tracking-wider text-teal-700">{challenge?'Student challenge':'Selected bone or group'}</p>
      <h2 className="my-2 text-lg font-semibold">{heading}</h2>
      {showAnswer&&<><p className="my-2 text-sm"><strong>{shown.count}</strong> {shown.count===1?'bone':'bones'} · <strong>{task==='classify'&&!revealed?'Choose a division below':shown.division}</strong></p>
       <p className="text-sm leading-6">{shown.location}</p><p className="mt-2 text-sm leading-6">{shown.function}</p>
       {!challenge&&<ReadAloud text={`${bone.name}. ${bone.location} ${bone.function}`} language="en"/>}</>}
      {controls&&task==='classify'&&<div className="mt-3 flex flex-wrap gap-2">{(['axial','appendicular'] as const).map(d=><button className="bio-button" key={d} disabled={answered} onClick={()=>answer(d===target.division)}>{d}</button>)}</div>}
      {task==='identify'&&!answered&&<p className="text-sm leading-6">Labels are hidden. Tap the named group on the diagram, or use the accessible bone list.</p>}
      {challenge&&<><p className="mt-3 text-sm font-medium">Score: {score.correct}/{score.total} first attempts</p><p role="status" className="mt-2 text-sm leading-6">{feedback}</p></>}
      <p className="mt-4 text-xs leading-5 text-gray-600">Typical adult count: 206 (80 axial + 126 appendicular). This schematic groups bones; it does not show all 206 separately. Some internal bones are callouts.</p>
     </aside>
    </div>
    {controls&&<div data-stage-role="parameters" className="bio-controls">
     <label>Activity<select value={task} onChange={e=>startTask(e.target.value as Task)}><option value="explore">Explore bones</option><option value="identify">Identify a bone</option><option value="classify">Axial or appendicular?</option></select></label>
     <label>Bone / group<select value={task==='identify'?'':String(selected)} disabled={task==='classify'||(task==='identify'&&answered)} onChange={e=>{if(e.target.value)selectBone(BONES[Number(e.target.value)].id);}}>{task==='identify'&&<option value="">Choose a bone…</option>}{BONES.map((b,i)=><option key={b.id} value={String(i)}>{b.name}</option>)}</select></label>
     <label>View<select value={view} disabled={challenge} onChange={e=>setView(e.target.value as 'front'|'back')}><option value="front">Front</option><option value="back">Back</option></select></label>
     <label>Division<select disabled={challenge} value={division} onChange={e=>setDivision(e.target.value)}><option value="all">All bones</option><option value="axial">Axial · 80 bones</option><option value="appendicular">Appendicular · 126 bones</option></select></label>
     <label>Labels<input type="checkbox" checked={labels} disabled={challenge} onChange={e=>setLabels(e.target.checked)}/></label>
     <label>{text.language}<select value={language} onChange={e=>changeLanguage(e.target.value as Language)}>{Object.entries(languageNames).map(([id,name])=><option key={id} value={id}>{name}</option>)}</select></label>
     <label>Diagram zoom {zoom}%<input type="range" min={75} max={160} step={5} value={zoom} onChange={e=>setZoom(Number(e.target.value))}/></label>
    </div>}
    {controls&&<div data-stage-role="playback" className="flex flex-wrap gap-2">
     {challenge&&<><button className="bio-button" onClick={reveal} disabled={revealed}>Reveal answer</button><button className="bio-button" onClick={next}>Next challenge</button></>}
     <button className="bio-button" onClick={reset}>Reset activity</button>
     {!embed&&<EmbedButton path="/embed/skeletal-system" title="Human skeletal system — A-Factor STEM Studio" width={900} height={720} params={{bone:selected,view,division,labels:labels?1:0,task,lang:language}}/>}
    </div>}
    <div data-stage-role="extra" className="bio-card"><h2 className="font-semibold">Accessible bone list</h2><p className="my-2 text-xs text-gray-600">The same selections as the diagram; useful on small screens and with a keyboard.</p><div className="grid grid-cols-2 gap-2 sm:grid-cols-3 lg:grid-cols-4">{BONES.filter(b=>challenge||division==='all'||b.division===division).map(b=><button key={b.id} className="bio-button text-left" disabled={!controls||task==='classify'||(task==='identify'&&answered)} onClick={()=>selectBone(b.id)} aria-pressed={!challenge&&bone.id===b.id}>{b.name}</button>)}</div></div>
   </SimulationStage>
   <section className="bio-card mt-4" lang={language}><h2 className="font-semibold">{text.title}</h2><p className="my-2 text-sm leading-7">{text.overview}</p><ReadAloud text={text.overview} language={language}/><p className="text-xs leading-6 text-gray-600" lang="en">Bone names, quizzes and detailed notes remain in English. Local-language overviews are draft teaching content for fluent-teacher review.</p></section>
   {!embed&&<section className="mt-5" lang="en">
    <div role="group" aria-label="Learning sections" className="mb-3 flex gap-2"><button className="bio-button" aria-pressed={tab==='student'} onClick={()=>setTab('student')}>Student activities</button><button className="bio-button" aria-pressed={tab==='teacher'} onClick={()=>setTab('teacher')}>Teacher guide</button></div>
    {tab==='teacher'?<TeacherGuide onChallenge={startTask}/>:<div className="bio-card"><h2 className="text-lg font-semibold">Explore → explain → practise</h2><ol className="my-3 list-decimal space-y-2 pl-5 text-sm leading-6"><li>Select a bone and tell a partner where it is before revealing its function.</li><li>Compare front and back views. Find the sternum in front and the scapulae at the back.</li><li>Filter by division, then complete five identification and five classification challenges.</li><li>Explain one answer aloud. Your partner checks the diagram and the notes.</li></ol><h3 className="mt-4 font-semibold">Worked example</h3><p className="my-2 text-sm leading-6">Question: is the femur axial or appendicular? It lies in the thigh, which is part of a limb. Limb bones belong to the appendicular skeleton, so the femur is appendicular.</p><h3 className="mt-4 font-semibold">Classwork and assignments</h3>{EXERCISES.map((e,i)=><details key={e.q} className="my-2 rounded-xl border border-gray-200 p-3"><summary className="cursor-pointer text-sm font-medium">{i+1}. {e.q}</summary><p className="mt-3 text-sm leading-6">{e.a}</p></details>)}</div>}
   </section>}
   <footer className="my-5 text-xs leading-6 text-gray-600" lang="en"><p>Original schematic illustration; educational overview, not a diagnostic or surgical model. Challenges are local practice, not a secure assessment or a shared live session.</p><p>Reference reading: {SOURCES.map(([label,url])=><a key={url} className="mr-3 underline" href={url} target="_blank" rel="noreferrer">OpenStax · {label}</a>)}</p>{embed&&<Link className="underline" href="/biology/skeletal-system" target="_blank">Open the full lesson · A-Factor STEM Studio</Link>}</footer>
  </main>
 </div>;
}
function TeacherGuide({onChallenge}:{onChallenge:(task:Task)=>void}) {
 return <div className="bio-card"><h2 className="text-lg font-semibold">Teacher guide · suggested 35-minute lesson</h2><h3 className="mt-3 font-semibold">Learning objectives</h3><ul className="my-2 list-disc space-y-1 pl-5 text-sm leading-6"><li>Locate major bones and distinguish axial from appendicular regions.</li><li>Relate a bone’s position to a supporting, protective or movement role.</li><li>Explain why a selected bone group is not always one individual bone.</li></ul><h3 className="mt-3 font-semibold">Demonstration and interaction</h3><ol className="my-2 list-decimal space-y-2 pl-5 text-sm leading-6"><li><strong>0–5 min:</strong> ask learners to name three bones. Collect predictions before showing labels.</li><li><strong>5–15 min:</strong> expand classroom view, compare front/back, and switch divisions. Ask “Why is the sacrum axial but a hip bone appendicular?”</li><li><strong>15–25 min:</strong> hide labels. Invite one learner to select a named bone; classmates justify or correct the choice. Rotate who answers and who explains.</li><li><strong>25–30 min:</strong> pairs alternate identification and classification challenges. Record first attempts on paper if needed.</li><li><strong>30–35 min:</strong> exit ticket: name one protective bone, one limb bone and their divisions.</li></ol><div className="my-3 flex flex-wrap gap-2"><button className="bio-button" onClick={()=>onChallenge('identify')}>Start identification challenge</button><button className="bio-button" onClick={()=>onChallenge('classify')}>Start classification challenge</button></div><h3 className="mt-3 font-semibold">Misconceptions and differentiation</h3><p className="my-2 text-sm leading-6">Paired or grouped regions are not single bones. A bone does not contract like a muscle. Use the bone list and read-aloud controls for learners who need alternatives to the diagram. For extension, ask pupils to explain movement using bones, joints and muscles.</p><p className="text-xs leading-6 text-gray-600">These activities support interaction around a shared screen. No learner accounts, microphone recording, remote classroom synchronization or student data collection are added.</p></div>;
}
