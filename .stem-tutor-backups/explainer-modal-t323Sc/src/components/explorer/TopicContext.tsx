'use client';
import { useEffect, useId, useState } from 'react';
import { usePathname } from 'next/navigation';
import { topics, isLanguage, type Language } from '@/lib/explorer/catalog';
import { prepare, presetFromSearch, type ExplorerResult } from '@/lib/explorer/prepare';
import { languageNames, ui } from '@/lib/explorer/locales';
import { ResultCard } from './ResultCard';
export function TopicContext(){
 const pathname=usePathname(),panelId=useId();
 const [result,setResult]=useState<ExplorerResult|null>(null),[open,setOpen]=useState(false);
 useEffect(()=>{setResult(null);setOpen(false);const topic=topics.find(t=>t.route===pathname);if(!topic)return;const q=new URLSearchParams(window.location.search);let language:Language='en';try{const l=q.get('afLang')||localStorage.getItem('afactor-simulation-language-v1');if(isLanguage(l))language=l;}catch{}
 const preset=presetFromSearch(topic.id,window.location.search);try{setResult(prepare({topicId:topic.id,language,params:preset?.params||{},modes:preset?.modes||{}}));setOpen(!!preset);}catch{}
 },[pathname]);
 if(!result||result.route!==pathname)return null;const s=ui[result.language];
 return <section aria-label={s.principle} className="af-explorer shrink-0 border-b border-indigo-200 bg-slate-100 px-3 py-2 text-gray-900 sm:px-4 sm:py-3" style={{colorScheme:'light'}}><div className="mx-auto min-w-0 max-w-6xl">
  <div className="flex min-w-0 flex-col gap-2 md:flex-row md:items-center md:justify-between md:gap-4">
   <button type="button" aria-expanded={open} aria-controls={panelId} onClick={()=>setOpen(v=>!v)} className="min-h-11 min-w-0 flex-1 rounded-lg px-1 py-2 text-left text-sm font-semibold leading-6 text-indigo-900 focus-visible:outline-2 focus-visible:outline-indigo-700">{open?s.close:s.principle} · {result.title}<span aria-hidden="true" className="ml-2">{open?'▴':'▾'}</span></button>
   <div className="grid min-w-0 grid-cols-[minmax(0,1fr)_minmax(0,1fr)] items-center gap-3 md:flex md:shrink-0">
    <select aria-label={s.language} value={result.language} onChange={e=>{const language=e.target.value as Language;setResult(prepare({topicId:result.topicId,language,params:result.params,modes:result.modes}));}} className="min-h-11 min-w-0 max-w-full rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900">{Object.entries(languageNames).map(([id,label])=><option key={id} value={id}>{label}</option>)}</select>
    <a href={'/explore?topic='+encodeURIComponent(result.topicId)+'&lang='+result.language} className="flex min-h-11 min-w-0 items-center rounded-lg py-2 text-sm leading-5 text-indigo-900 underline">{s.review}</a>
   </div>
  </div>
  <div id={panelId} hidden={!open} className="max-h-[min(60dvh,36rem)] min-w-0 overflow-y-auto overscroll-contain pb-1">{open&&<ResultCard result={result} showOpen={false}/>}</div>
 </div></section>;
}
