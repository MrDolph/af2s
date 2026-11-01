'use client';
import { useId } from 'react';
import { useAccessibility } from './AccessibilityProvider';
export function ReadAloud({text,language='en'}:{text:string;language?:string}){
 const id=useId(),access=useAccessibility(),active=access.speech?.id===id;const error=access.speechError?.id===id?access.speechError.message:null;
 const cls='min-h-11 rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-900 hover:bg-gray-50';
 return <div className="af-access-read my-3" aria-label="Read aloud controls"><div className="flex flex-wrap gap-2"><button type="button" className={cls} onClick={()=>access.speak(text,language,id)} disabled={!access.canSpeak}>Read aloud</button>{active&&<><button type="button" className={cls} onClick={access.speech?.paused?access.resume:access.pause}>{access.speech?.paused?'Resume':'Pause'}</button><button type="button" className={cls} onClick={access.stop}>Stop</button></>}<button type="button" className={cls} onClick={access.openSettings}>Voice settings</button></div>{!access.canSpeak&&<p className="mt-2 text-xs leading-5 text-gray-700">Read aloud is unavailable in this browser.</p>}{error&&<p role="status" className="mt-2 text-xs leading-6 text-amber-900">{error}</p>}</div>;
}
