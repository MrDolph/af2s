'use client';
import { useEffect, useRef, useState } from 'react';
import type { AIPromptResponse } from '@/types/ai';
type Language = 'en' | 'yo' | 'ha' | 'ig';
interface PromptBarProps { onResult: (r: AIPromptResponse) => void; className?: string; }
const languages = { en: 'English', yo: 'Yorùbá', ha: 'Hausa', ig: 'Igbo' };
const labels = {
  en: { language: 'Response language', placeholder: 'Example: projectile at 45° and 30 m/s', generate: 'Apply prompt', loading: 'Reading…', note: 'Free demo: reads supported projectile prompts using rules. No AI API key needed. Other topics are available in the simulations catalogue.', demo: 'Free demo response · no AI service called', live: 'Live AI response' },
  yo: { language: 'Èdè ìdáhùn', placeholder: 'Àpẹẹrẹ: Ṣe afihan projectile ni 45° ati 30 m/s', generate: 'Lo ìbéèrè', loading: 'Ó ń kà á…', note: 'Àpẹẹrẹ ọ̀fẹ́: ó ń lo òfin láti ka ìbéèrè projectile. Kò nílò API key. Àwọn kókó mìíràn wà nínú àkójọ simulation.', demo: 'Ìdáhùn àpẹẹrẹ ọ̀fẹ́ · a kò lo iṣẹ́ AI', live: 'Ìdáhùn AI' },
  ha: { language: 'Harshen amsa', placeholder: 'Misali: Nuna projectile a 45° da 30 m/s', generate: 'Aiwatar', loading: 'Ana karantawa…', note: 'Samfurin kyauta: yana karanta tambayar projectile da ƙa’idoji. Ba ya buƙatar API key. Sauran batutuwa suna cikin jerin simulations.', demo: 'Amsar samfurin kyauta · ba a kira sabis na AI ba', live: 'Amsar AI' },
  ig: { language: 'Asụsụ azịza', placeholder: 'Ihe atụ: Gosi projectile na 45° na 30 m/s', generate: 'Tinye arịrịọ', loading: 'A na-agụ…', note: 'Ihe ngosi efu: ọ na-eji iwu agụ arịrịọ projectile. Ọ chọghị API key. Ihe ndị ọzọ dị na ndepụta simulations.', demo: 'Azịza ihe ngosi efu · ejighị ọrụ AI', live: 'Azịza AI' },
};
const examples: Record<Language, string[]> = {
  en: ['Show projectile motion at 45° and 30 m/s', 'Show projectile motion at 60° and 20 m/s', 'Projectile at 30 m/s, 30°, gravity 2 m/s², mass 2 kg'],
  yo: ['Ṣe afihan projectile ni 45° ati 30 m/s', 'Ṣe afihan projectile ni 60° ati 20 m/s', 'Projectile ni 30 m/s, 30°, gravity 2 m/s², mass 2 kg'],
  ha: ['Nuna projectile a 45° da 30 m/s', 'Nuna projectile a 60° da 20 m/s', 'Projectile a 30 m/s, 30°, gravity 2 m/s², mass 2 kg'],
  ig: ['Gosi projectile na 45° na 30 m/s', 'Gosi projectile na 60° na 20 m/s', 'Projectile na 30 m/s, 30°, gravity 2 m/s², mass 2 kg'],
};
export function PromptBar({ onResult, className }: PromptBarProps) {
  const [prompt, setPrompt] = useState('');
  const [language, setLanguage] = useState<Language>('en');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [mode, setMode] = useState<'demo' | 'live' | null>(null);
  const pending = useRef<AbortController | null>(null);
  const ui = labels[language];
  useEffect(() => {
    try { const saved = localStorage.getItem('afactor-simulation-language-v1'); if (saved && saved in languages) setLanguage(saved as Language); } catch { /* storage is optional */ }
    return () => pending.current?.abort();
  }, []);
  function changeLanguage(value: Language) {
    pending.current?.abort(); pending.current = null; setIsLoading(false);
    setLanguage(value); setError(null); setMode(null);
    try { localStorage.setItem('afactor-simulation-language-v1', value); } catch { /* storage is optional */ }
  }
  async function handleSubmit(text: string) {
    if (!text.trim() || isLoading) return;
    const controller = new AbortController(); pending.current = controller;
    setIsLoading(true); setError(null); setMode(null);
    const timeout = setTimeout(() => controller.abort(), 28000);
    try {
      const res = await fetch('/api/ai', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ prompt: text, language }), signal: controller.signal });
      const result = await res.json();
      if (!res.ok) throw new Error(result.error || 'Unable to read this prompt.');
      if (pending.current !== controller) return;
      onResult(result); setMode(result.mode === 'demo' ? 'demo' : 'live'); setPrompt('');
    } catch (err) {
      if (pending.current === controller) setError(controller.signal.aborted ? 'Request timed out. Try again.' : err instanceof Error ? err.message : 'Unable to read this prompt.');
    } finally { clearTimeout(timeout); if (pending.current === controller) { pending.current = null; setIsLoading(false); } }
  }
  return <div className={className}>
    <div className="mb-3 flex flex-wrap items-center gap-3"><label className="text-xs font-semibold text-gray-700">{ui.language}<select aria-label={ui.language} value={language} onChange={e => changeLanguage(e.target.value as Language)} className="ml-2 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm text-gray-900">{Object.entries(languages).map(([id, name]) => <option key={id} value={id}>{name}</option>)}</select></label></div>
    <p className="mb-3 text-xs leading-6 text-gray-700" lang={language}>{ui.note}</p>
    <div className="flex flex-col gap-2 sm:flex-row"><input aria-label={ui.placeholder} type="text" value={prompt} maxLength={500} onChange={e => setPrompt(e.target.value)} onKeyDown={e => { if (e.key === 'Enter') { e.preventDefault(); void handleSubmit(prompt); } }} placeholder={ui.placeholder} disabled={isLoading} className="min-w-0 flex-1 rounded-lg border border-gray-300 bg-white px-4 py-3 text-base text-gray-900 outline-none placeholder:text-gray-600 focus:border-indigo-500 disabled:opacity-50 sm:text-sm" /><button onClick={() => void handleSubmit(prompt)} disabled={!prompt.trim() || isLoading} className="w-full shrink-0 rounded-lg bg-indigo-600 px-5 py-3 text-sm font-medium text-white hover:bg-indigo-700 disabled:opacity-50 sm:w-auto">{isLoading ? ui.loading : ui.generate}</button></div>
    {error && <p role="alert" className="mt-2 text-sm text-red-800">{error}</p>}
    {mode && <p role="status" lang={language} className="mt-2 text-xs font-semibold text-emerald-800">{mode === 'demo' ? ui.demo : ui.live}</p>}
    <div className="mt-3 flex flex-wrap gap-2">{examples[language].map(p => <button key={p} onClick={() => void handleSubmit(p)} disabled={isLoading} className="max-w-full rounded-xl border border-gray-300 bg-gray-50 px-3 py-2 text-left text-xs leading-5 text-gray-700 hover:border-indigo-400 disabled:opacity-50">{p}</button>)}</div>
  </div>;
}
