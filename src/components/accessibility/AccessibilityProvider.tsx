'use client';
import { createContext,useContext,useEffect,useRef,useState,type ReactNode } from 'react';
import { usePathname } from 'next/navigation';
import { ACCESSIBILITY_KEY,DEFAULT_SETTINGS,sanitizeSettings,speechChunks,speechLanguage,speechText,type AccessibilitySettings } from '@/lib/accessibility/settings';
import { AccessibilityPanel } from './AccessibilityPanel';
type SpeechState={id:string;paused:boolean}|null;
type AccessContext={settings:AccessibilitySettings;update:(patch:Partial<AccessibilitySettings>)=>void;reset:()=>void;openSettings:()=>void;voices:SpeechSynthesisVoice[];canSpeak:boolean;speech:SpeechState;speechError:{id:string;message:string}|null;speak:(text:string,language:string,id:string)=>void;stop:()=>void;pause:()=>void;resume:()=>void;storageError:boolean};
const Context=createContext<AccessContext|null>(null);
export function useAccessibility(){const value=useContext(Context);if(!value)throw Error('AccessibilityProvider is missing.');return value;}
export function AccessibilityProvider({children}:{children:ReactNode}){
 const pathname=usePathname();const [settings,setSettings]=useState<AccessibilitySettings>(DEFAULT_SETTINGS),[loaded,setLoaded]=useState(false),[storageError,setStorageError]=useState(false),[panelOpen,setPanelOpen]=useState(false),[voices,setVoices]=useState<SpeechSynthesisVoice[]>([]),[canSpeak,setCanSpeak]=useState(false),[speech,setSpeech]=useState<SpeechState>(null),[speechError,setSpeechError]=useState<{id:string;message:string}|null>(null);
 const baseFont=useRef(16),generation=useRef(0),utterances=useRef<SpeechSynthesisUtterance[]>([]);
 function stop(){generation.current++;if(typeof window!=='undefined'&&'speechSynthesis'in window)window.speechSynthesis.cancel();utterances.current=[];setSpeech(null);setSpeechError(null);}
 useEffect(()=>{
  baseFont.current=parseFloat(getComputedStyle(document.documentElement).fontSize)||16;
  try{setSettings(sanitizeSettings(JSON.parse(localStorage.getItem(ACCESSIBILITY_KEY)||'null')));}catch{setStorageError(true);}setLoaded(true);
  if(!('speechSynthesis'in window))return;
  setCanSpeak(true);const synth=window.speechSynthesis,refresh=()=>setVoices(synth.getVoices());refresh();synth.addEventListener('voiceschanged',refresh);
  return()=>{synth.removeEventListener('voiceschanged',refresh);synth.cancel();};
 },[]);
 useEffect(()=>{if(!loaded)return;try{if(JSON.stringify(settings)===JSON.stringify(DEFAULT_SETTINGS))localStorage.removeItem(ACCESSIBILITY_KEY);else localStorage.setItem(ACCESSIBILITY_KEY,JSON.stringify(settings));setStorageError(false);}catch{setStorageError(true);}
  const html=document.documentElement;html.classList.toggle('af-access-text',settings.textScale!==1);html.style.setProperty('--af-access-font-size',`${baseFont.current*settings.textScale}px`);
  for(const [name,enabled] of [['af-access-reading',settings.readingSpace],['af-access-focus',settings.strongFocus],['af-access-links',settings.underlineLinks],['af-access-motion',settings.reduceMotion]] as const)html.classList.toggle(name,enabled);
 },[settings,loaded]);
 useEffect(()=>{stop();setPanelOpen(false);window.dispatchEvent(new Event('af-access-stop-input'));},[pathname]); // Stop audio when leaving a topic.
 function openSettings(){stop();window.dispatchEvent(new Event('af-access-stop-input'));setPanelOpen(true);}
 function update(patch:Partial<AccessibilitySettings>){stop();setSettings(current=>sanitizeSettings({...current,...patch}));}
 function reset(){stop();window.dispatchEvent(new Event('af-access-stop-input'));setSettings({...DEFAULT_SETTINGS});}
 function speak(text:string,language:string,id:string){
  stop();if(!canSpeak){setSpeechError({id,message:'Read aloud is unavailable in this browser.'});return;}
  const lang=speechLanguage(language),base=lang.split('-')[0].toLowerCase();
  const allowed=voices.filter(v=>!settings.localVoicesOnly||v.localService);
  const voice=settings.voiceURI?allowed.find(v=>v.voiceURI===settings.voiceURI):allowed.find(v=>v.lang.toLowerCase()===lang.toLowerCase())||allowed.find(v=>v.lang.toLowerCase().split('-')[0]===base);
  if(!voice||voice.lang.toLowerCase().split('-')[0]!==base){setSpeechError({id,message:`No matching ${lang} voice is available with your current settings. Open Voice settings to choose an installed voice, or use the visible text.`});return;}
  const synth=window.speechSynthesis,token=generation.current;const chunks=speechChunks(speechText(text,language));if(!chunks.length)return;
  setSpeech({id,paused:false});synth.resume();
  utterances.current=chunks.map((chunk,index)=>{const utterance=new SpeechSynthesisUtterance(chunk);utterance.voice=voice;utterance.lang=voice.lang;utterance.rate=settings.rate;utterance.pitch=settings.pitch;
   utterance.onend=()=>{if(token===generation.current&&index===chunks.length-1){setSpeech(null);utterances.current=[];}};
   utterance.onerror=event=>{if(token!==generation.current)return;generation.current++;synth.cancel();utterances.current=[];setSpeech(null);setSpeechError({id,message:`Speech stopped (${event.error}). Try again or choose another matching voice.`});};return utterance;});
  for(const utterance of utterances.current)synth.speak(utterance);
 }
 const value:AccessContext={settings,update,reset,openSettings,voices,canSpeak,speech,speechError,speak,stop,pause:()=>{window.speechSynthesis.pause();setSpeech(s=>s?{...s,paused:true}:null);},resume:()=>{window.speechSynthesis.resume();setSpeech(s=>s?{...s,paused:false}:null);},storageError};
 return <Context.Provider value={value}><a href="#main-content" className="af-access-skip" onClick={event=>{event.preventDefault();const main=document.querySelector('main');if(main instanceof HTMLElement){if(!main.hasAttribute('tabindex'))main.setAttribute('tabindex','-1');main.focus();main.scrollIntoView({block:'start',behavior:'auto'});}}}>Skip to main content</a>{children}<AccessibilityPanel open={panelOpen} onClose={()=>setPanelOpen(false)}/></Context.Provider>;
}
