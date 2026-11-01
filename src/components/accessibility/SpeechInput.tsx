'use client';
import { useEffect,useRef,useState } from 'react';
import { usePathname } from 'next/navigation';
import { normalizeDictation,speechLanguage } from '@/lib/accessibility/settings';
import { useAccessibility } from './AccessibilityProvider';
type Recognition={lang:string;continuous:boolean;interimResults:boolean;onresult:((event:{resultIndex:number;results:ArrayLike<{isFinal:boolean;0:{transcript:string}}>})=>void)|null;onerror:((event:{error:string})=>void)|null;onend:(()=>void)|null;start:()=>void;stop:()=>void;abort:()=>void};
type SpeechWindow=Window&{SpeechRecognition?:new()=>Recognition;webkitSpeechRecognition?:new()=>Recognition};
export function SpeechInput({language='en',onTranscript}:{language?:string;onTranscript:(text:string)=>void}){
 const access=useAccessibility(),pathname=usePathname();const [supported,setSupported]=useState(false),[listening,setListening]=useState(false),[message,setMessage]=useState('');const recognition=useRef<Recognition|null>(null),callback=useRef(onTranscript);callback.current=onTranscript;
 function abort(){const current=recognition.current;recognition.current=null;if(current){current.onresult=null;current.onerror=null;current.onend=null;current.abort();}setListening(false);}
 useEffect(()=>{const w=window as SpeechWindow;setSupported(!!(w.SpeechRecognition||w.webkitSpeechRecognition));window.addEventListener('af-access-stop-input',abort);return()=>{window.removeEventListener('af-access-stop-input',abort);abort();};},[]);
 useEffect(()=>{abort();},[pathname,language,access.settings.voiceInput]);
 function start(){if(listening){recognition.current?.stop();return;}const w=window as SpeechWindow,Constructor=w.SpeechRecognition||w.webkitSpeechRecognition;if(!Constructor||!access.settings.voiceInput)return;
  access.stop();setMessage('');const current=new Constructor();recognition.current=current;current.lang=speechLanguage(language);current.continuous=false;current.interimResults=false;
  current.onresult=event=>{if(recognition.current!==current)return;let text='';for(let i=event.resultIndex;i<event.results.length;i++)if(event.results[i].isFinal)text+=(text?' ':'')+event.results[i][0].transcript;if(text.trim()){callback.current(normalizeDictation(text.trim(),language));setMessage('Transcribed. Review and edit the text before submitting.');}};
  current.onerror=event=>{if(recognition.current===current){setMessage(event.error==='not-allowed'?'Microphone permission was denied. You can continue typing.':`Voice input stopped (${event.error}). You can continue typing.`);setListening(false);}};
  current.onend=()=>{if(recognition.current===current){recognition.current=null;setListening(false);}};
  try{current.start();setListening(true);}catch{recognition.current=null;setListening(false);setMessage('Unable to start voice input. You can continue typing.');}
 }
 const cls='min-h-11 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-900';
 return <div className="af-access-dictation my-3"><div className="flex flex-wrap items-center gap-2"><button type="button" className={cls} onClick={access.settings.voiceInput?start:access.openSettings} disabled={!supported} aria-pressed={listening}>{listening?'Stop microphone':access.settings.voiceInput?'Speak a question':'Enable voice input'}</button>{listening&&<span role="status" className="text-sm font-semibold text-red-800">Listening…</span>}</div><p className="mt-2 text-xs leading-6 text-gray-700">{!supported?'Voice input is unavailable in this browser; typing remains available.':access.settings.voiceInput?'Only starts when you press the microphone button. Your browser may send audio to its speech provider.':'Enable voice input in Accessibility settings first. Your browser may send audio to its speech provider.'}</p>{message&&<p role="status" className="mt-2 text-xs leading-6 text-gray-800">{message}</p>}</div>;
}
