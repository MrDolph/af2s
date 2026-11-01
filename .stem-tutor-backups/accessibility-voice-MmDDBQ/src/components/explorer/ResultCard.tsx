'use client';
import { getTopic, topics } from '@/lib/explorer/catalog';
import { ui } from '@/lib/explorer/locales';
import type { ExplorerResult } from '@/lib/explorer/prepare';
export function ResultCard({result,showOpen=true}:{result:ExplorerResult;showOpen?:boolean}) {
 const topic=getTopic(result.topicId);if(!topic)return null;const s=ui[result.language];
 return <article lang={result.language} className="af-explorer mt-4 min-w-0 max-w-full rounded-2xl border border-indigo-200 bg-white p-3 sm:p-5 text-gray-900 shadow-sm">
  <p className="text-xs font-semibold text-indigo-700">{s.free}</p><h2 className="mt-2 text-xl font-semibold">{topic.title}</h2><p className="mt-3 text-sm leading-7">{result.explanation}</p>
  <div className="mt-4 rounded-xl bg-indigo-50 p-4"><h3 className="text-xs font-semibold text-indigo-900">{s.principle}</h3><p className="mt-2 text-sm leading-7 text-indigo-950">{topic.principle}</p></div>
  {result.calculation&&<div className="mt-3 rounded-xl bg-emerald-50 p-4"><h3 className="text-xs font-semibold text-emerald-900">{s.numerical}</h3><p className="mt-2 text-sm leading-7 text-emerald-950">{result.calculation}</p><p className="mt-2 text-xs text-emerald-900">Formulae, units and calculation assumptions: English.</p></div>}
  {result.language!=='en'&&<details className="mt-3 text-sm"><summary className="cursor-pointer min-h-11 py-2 text-indigo-800">{s.source}</summary><p className="mt-2 leading-7">{topic.description}</p></details>}
  {!!topic.parameters.length&&<details className="mt-4 text-sm"><summary className="cursor-pointer min-h-11 py-2 font-medium">{s.settings} ({topic.parameters.length})</summary><p className="my-2 text-xs leading-6 text-gray-700">{s.omitted} {s.bridge}</p><div className="min-w-0 max-w-full overflow-x-auto overscroll-x-contain"><table className="w-full text-left text-xs"><thead><tr className="border-b"><th className="p-2">Key</th><th className="p-2">Value</th><th className="p-2">Range</th></tr></thead><tbody>{topic.parameters.map(p=><tr className="border-b border-gray-100" key={p.key}><td className="p-2">{p.label} <code>({p.key})</code></td><td className="p-2">{result.params[p.key]} {p.unit}{result.requested.includes(p.key)?' *':''}</td><td className="p-2">{p.min}–{p.max}</td></tr>)}</tbody></table></div></details>}
  {Object.keys(result.modes).length>0&&<p className="mt-3 text-xs text-gray-700">{s.modes}: {Object.entries(result.modes).map(([k,v])=>`${k}=${v}`).join(', ')}</p>}
  <p className="mt-3 text-xs leading-6 text-gray-700">{s.manual} {s.limitations}</p>{topic.protected&&<p className="mt-2 text-xs font-medium text-amber-900">{s.protected}</p>}
  {showOpen&&<a href={result.url} className="mt-4 inline-flex min-h-11 w-full items-center justify-center rounded-xl bg-indigo-700 sm:w-auto px-5 py-3 text-sm font-semibold text-white hover:bg-indigo-800">{s.open} →</a>}
  <details className="mt-4 text-xs"><summary className="cursor-pointer min-h-11 py-2 text-gray-700">{s.reference}</summary><div className="mt-2 flex flex-wrap gap-3">{topics.filter(t=>t.id!==topic.id&&t.concept===topic.concept).slice(0,4).map(t=><a className="text-indigo-800 underline" key={t.id} href={'/explore?topic='+encodeURIComponent(t.id)+'&lang='+result.language}>{t.title}</a>)}</div></details>
 </article>;
}
