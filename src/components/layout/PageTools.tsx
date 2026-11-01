'use client';
import { useEffect,useRef,useState } from 'react';
import { useAccessibility } from '@/components/accessibility/AccessibilityProvider';
import './floating-tools.css';
type Explainer={label:string;dialogId:string;open:boolean;onOpen:()=>void};
export function PageTools({explainer}:{explainer?:Explainer}){
 const access=useAccessibility(),[mobile,setMobile]=useState(false),[visible,setVisible]=useState(true);
 const timer=useRef<ReturnType<typeof setTimeout>|null>(null),frame=useRef<number|null>(null);
 useEffect(()=>{const query=window.matchMedia('(hover: none) and (pointer: coarse), (max-width: 767px)');const update=()=>setMobile(query.matches);update();query.addEventListener('change',update);return()=>query.removeEventListener('change',update);},[]);
 const hideWhenIdle=mobile&&access.settings.autoHideTools;
 useEffect(()=>{
  function clear(){if(timer.current!==null){clearTimeout(timer.current);timer.current=null;}}
  function reveal(){setVisible(true);clear();if(hideWhenIdle)timer.current=setTimeout(()=>setVisible(false),4000);}
  function afterTouch(){if(frame.current!==null)cancelAnimationFrame(frame.current);frame.current=requestAnimationFrame(()=>{frame.current=null;reveal();});}
  function onKey(event:KeyboardEvent){if(event.key==='Tab')reveal();}
  function onDown(event:PointerEvent){if(event.target instanceof Element&&event.target.closest('[data-af-tool]')){clear();setVisible(true);}}
  reveal();
  // Reveal after a completed touch/scroll gesture so hidden controls cannot steal its target.
  window.addEventListener('pointerup',afterTouch,{passive:true});window.addEventListener('touchend',afterTouch,{passive:true});window.addEventListener('pointerdown',onDown,{passive:true});window.addEventListener('keydown',onKey);
  return()=>{clear();if(frame.current!==null)cancelAnimationFrame(frame.current);window.removeEventListener('pointerup',afterTouch);window.removeEventListener('touchend',afterTouch);window.removeEventListener('pointerdown',onDown);window.removeEventListener('keydown',onKey);};
 },[hideWhenIdle]);
 return <div role="group" aria-label="Page tools" className={`af-floating-tools ${hideWhenIdle&&!visible?'af-tools-hidden':''}`} onFocusCapture={()=>setVisible(true)}>
  {explainer&&<button type="button" data-af-tool="explainer" aria-haspopup="dialog" aria-controls={explainer.dialogId} aria-expanded={explainer.open} onClick={explainer.onOpen} className="af-tool-button af-tool-explainer"><span aria-hidden="true">✦</span><span>{explainer.label}</span></button>}
  <button type="button" data-af-tool="accessibility" aria-label="Accessibility settings" title="Accessibility settings" aria-haspopup="dialog" onClick={access.openSettings} className="af-tool-button af-tool-accessibility"><svg aria-hidden="true" width="27" height="27" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8"><circle cx="12" cy="4" r="2"/><path d="M4 8l8 2 8-2M12 10v5M12 15l-5 6M12 15l5 6"/></svg></button>
 </div>;
}
