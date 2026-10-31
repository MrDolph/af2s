'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { createPortal } from 'react-dom';
import { usePathname } from 'next/navigation';
import { topics, isLanguage, type Language } from '@/lib/explorer/catalog';
import { prepare, presetFromSearch, type ExplorerResult } from '@/lib/explorer/prepare';
import { languageNames, ui } from '@/lib/explorer/locales';
import { ResultCard } from './ResultCard';
const labels={en:{open:'AI explainer',close:'Close explainer'},yo:{open:'Olùṣàlàyé AI',close:'Pa àlàyé dé'},ha:{open:'Mai bayanin AI',close:'Rufe bayani'},ig:{open:'Onye nkọwa AI',close:'Mechie nkọwa'}};
export function TopicContext(){
 const pathname=usePathname(),titleId=useId(),noticeId=useId(),dialogId=useId();
 const [result,setResult]=useState<ExplorerResult|null>(null),[open,setOpen]=useState(false);
 const dialogRef=useRef<HTMLDialogElement>(null);
 const visible=!!result&&result.route===pathname;
 useEffect(()=>{
  setResult(null);setOpen(false);
  const topic=topics.find(t=>t.route===pathname);if(!topic)return;
  const q=new URLSearchParams(window.location.search);let language:Language='en';
  try{const l=q.get('afLang')||localStorage.getItem('afactor-simulation-language-v1');if(isLanguage(l))language=l;}catch{}
  const preset=presetFromSearch(topic.id,window.location.search);
  try{setResult(prepare({topicId:topic.id,language,params:preset?.params||{},modes:preset?.modes||{}}));}catch{}
 },[pathname]);
 useEffect(()=>{
  const dialog=dialogRef.current;if(!dialog)return;
  if(!open||!visible){if(dialog.open)dialog.close();return;}
  const oldBodyOverflow=document.body.style.overflow,oldHtmlOverflow=document.documentElement.style.overflow;
  if(!dialog.open)dialog.showModal();
  document.body.style.overflow='hidden';document.documentElement.style.overflow='hidden';
  return()=>{if(dialog.open)dialog.close();document.body.style.overflow=oldBodyOverflow;document.documentElement.style.overflow=oldHtmlOverflow;};
 },[open,visible]);
 if(!result||!visible)return null;
 const s=ui[result.language],text=labels[result.language];
 return <>
  <button type="button" aria-haspopup="dialog" aria-controls={dialogId} aria-expanded={open} onClick={()=>setOpen(true)} className="af-explainer-launcher fixed z-[60] inline-flex min-h-12 max-w-[calc(100vw-2rem)] items-center justify-center gap-2 rounded-full bg-indigo-700 px-5 py-3 text-sm font-semibold text-white shadow-lg hover:bg-indigo-800 focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-indigo-700" style={{right:'max(1rem, env(safe-area-inset-right))',bottom:'max(1rem, env(safe-area-inset-bottom))'}}><span aria-hidden="true">✦</span>{text.open}</button>
  {createPortal(<dialog id={dialogId} ref={dialogRef} aria-labelledby={titleId} aria-describedby={noticeId} className="af-explainer-modal af-explorer" onCancel={event=>{event.preventDefault();setOpen(false);}} onClick={event=>{if(event.target!==event.currentTarget)return;const box=event.currentTarget.getBoundingClientRect();if(event.clientX<box.left||event.clientX>box.right||event.clientY<box.top||event.clientY>box.bottom)setOpen(false);}}>
   <div className="af-explainer-shell flex min-h-0 min-w-0 flex-col bg-slate-50 text-gray-900" style={{colorScheme:'light'}}>
    <div className="flex shrink-0 items-start justify-between gap-3 border-b border-gray-200 bg-white px-4 py-4 sm:px-6">
     <div className="min-w-0"><p className="text-xs font-semibold text-indigo-700">{text.open}</p><h2 id={titleId} className="mt-1 break-words text-lg font-semibold sm:text-2xl">{result.title}</h2><p id={noticeId} className="mt-1 text-xs leading-5 text-gray-700">{s.free}</p></div>
     <button type="button" autoFocus aria-label={text.close} onClick={()=>setOpen(false)} className="flex min-h-11 min-w-11 shrink-0 items-center justify-center rounded-xl border border-gray-300 bg-white text-2xl text-gray-800 hover:bg-gray-100 focus-visible:outline-2 focus-visible:outline-indigo-700">×</button>
    </div>
    <div className="min-h-0 min-w-0 flex-1 overflow-y-auto overscroll-contain px-3 pb-5 pt-4 sm:px-6">
     <div className="grid min-w-0 gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end"><label className="min-w-0 text-sm font-medium">{s.language}<select aria-label={s.language} value={result.language} onChange={event=>{const language=event.target.value as Language;setResult(prepare({topicId:result.topicId,language,params:result.params,modes:result.modes}));}} className="mt-2 min-h-11 w-full min-w-0 rounded-xl border border-gray-300 bg-white px-3 py-2 text-base text-gray-900">{Object.entries(languageNames).map(([id,label])=><option key={id} value={id}>{label}</option>)}</select></label><a href={'/explore?topic='+encodeURIComponent(result.topicId)+'&lang='+result.language} className="inline-flex min-h-11 items-center justify-center rounded-xl border border-indigo-200 bg-indigo-50 px-4 py-2 text-sm font-medium text-indigo-900">{s.review}</a></div>
     <ResultCard result={result} showOpen={false}/>
    </div>
   </div>
  </dialog>,document.body)}
 </>;
}
