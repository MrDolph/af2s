'use client';
import { useEffect, useRef, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { lessons, type Subject } from '@/lib/tutor/lessons';

type Message = { role: 'user' | 'assistant'; text: string };
type Result = { selected: number; correct: boolean };
const subjects: Subject[] = ['Physics', 'Chemistry', 'Biology', 'Mathematics'];
const STORAGE = 'afactor-stem-tutor-v1';
const button = 'rounded-xl border border-gray-200 bg-white px-4 py-2 text-sm font-medium text-gray-700 hover:border-indigo-400 focus-visible:outline-2 focus-visible:outline-indigo-600 disabled:opacity-50';

export default function TutorPage() {
  const [lessonId, setLessonId] = useState(lessons[0].id);
  const lesson = lessons.find(l => l.id === lessonId)!;
  const [stage, setStage] = useState<'Learn' | 'Explore' | 'Practise'>('Learn');
  const [results, setResults] = useState<Record<string, Result>>({});
  const [loaded, setLoaded] = useState(false);
  const [storageError, setStorageError] = useState(false);
  const [selected, setSelected] = useState<number | null>(null);
  const [hint, setHint] = useState(false);
  const [live, setLive] = useState(false);
  const [messages, setMessages] = useState<Message[]>([]);
  const [question, setQuestion] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const pending = useRef<AbortController | null>(null);
  const result = results[lesson.id];
  useEffect(() => {
    try {
      const saved: unknown = JSON.parse(localStorage.getItem(STORAGE) || '{}');
      const valid: Record<string, Result> = {};
      if (saved && typeof saved === 'object') for (const l of lessons) {
        const value = (saved as Record<string, Result>)[l.id];
        if (value && Number.isInteger(value.selected) && value.selected >= 0 && value.selected < l.options.length)
          valid[l.id] = { selected: value.selected, correct: value.selected === l.correct };
      }
      setResults(valid);
    } catch { setStorageError(true); }
    setLoaded(true);
    return () => pending.current?.abort();
  }, []);
  useEffect(() => {
    if (loaded) try { localStorage.setItem(STORAGE, JSON.stringify(results)); } catch { setStorageError(true); }
  }, [results, loaded]);
  function changeLesson(id: string) {
    pending.current?.abort(); pending.current = null;
    setLessonId(id); setStage('Learn'); setSelected(null); setHint(false);
    setMessages([]); setQuestion(''); setBusy(false); setError('');
  }
  async function ask(event: React.FormEvent) {
    event.preventDefault();
    if (busy || !question.trim()) return;
    const controller = new AbortController(); pending.current = controller;
    const text = question.trim(); setBusy(true); setError('');
    setMessages(m => [...m, { role: 'user', text }]); setQuestion('');
    const timeout = setTimeout(() => controller.abort(), 28000);
    try {
      const response = await fetch('/api/tutor', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ lessonId, question: text }), signal: controller.signal });
      const data = await response.json();
      if (!response.ok || typeof data.answer !== 'string') throw new Error(data.error || 'Tutor unavailable.');
      if (pending.current === controller) setMessages(m => [...m, { role: 'assistant', text: data.answer }]);
    } catch (e) {
      if (pending.current === controller) { setError(controller.signal.aborted ? 'Request timed out. Please try again.' : e instanceof Error ? e.message : 'Tutor unavailable.'); setQuestion(text); }
    } finally { clearTimeout(timeout); if (pending.current === controller) { pending.current = null; setBusy(false); } }
  }
  function exportProgress() {
    const text = ['A-Factor STEM Tutor — practice record', 'These are four practice questions, not a validated assessment of mastery.', ...lessons.map(l => `${l.subject}: ${l.title} — ${results[l.id] ? results[l.id].correct ? 'Correct' : 'Needs review' : 'Not attempted'}`)].join('\n');
    const url = URL.createObjectURL(new Blob([text], { type: 'text/plain' }));
    const a = document.createElement('a'); a.href = url; a.download = 'A-Factor_STEM_Practice_Record.txt'; a.click(); URL.revokeObjectURL(url);
  }
  return <div data-stem-tutor-contrast style={{ backgroundColor: "#f1f5f9", color: "#111827", colorScheme: "light", minHeight: "100vh" }}><AppHeader /><main className="mx-auto max-w-6xl px-4 py-8 text-gray-900 sm:px-6 sm:py-12">
    <div className="mb-8 flex flex-wrap items-start justify-between gap-4">
      <div><p className="mb-2 text-xs font-semibold uppercase tracking-widest text-indigo-600">A-Factor Academy · Capstone prototype</p>
        <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">Your STEM study companion</h1>
        <p className="mt-3 max-w-xl text-sm leading-6 text-gray-600">Understand the idea. Explore an activity. Try it yourself. Start with one focused lesson in each subject.</p></div>
      <span className="rounded-full bg-amber-50 px-3 py-2 text-xs font-medium text-amber-800">Guided demo · 4 starter lessons</span>
    </div>
    <div className="mb-6 grid grid-cols-2 gap-2 sm:grid-cols-4" aria-label="Choose subject">{subjects.map((subject, i) => <button key={subject} onClick={() => changeLesson(lessons[i].id)} aria-pressed={lesson.subject === subject} className={`${button} py-4 ${lesson.subject === subject ? '!border-indigo-600 !bg-indigo-600 !text-white' : ''}`}>{subject}</button>)}</div>
    <div className="grid items-start gap-6 lg:grid-cols-[1fr_300px]">
      <section className="overflow-hidden rounded-2xl border border-gray-200 bg-white">
        <div className="border-b border-gray-100 p-6"><p className="text-xs font-medium text-indigo-600">{lesson.subject} · Senior secondary</p><h2 className="mt-1 text-2xl font-semibold">{lesson.title}</h2><p className="mt-2 text-sm text-gray-600">{lesson.objective}</p></div>
        <div className="flex gap-2 border-b border-gray-100 px-6 py-3" aria-label="Learning stage">{(['Learn', 'Explore', 'Practise'] as const).map((s, i) => <button key={s} onClick={() => setStage(s)} aria-pressed={stage === s} className={`rounded-lg px-3 py-2 text-sm ${stage === s ? 'bg-indigo-50 font-semibold text-indigo-700' : 'text-gray-600 hover:bg-gray-50'}`}>{i + 1}. {s}</button>)}</div>
        <div className="min-h-80 p-6 leading-7">
          {stage === 'Learn' && <><h3 className="font-semibold">The idea</h3><p className="mt-2 text-sm leading-7 text-gray-600">{lesson.explanation}</p><div className="my-6 rounded-xl bg-indigo-50 p-5"><h3 className="text-sm font-semibold text-indigo-900">Worked example</h3><p className="mt-2 text-sm leading-7 text-indigo-900">{lesson.example}</p></div><button className={button} onClick={() => setStage('Explore')}>Explore this idea →</button></>}
          {stage === 'Explore' && <><h3 className="font-semibold">Predict, investigate, explain</h3><p className="my-4 text-sm leading-7 text-gray-600">{lesson.investigation}</p>{lesson.resource && <Link href={lesson.resource.href} target="_blank" rel="noopener noreferrer" className="inline-block rounded-xl bg-indigo-600 px-4 py-2 text-sm font-medium text-white">{lesson.resource.title} ↗</Link>}<p className="my-4 text-xs leading-5 text-gray-600">{lesson.resource ? 'Activity opens in a new tab. Return here to check your understanding. The tutor cannot see your simulation settings.' : 'Use the scenario above; no external Biology tool is connected yet.'}</p><button className={button} onClick={() => setStage('Practise')}>Try a question →</button></>}
          {stage === 'Practise' && <><h3 className="font-semibold">{lesson.question}</h3><fieldset disabled={!!result} className="my-4 space-y-2"><legend className="sr-only">Choose one answer</legend>{lesson.options.map((option, i) => <label key={option} className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3 text-sm ${((result?.selected ?? selected) === i) ? 'border-indigo-600 bg-indigo-50' : 'border-gray-200'}`}><input type="radio" name={lesson.id} checked={(result?.selected ?? selected) === i} onChange={() => setSelected(i)} />{option}</label>)}</fieldset>
            {!result ? <div className="flex flex-wrap gap-2"><button className={button} disabled={selected === null || !loaded} onClick={() => { if (selected !== null) setResults(r => ({ ...r, [lesson.id]: { selected, correct: selected === lesson.correct } })); }}>Check answer</button><button className={button} onClick={() => setHint(true)}>Give me a hint</button></div> : <div role="status" className={`rounded-xl p-4 text-sm ${result.correct ? 'bg-emerald-50 text-emerald-900' : 'bg-amber-50 text-amber-900'}`}><strong>{result.correct ? 'Correct. ' : 'Review this idea. '}</strong>{lesson.solution}<button className="mt-3 block underline" onClick={() => { setResults(r => { const next = { ...r }; delete next[lesson.id]; return next; }); setSelected(null); setHint(false); }}>Try again</button></div>}
            {hint && !result && <p role="status" className="mt-4 rounded-xl bg-gray-50 p-4 text-sm">{lesson.hint}</p>}</>}
        </div>
      </section>
      <aside className="space-y-4"><section className="rounded-2xl border border-gray-200 bg-white p-5"><h2 className="font-semibold">Your practice record</h2><p className="my-3 text-sm text-gray-600">{Object.keys(results).length} / 4 questions attempted · {Object.values(results).filter(r => r.correct).length} correct</p><ul className="space-y-3">{lessons.map(l => <li key={l.id} className="flex justify-between gap-2 text-xs"><span>{l.subject}</span><span className={results[l.id]?.correct ? 'text-emerald-700' : 'text-gray-600'}>{results[l.id] ? results[l.id].correct ? 'Correct' : 'Needs review' : 'Not attempted'}</span></li>)}</ul><p className="mt-4 text-xs leading-5 text-gray-600">Saved on this browser only. One question per topic does not establish mastery.</p>{storageError && <p role="status" className="mt-2 text-xs text-amber-800">Browser storage is unavailable. Progress may not persist.</p>}<button className={`${button} mt-4 w-full`} onClick={exportProgress}>Download record</button><button className="mt-3 w-full text-xs text-gray-600 underline" onClick={() => { if (window.confirm('Clear all four practice results on this browser?')) { setResults({}); setSelected(null); setHint(false); } }}>Clear practice record</button></section>
      <section className="rounded-2xl bg-indigo-950 p-5 text-white"><h2 className="font-semibold">Learn by doing</h2><p className="mt-2 text-sm leading-6 text-indigo-100">Your existing STEM Studio tools turn an explanation into an investigation.</p><Link href="/simulations" className="mt-4 inline-block text-sm font-medium underline">Browse Physics activities →</Link></section></aside>
    </div>
    <section className="mt-6 rounded-2xl border border-gray-200 bg-white p-6"><div className="flex flex-wrap items-center justify-between gap-3"><div><h2 className="text-lg font-semibold">Ask the tutor</h2><p className="mt-1 text-sm text-gray-600">Optional live AI · ask about {lesson.title.toLowerCase()}.</p></div><label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={live} onChange={e => setLive(e.target.checked)} />Enable live questions</label></div>
      {!live ? <p className="mt-4 rounded-xl bg-gray-50 p-4 text-sm leading-6 text-gray-600">The guided demo uses fixed, reviewed lessons and feedback. Enable live questions to contact the configured AI service. Live responses can make mistakes; check calculations and explanations.</p> : <><p className="my-4 text-xs text-gray-600">Your question and the selected lesson are sent to the AI provider. Do not enter personal information. Each question is answered independently.</p><div role="log" aria-live="polite" aria-label="Tutor conversation" className="max-h-96 space-y-3 overflow-y-auto">{messages.map((m, i) => <div key={i} className={`whitespace-pre-wrap rounded-xl p-4 text-sm leading-7 ${m.role === 'user' ? 'ml-6 bg-indigo-50' : 'mr-6 bg-gray-50'}`}><strong className="mb-1 block text-xs">{m.role === 'user' ? 'You' : 'AI tutor'}</strong>{m.text}</div>)}</div><form onSubmit={ask} className="mt-4 flex gap-2"><label htmlFor="tutor-question" className="sr-only">Your STEM question</label><textarea id="tutor-question" value={question} onChange={e => setQuestion(e.target.value)} maxLength={1200} rows={2} placeholder="What part would you like explained?" className="min-w-0 flex-1 rounded-xl border border-gray-300 p-3 text-sm focus:outline-indigo-600" disabled={busy} /><button className={button} disabled={busy || !question.trim()}>{busy ? 'Thinking…' : 'Ask'}</button></form>{error && <p role="alert" className="mt-3 text-sm text-amber-800">{error}</p>}</>}
    </section>
    <p className="mt-6 text-center text-xs leading-5 text-gray-600">Designed by Mr Dawodu O.F. · A-Factor EdTech Solutions · Pilot content, not a complete curriculum.</p>
  </main></div>;
}
