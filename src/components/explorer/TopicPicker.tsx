'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { topics, getTopic } from '@/lib/explorer/catalog';

type Props = { value: string; onChange: (id: string) => void; label: string; automatic: string };
export function TopicPicker({ value, onChange, label, automatic }: Props) {
 const [open, setOpen] = useState(false), [query, setQuery] = useState('');
 const dialog = useRef<HTMLDialogElement>(null), search = useRef<HTMLInputElement>(null), trigger = useRef<HTMLButtonElement>(null);
 const titleId = useId();
 const selected = getTopic(value);
 const filtered = topics.filter(t => `${t.title} ${t.subject}`.toLowerCase().includes(query.trim().toLowerCase()));
 const colours = { color: '#111827', backgroundColor: '#fff', colorScheme: 'light' as const };
 useEffect(() => {
  const el = dialog.current; if (!el) return;
  if (open) { if (!el.open) el.showModal(); search.current?.focus(); }
  else if (el.open) el.close();
 }, [open]);
 function close() { setOpen(false); trigger.current?.focus(); }
 function choose(id: string) { onChange(id); close(); }
 return <div className="min-w-0 text-xs font-semibold text-gray-800" style={colours}>
  <span>{label}</span>
  <button ref={trigger} type="button" aria-haspopup="dialog" aria-expanded={open} onClick={() => { setQuery(''); setOpen(true); }}
   className="mt-1 flex min-h-11 w-full items-center justify-between gap-3 rounded-xl border border-gray-300 p-3 text-left text-sm" style={colours}>
   <span>{selected?.title || automatic}</span><span aria-hidden="true">▾</span>
  </button>
  <dialog ref={dialog} aria-labelledby={titleId} onCancel={e => { e.preventDefault(); close(); }} onClose={close}
   onClick={e => { if (e.target === e.currentTarget) { const rect = e.currentTarget.getBoundingClientRect(); if (e.clientX < rect.left || e.clientX > rect.right || e.clientY < rect.top || e.clientY > rect.bottom) close(); } }}
   className="af-topic-picker" style={colours}>
   <div className="flex items-center justify-between gap-3 border-b border-gray-200 p-3">
    <h2 id={titleId} className="text-base font-semibold" style={{color:'#111827'}}>{label}</h2>
    <button type="button" onClick={close} aria-label="Close topic picker" className="min-h-11 rounded-lg border border-gray-300 px-3" style={colours}>✕</button>
   </div>
   <div className="p-3"><label className="sr-only" htmlFor={`${titleId}-search`}>Search topics</label>
    <input ref={search} id={`${titleId}-search`} type="search" value={query} onChange={e => setQuery(e.target.value)} placeholder="Search topics or subjects…" className="min-h-11 w-full rounded-lg border border-gray-300 px-3 text-base font-normal" style={colours}/>
    <p role="status" className="mt-2 text-xs font-normal" style={{color:'#475569'}}>{filtered.length} topics</p>
   </div>
   <div className="af-topic-picker-list">
    <button type="button" onClick={() => choose('')} className="af-topic-choice" style={colours}>{automatic}{!value && ' ✓'}</button>
    {['Physics','Chemistry','Mathematics','Geophysics'].map(subject => {
     const group = filtered.filter(t => t.subject === subject); if (!group.length) return null;
     return <section key={subject} aria-label={subject}><h3 style={{color:'#3730a3',background:'#eef2ff',padding:'.6rem .75rem',fontSize:'.8rem'}}>{subject}</h3>
      {group.map(t => <button key={t.id} type="button" className="af-topic-choice" style={colours} onClick={() => choose(t.id)} aria-pressed={value===t.id}>{t.title}{value === t.id && ' ✓'}</button>)}
     </section>;
    })}
    {!filtered.length && <p className="p-4 text-sm font-normal" style={{color:'#475569'}}>No topics match this search.</p>}
   </div>
  </dialog>
 </div>;
}
