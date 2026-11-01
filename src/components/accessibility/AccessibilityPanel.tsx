'use client';
import { useEffect,useId,useRef,useState } from 'react';
import { createPortal } from 'react-dom';
import { ReadAloud } from './ReadAloud';
import { useAccessibility } from './AccessibilityProvider';
import { DEFAULT_SETTINGS,type AccessibilitySettings } from '@/lib/accessibility/settings';
export function AccessibilityPanel({open,onClose,onOpen}:{open:boolean;onClose:()=>void;onOpen:()=>void}){
 const access=useAccessibility(),dialog=useRef<HTMLDialogElement>(null),title=useId(),notice=useId(),id=useId();const [mounted,setMounted]=useState(false),[pageText,setPageText]=useState(''),[pageLanguage,setPageLanguage]=useState('en');
 useEffect(()=>setMounted(true),[]);
 useEffect(()=>{if(!open)return;const main=document.querySelector('main');if(main instanceof HTMLElement){setPageText(main.innerText.slice(0,12000));setPageLanguage(main.closest('[lang]')?.getAttribute('lang')||'en');}},[open]);
 useEffect(()=>{const node=dialog.current;if(!node||!mounted)return;if(!open){if(node.open)node.close();return;}
  const body=document.body.style.overflow,html=document.documentElement.style.overflow;
  if(!node.open)node.showModal();document.body.style.overflow='hidden';document.documentElement.style.overflow='hidden';
  return()=>{if(node.open)node.close();document.body.style.overflow=body;document.documentElement.style.overflow=html;};
 },[open,mounted]);
 const settings=access.settings,field='mt-2 min-h-11 w-full min-w-0 rounded-xl border border-gray-300 bg-white px-3 py-2 text-base text-gray-900';
 const available=access.voices.filter(v=>!settings.localVoicesOnly||v.localService);
 const checks:[keyof AccessibilitySettings,string,string][]=[['readingSpace','More reading space','Increase line and letter spacing for paragraphs.'],['strongFocus','Clearer keyboard focus','Show a stronger outline around the control you are using.'],['underlineLinks','Underline links','Make links easier to distinguish from ordinary text.'],['reduceMotion','Reduce interface motion','Reduce CSS animations and transitions. Simulations keep their own Run/Pause controls.']];
 return <>
  <button type="button" onClick={onOpen} aria-label="Accessibility settings" title="Accessibility settings" aria-haspopup="dialog" aria-controls={id} aria-expanded={open} className="af-access-launcher"><svg aria-hidden="true" width="27" height="27" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"><circle cx="12" cy="4" r="2"/><path d="M4 8l8 2 8-2M12 10v5M12 15l-5 6M12 15l5 6"/></svg></button>
  {mounted&&createPortal(<dialog id={id} ref={dialog} aria-labelledby={title} aria-describedby={notice} className="af-access-modal" onCancel={e=>{e.preventDefault();onClose();}} onClick={e=>{if(e.target!==e.currentTarget)return;const r=e.currentTarget.getBoundingClientRect();if(e.clientX<r.left||e.clientX>r.right||e.clientY<r.top||e.clientY>r.bottom)onClose();}}>
   <div className="af-access-panel">
    <div className="af-access-panel-head"><div><h2 id={title} className="text-xl font-semibold">Accessibility settings</h2><p id={notice} className="mt-1 text-sm leading-6 text-gray-700">Adjust these settings any time. Saved on this browser only.</p></div><button type="button" autoFocus onClick={onClose} aria-label="Close accessibility settings" className="af-access-close">×</button></div>
    <div className="af-access-panel-body space-y-6">
     {access.storageError&&<p role="status" className="rounded-xl bg-amber-50 p-3 text-sm text-amber-900">Your browser cannot save these preferences. Changes still work for this session.</p>}
     <section><h3 className="text-lg font-semibold">Reading and navigation</h3><label className="mt-4 block text-sm font-medium">Text size: {Math.round(settings.textScale*100)}%<input type="range" min={1} max={1.5} step={.05} value={settings.textScale} onChange={e=>access.update({textScale:Number(e.target.value)})} className="mt-2 min-h-11 w-full"/></label><button type="button" onClick={()=>access.update({textScale:1})} className="af-access-text-button">Reset text size</button>
      <div className="mt-4 space-y-3">{checks.map(([key,label,description])=><label key={key} className="flex min-h-11 cursor-pointer items-start gap-3 rounded-xl border border-gray-200 p-3"><input type="checkbox" checked={settings[key]===true} onChange={e=>access.update({[key]:e.target.checked})} className="mt-1 h-5 w-5 shrink-0"/><span className="min-w-0"><strong className="block text-sm">{label}</strong><span className="mt-1 block text-xs leading-6 text-gray-700">{description}</span></span></label>)}</div>
     </section>
     <section><h3 className="text-lg font-semibold">Read aloud</h3>{pageText&&<div className="mt-3 rounded-xl bg-slate-50 p-3"><p className="text-sm font-medium">Read this page’s main text</p><p className="mt-1 text-xs leading-6 text-gray-700">Up to 12,000 characters. Charts, canvas graphics and embedded tools are not described automatically.</p><ReadAloud text={pageText} language={pageLanguage}/></div>}<p className="mt-2 text-sm leading-7 text-gray-700">Use Read aloud beside lessons and explanations. Nothing starts reading automatically. Available languages depend on voices installed on your device.</p>
      {!access.canSpeak&&<p className="mt-2 text-sm text-amber-900">Speech synthesis is unavailable in this browser.</p>}
      <label className="mt-3 flex min-h-11 items-start gap-3 text-sm"><input type="checkbox" checked={settings.localVoicesOnly} onChange={e=>access.update({localVoicesOnly:e.target.checked,voiceURI:''})} className="mt-1 h-5 w-5"/><span>Use on-device voices only<span className="mt-1 block text-xs leading-6 text-gray-700">If turned off, some voices may send text to the browser or voice provider.</span></span></label>
      <label className="mt-4 block text-sm font-medium">Voice<select value={settings.voiceURI} onChange={e=>access.update({voiceURI:e.target.value})} className={field}><option value="">Automatic: match the text language</option>{available.map(v=><option key={v.voiceURI} value={v.voiceURI}>{v.name} — {v.lang}{v.localService?' · on device':''}</option>)}</select></label>
      {!available.length&&<p className="mt-2 text-xs leading-6 text-amber-900">No eligible voices are available yet. Voice support may require an installed language voice. Text stays visible.</p>}
      <label className="mt-4 block text-sm font-medium">Reading speed: {settings.rate.toFixed(2)}×<input type="range" min={.6} max={1.5} step={.05} value={settings.rate} onChange={e=>access.update({rate:Number(e.target.value)})} className="mt-2 min-h-11 w-full"/></label>
      <label className="mt-3 block text-sm font-medium">Voice pitch: {settings.pitch.toFixed(2)}<input type="range" min={.8} max={1.2} step={.05} value={settings.pitch} onChange={e=>access.update({pitch:Number(e.target.value)})} className="mt-2 min-h-11 w-full"/></label>
      <button type="button" className="af-access-text-button" onClick={()=>access.update({rate:DEFAULT_SETTINGS.rate,pitch:DEFAULT_SETTINGS.pitch,voiceURI:'',localVoicesOnly:true})}>Reset voice settings</button>
     </section>
     <section><h3 className="text-lg font-semibold">Speak a question</h3><label className="mt-3 flex min-h-11 items-start gap-3 rounded-xl border border-gray-200 p-3"><input type="checkbox" checked={settings.voiceInput} onChange={e=>access.update({voiceInput:e.target.checked})} className="mt-1 h-5 w-5 shrink-0"/><span className="text-sm font-medium">Enable voice input</span></label><p className="mt-2 text-xs leading-6 text-gray-700">Off by default. Your browser may send microphone audio to its speech provider and may need an internet connection. Recording starts only after you press Speak a question. Transcribed text is editable and is never submitted automatically. Browser and language support varies.</p></section>
     <p className="rounded-xl bg-indigo-50 p-4 text-xs leading-6 text-indigo-950">Keep using your normal screen reader, browser zoom and keyboard tools. These controls provide additional options; they do not establish full accessibility compliance. Voice support does not change the free tutor’s supported-question limits. Embedded tools may have their own settings.</p>
    </div>
    <div className="af-access-panel-footer"><button type="button" onClick={access.reset} className="min-h-11 rounded-xl border-2 border-red-700 bg-white px-4 py-2 text-sm font-semibold text-red-800">Reset all accessibility settings</button><button type="button" onClick={onClose} className="min-h-11 rounded-xl bg-indigo-700 px-5 py-2 text-sm font-semibold text-white">Done</button><p className="w-full text-xs leading-5 text-gray-700">Reset stops voice activity and restores defaults. Your lesson results and language choices are kept.</p></div>
   </div>
  </dialog>,document.body)}
 </>;
}
