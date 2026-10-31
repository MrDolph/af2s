'use client';
import { useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { topics, normalize } from '@/lib/explorer/catalog';
const subjects=['All','Physics','Chemistry','Mathematics','Geophysics'];
export default function AllSimulationsPage(){
 const [subject,setSubject]=useState('All'),[search,setSearch]=useState('');
 const query=normalize(search);
 const visible=topics.filter(t=>(subject==='All'||t.subject===subject)&&(!query||normalize([t.title,t.description,...t.aliases].join(' ')).includes(query)));
 return <div style={{background:'#f1f5f9',color:'#111827',minHeight:'100vh',colorScheme:'light'}}><AppHeader/><main className="af-explorer mx-auto min-w-0 max-w-7xl px-4 py-8 sm:px-6 sm:py-12">
  <p className="text-xs font-semibold uppercase tracking-widest text-indigo-700">A-Factor STEM Studio</p><h1 className="mt-2 text-3xl font-semibold">All simulations &amp; activities</h1><p className="mt-3 max-w-2xl text-sm leading-7 text-gray-700">Browse {topics.length} existing activities across Physics, Chemistry, Mathematics and Geophysics. Open an activity to use its controls, or choose Try AI for guided explanations.</p>
  <div className="mt-6 min-w-0"><label htmlFor="simulation-search" className="mb-2 block text-sm font-medium">Find an activity</label><input id="simulation-search" type="search" value={search} onChange={e=>setSearch(e.target.value)} placeholder="Search by topic or concept" className="min-h-11 w-full min-w-0 rounded-xl border border-gray-300 bg-white px-4 py-3 text-base text-gray-900 placeholder:text-gray-600"/></div>
  <div className="mt-4 flex max-w-full gap-2 overflow-x-auto pb-2" aria-label="Filter activities by subject">{subjects.map(s=><button key={s} onClick={()=>setSubject(s)} aria-pressed={subject===s} className={`min-h-11 shrink-0 rounded-full border px-4 py-2 text-sm font-medium ${subject===s?'border-indigo-700 bg-indigo-700 text-white':'border-gray-300 bg-white text-gray-700'}`}>{s}</button>)}</div>
  <p role="status" className="my-4 text-xs text-gray-700">{visible.length} activities</p>
  <div className="grid min-w-0 gap-4 sm:grid-cols-2 lg:grid-cols-3">{visible.map(t=><article key={t.id} className="flex min-w-0 flex-col rounded-2xl border border-gray-200 bg-white p-5"><p className="text-xs font-semibold text-indigo-700">{t.subject}</p><h2 className="mt-2 text-lg font-semibold"><Link href={t.route} className="hover:text-indigo-800 hover:underline">{t.title}</Link></h2><p className="mb-5 mt-2 flex-1 text-sm leading-7 text-gray-700">{t.description}</p>{t.protected&&<p className="mb-3 text-xs text-amber-900">Student login required by the existing Minitab tool.</p>}<Link href={t.route} className="inline-flex min-h-11 items-center justify-center rounded-xl border border-indigo-200 bg-indigo-50 px-4 py-2 text-sm font-semibold text-indigo-900">Open activity →</Link></article>)}</div>
  {!visible.length&&<p className="rounded-xl border border-gray-200 bg-white p-6 text-sm text-gray-700">No matching activities. Try another search or choose All.</p>}
 </main></div>;
}
