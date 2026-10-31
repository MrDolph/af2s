'use client';
import { useEffect, useState } from 'react';
import { usePathname } from 'next/navigation';
import { topics, isLanguage, type Language } from '@/lib/explorer/catalog';
import { prepare, presetFromSearch, type ExplorerResult } from '@/lib/explorer/prepare';
import { languageNames, ui } from '@/lib/explorer/locales';
import { ResultCard } from './ResultCard';
export function TopicContext(){
 const pathname=usePathname();
 const [result,setResult]=useState<ExplorerResult|null>(null),[open,setOpen]=useState(false);
 useEffect(()=>{setResult(null);setOpen(false);const topic=topics.find(t=>t.route===pathname);if(!topic)return;const q=new URLSearchParams(window.location.search);let language:Language='en';try{const l=q.get('afLang')||localStorage.getItem('afactor-simulation-language-v1');if(isLanguage(l))language=l;}catch{}
 const preset=presetFromSearch(topic.id,window.location.search);try{setResult(prepare({topicId:topic.id,language,params:preset?.params||{},modes:preset?.modes||{}}));setOpen(!!preset);}catch{}
 },[pathname]);
 if(!result||result.route!==pathname)return null;const s=ui[result.language];
 return <section className="border-b border-indigo-200 bg-slate-100 px-4 py-3 text-gray-900" style={{colorScheme:'light'}}><div className="mx-auto max-w-6xl"><div className="flex flex-wrap items-center justify-between gap-3"><button onClick={()=>setOpen(v=>!v)} className="text-sm font-semibold text-indigo-900">{open?s.close:s.principle} · {result.title}</button><div className="flex items-center gap-3"><select aria-label={s.language} value={result.language} onChange={e=>{const language=e.target.value as Language;setResult(prepare({topicId:result.topicId,language,params:result.params,modes:result.modes}));}} className="rounded-lg border border-gray-300 bg-white px-2 py-1 text-xs">{Object.entries(languageNames).map(([id,label])=><option key={id} value={id}>{label}</option>)}</select><a href={'/explore?topic='+encodeURIComponent(result.topicId)+'&lang='+result.language} className="text-xs text-indigo-900 underline">{s.review}</a></div></div>{open&&<ResultCard result={result} showOpen={false}/>}</div></section>;
}
