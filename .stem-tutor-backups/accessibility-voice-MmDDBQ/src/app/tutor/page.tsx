'use client';
import { useEffect, useState } from 'react';
import Link from 'next/link';
import { AppHeader } from '@/components/layout/AppHeader';
import { lessons } from '@/lib/tutor/lessons';
import { demoAnswer, detectIntent, isLanguage, languageName, languages, localizedLesson, strings, type DemoIntent, type Language } from '@/lib/tutor/local-demo';

type Result = { selected: number; correct: boolean };
type Message = { question: string; intent: DemoIntent | null };
const STORAGE = 'afactor-stem-tutor-v1';
const LANGUAGE_STORAGE = 'afactor-stem-tutor-language-v1';
const button = 'rounded-xl border border-gray-300 bg-white px-4 py-2 text-sm font-medium text-gray-800 hover:border-indigo-500 focus-visible:outline-2 focus-visible:outline-indigo-600 disabled:opacity-50';
const intents: DemoIntent[] = ['explain', 'example', 'activity', 'hint', 'solution'];

export default function TutorPage() {
  const [language, setLanguage] = useState<Language>('en');
  const [lessonId, setLessonId] = useState(lessons[0].id);
  const [stage, setStage] = useState<'learn' | 'explore' | 'practise'>('learn');
  const [results, setResults] = useState<Record<string, Result>>({});
  const [loaded, setLoaded] = useState(false);
  const [storageError, setStorageError] = useState(false);
  const [selected, setSelected] = useState<number | null>(null);
  const [hint, setHint] = useState(false);
  const [question, setQuestion] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const lesson = localizedLesson(lessonId, language);
  const ui = strings(language);
  const result = results[lesson.id];
  const promptLabels = { explain: ui.explain, example: ui.showExample, activity: ui.showActivity, hint: ui.showHint, solution: ui.showSolution };
  const subjectName = (subject: typeof lesson.subject) => ui.subjects[subject];
  useEffect(() => {
    try {
      const lang = localStorage.getItem(LANGUAGE_STORAGE);
      if (isLanguage(lang)) setLanguage(lang);
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
  }, []);
  useEffect(() => {
    if (!loaded) return;
    try { localStorage.setItem(STORAGE, JSON.stringify(results)); localStorage.setItem(LANGUAGE_STORAGE, language); }
    catch { setStorageError(true); }
  }, [results, language, loaded]);
  function changeLesson(id: string) {
    setLessonId(id); setStage('learn'); setSelected(null); setHint(false); setMessages([]); setQuestion('');
  }
  function addMessage(intent: DemoIntent | null, text: string) {
    setMessages(m => [...m.slice(-9), { question: text, intent }]);
  }
  function ask(event: React.FormEvent) {
    event.preventDefault();
    if (!question.trim()) return;
    addMessage(detectIntent(question), question.trim()); setQuestion('');
  }
  function exportProgress() {
    const lines = [ui.record, languageName(language), ui.saved, ...lessons.map(l => `${subjectName(l.subject)}: ${localizedLesson(l.id, language).title} — ${results[l.id] ? results[l.id].correct ? ui.correct : ui.review : ui.notAttempted}`)];
    const url = URL.createObjectURL(new Blob([lines.join('\n')], { type: 'text/plain;charset=utf-8' }));
    const a = document.createElement('a'); a.href = url; a.download = 'A-Factor_STEM_Practice_Record.txt';
    document.body.appendChild(a); a.click(); a.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  return <div className="af-tutor" data-stem-tutor-contrast lang={language} style={{ backgroundColor: '#f1f5f9', color: '#111827', colorScheme: 'light', minHeight: '100vh' }}><AppHeader />
    <main className="mx-auto max-w-6xl px-4 py-8 sm:px-6 sm:py-12">
      <div className="mb-6 flex flex-wrap items-start justify-between gap-5">
        <div className="max-w-2xl"><p className="mb-2 text-xs font-semibold uppercase tracking-widest text-indigo-700">A-Factor STEM Studio</p><h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">{ui.heading}</h1><p className="mt-3 text-sm leading-6 text-gray-700">{ui.intro}</p></div>
        <div className="space-y-3"><span className="inline-block rounded-full bg-emerald-100 px-3 py-2 text-xs font-semibold text-emerald-900">{ui.badge}</span><label className="block text-sm font-medium" htmlFor="tutor-language">{ui.language}</label><select id="tutor-language" value={language} onChange={e => { if (isLanguage(e.target.value)) setLanguage(e.target.value); }} className="w-full rounded-xl border border-gray-300 bg-white px-4 py-3 text-gray-900 focus:outline-indigo-600">{languages.map(lang => <option key={lang} value={lang}>{languageName(lang)}</option>)}</select></div>
      </div>
      <div className="mb-6 grid grid-cols-2 gap-2 sm:grid-cols-4" aria-label={ui.subject}>{lessons.map(l => <button key={l.id} onClick={() => changeLesson(l.id)} aria-pressed={lesson.id === l.id} className={`${button} py-4 ${lesson.id === l.id ? '!border-indigo-600 !bg-indigo-600 !text-white' : ''}`}>{subjectName(l.subject)}</button>)}</div>
      <div className="grid items-start gap-6 lg:grid-cols-[1fr_300px]">
        <section className="overflow-hidden rounded-2xl border border-gray-200 bg-white">
          <div className="border-b border-gray-200 p-6"><p className="text-xs font-semibold text-indigo-700">{subjectName(lesson.subject)}</p><h2 className="mt-2 text-2xl font-semibold">{lesson.title}</h2><p className="mt-2 text-sm leading-6 text-gray-700">{lesson.objective}</p></div>
          <div className="flex flex-wrap gap-2 border-b border-gray-200 px-6 py-3">{(['learn', 'explore', 'practise'] as const).map((s, i) => <button key={s} onClick={() => setStage(s)} aria-pressed={stage === s} className={`rounded-lg px-3 py-2 text-sm ${stage === s ? 'bg-indigo-100 font-semibold text-indigo-900' : 'text-gray-700 hover:bg-gray-100'}`}>{i + 1}. {ui[s]}</button>)}</div>
          <div className="min-h-80 p-6">
            {stage === 'learn' && <><h3 className="font-semibold">{ui.idea}</h3><p className="mt-3 text-sm leading-7 text-gray-700">{lesson.explanation}</p><div className="my-6 rounded-xl bg-indigo-50 p-5"><h3 className="text-sm font-semibold text-indigo-900">{ui.example}</h3><p className="mt-2 text-sm leading-7 text-indigo-950">{lesson.example}</p></div><button className={button} onClick={() => setStage('explore')}>{ui.explore} →</button></>}
            {stage === 'explore' && <><h3 className="font-semibold">{ui.investigate}</h3><p className="my-4 text-sm leading-7 text-gray-700">{lesson.investigation}</p>{lesson.resource && <Link href={lesson.resource.href} target="_blank" rel="noopener noreferrer" className="inline-block rounded-xl bg-indigo-600 px-4 py-3 text-sm font-medium text-white">{ui.open} ↗</Link>}<p className="my-4 text-xs leading-6 text-gray-700">{lesson.resource ? ui.activityNote : ui.biologyNote}</p><button className={button} onClick={() => setStage('practise')}>{ui.practise} →</button></>}
            {stage === 'practise' && <><h3 className="font-semibold leading-7">{lesson.question}</h3><fieldset disabled={!!result} className="my-4 space-y-2"><legend className="sr-only">{lesson.question}</legend>{lesson.options.map((option, i) => <label key={i} className={`flex cursor-pointer items-center gap-3 rounded-xl border p-3 text-sm ${((result?.selected ?? selected) === i) ? 'border-indigo-600 bg-indigo-50' : 'border-gray-300'}`}><input type="radio" name={lesson.id} checked={(result?.selected ?? selected) === i} onChange={() => setSelected(i)} />{option}</label>)}</fieldset>
              {!result ? <div className="flex flex-wrap gap-2"><button className={button} disabled={selected === null || !loaded} onClick={() => { if (selected !== null) setResults(r => ({ ...r, [lesson.id]: { selected, correct: selected === lesson.correct } })); }}>{ui.check}</button><button className={button} onClick={() => setHint(true)}>{ui.hint}</button></div> : <div role="status" className={`rounded-xl p-4 text-sm leading-7 ${result.correct ? 'bg-emerald-50 text-emerald-950' : 'bg-amber-50 text-amber-950'}`}><strong>{result.correct ? ui.correct : ui.review}. </strong>{lesson.solution}<button className="mt-3 block underline" onClick={() => { setResults(r => { const next = { ...r }; delete next[lesson.id]; return next; }); setSelected(null); setHint(false); }}>{ui.retry}</button></div>}
              {hint && !result && <p role="status" className="mt-4 rounded-xl bg-gray-100 p-4 text-sm leading-7">{lesson.hint}</p>}</>}
          </div>
        </section>
        <aside className="rounded-2xl border border-gray-200 bg-white p-5"><h2 className="font-semibold">{ui.record}</h2><p className="my-3 text-sm text-gray-700">{ui.attempted}: {Object.keys(results).length} / 4 · {ui.correct}: {Object.values(results).filter(r => r.correct).length}</p><ul className="space-y-3">{lessons.map(l => <li key={l.id} className="flex justify-between gap-2 text-xs leading-5"><span>{subjectName(l.subject)}</span><span className={results[l.id]?.correct ? 'text-emerald-800' : 'text-gray-700'}>{results[l.id] ? results[l.id].correct ? ui.correct : ui.review : ui.notAttempted}</span></li>)}</ul><p className="mt-4 text-xs leading-6 text-gray-700">{ui.saved}</p>{storageError && <p role="status" className="mt-2 text-xs text-amber-900">{ui.storageError}</p>}<button className={`${button} mt-4 w-full`} onClick={exportProgress}>{ui.download}</button><button className="mt-3 w-full text-xs text-gray-700 underline" onClick={() => { if (window.confirm(ui.confirm)) { setResults({}); setSelected(null); setHint(false); } }}>{ui.clear}</button></aside>
      </div>
      <section className="mt-6 rounded-2xl border border-gray-200 bg-white p-6"><h2 className="text-xl font-semibold">{ui.coach}</h2><p className="mt-3 rounded-xl bg-emerald-50 p-4 text-sm leading-7 text-emerald-950">{ui.demoNotice}</p>
        <div className="my-4 flex flex-wrap gap-2">{intents.map(intent => <button key={intent} className={button} onClick={() => addMessage(intent, '')}>{promptLabels[intent]}</button>)}</div>
        <div role="log" aria-live="polite" aria-label={ui.coach} className="max-h-96 space-y-3 overflow-y-auto">{messages.map((m, i) => <div key={i}><div className="ml-4 rounded-xl bg-indigo-50 p-3 text-sm leading-7"><strong>{ui.you}: </strong>{m.question || (m.intent ? promptLabels[m.intent] : '')}</div><div className="mr-4 mt-2 whitespace-pre-wrap rounded-xl bg-gray-100 p-4 text-sm leading-7"><strong className="mb-1 block text-xs">{ui.tutor}</strong>{demoAnswer(lesson.id, language, m.intent)}</div></div>)}</div>
        <form onSubmit={ask} className="mt-4 flex flex-wrap gap-2"><label htmlFor="tutor-question" className="sr-only">{ui.placeholder}</label><textarea id="tutor-question" value={question} onChange={e => setQuestion(e.target.value)} maxLength={1200} rows={2} placeholder={ui.placeholder} className="min-w-0 flex-1 rounded-xl border border-gray-300 bg-white p-3 text-sm text-gray-900 placeholder:text-gray-600 focus:outline-indigo-600" /><button className={button} disabled={!question.trim()}>{ui.send}</button></form>
      </section>
      <p className="mt-6 rounded-xl border border-amber-200 bg-amber-50 p-4 text-xs leading-6 text-amber-950">{ui.translationNote}</p><p className="mt-5 text-center text-xs leading-6 text-gray-700">Mr Dawodu O.F. · A-Factor EdTech Solutions · {ui.limit}</p>
    </main></div>;
}
