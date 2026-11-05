'use client';
import {useEffect,useRef,useState} from 'react';
import {usePathname} from 'next/navigation';
import {sitePath,type SiteKind} from '@/lib/analytics/site-model';
const OPT='afactor-analytics-opt-out-v1';
export function analyticsAllowed(){try{return navigator.doNotTrack!=='1'&&!(navigator as Navigator&{globalPrivacyControl?:boolean}).globalPrivacyControl&&localStorage.getItem(OPT)!=='1';}catch{return false;}}
// Serialising beacons lets the first response set the browser cookie before later events.
let queue:Promise<unknown>=Promise.resolve();
function send(body:object){const task=queue.then(async()=>{if(!analyticsAllowed())return false;try{const r=await fetch('/api/site-track',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body),keepalive:true});return r.ok&&(await r.json()).accepted===true;}catch{return false;}});queue=task.catch(()=>false);return task;}
export function SiteAnalyticsTracker(){
 const pathname=usePathname();const [preference,setPreference]=useState(0);const page=useRef<{path:string;id:string}|null>(null);
 useEffect(()=>{const change=()=>{page.current=null;setPreference(n=>n+1);};window.addEventListener('afactor-analytics-preference',change);return()=>window.removeEventListener('afactor-analytics-preference',change);},[]);
 useEffect(()=>{
  if(!sitePath(pathname)||!analyticsAllowed())return;
  if(page.current?.path!==pathname)page.current={path:pathname,id:crypto.randomUUID()};
  const viewId=page.current.id;const referrer=document.referrer;let milliseconds=0,last=performance.now(),visible=document.visibilityState==='visible'&&document.hasFocus();
  const accepted=send({kind:'pageview',path:pathname,id:viewId,viewId,referrer});
  function accrue(){const now=performance.now();if(visible)milliseconds+=Math.max(0,now-last);last=now;}
  function flush(){accrue();const seconds=Math.min(1800,Math.floor(milliseconds/1000));if(seconds>0)void accepted.then(ok=>ok&&send({kind:'engagement',path:pathname,id:crypto.randomUUID(),viewId,seconds}));}
  function visibility(){flush();visible=document.visibilityState==='visible'&&document.hasFocus();last=performance.now();}
  function action(e:MouseEvent){const button=(e.target as Element|null)?.closest('button');if(!button?.closest('[data-simulation-stage]'))return;const label=button.textContent?.trim()||'';let kind:SiteKind|undefined;
   if(/^(?:▶\s*)?run$/i.test(label))kind='run';else if(/pause|resume/i.test(label))kind='pause';else if(/reset/i.test(label))kind='reset';else if(/expand simulation|exit classroom/i.test(label))kind='classroom';
   if(kind)void accepted.then(ok=>ok&&send({kind,path:pathname,id:crypto.randomUUID(),viewId}));
  }
  const timer=setInterval(flush,60000);document.addEventListener('visibilitychange',visibility);window.addEventListener('focus',visibility);window.addEventListener('blur',visibility);window.addEventListener('pagehide',flush);document.addEventListener('click',action);
  return()=>{flush();clearInterval(timer);document.removeEventListener('visibilitychange',visibility);window.removeEventListener('focus',visibility);window.removeEventListener('blur',visibility);window.removeEventListener('pagehide',flush);document.removeEventListener('click',action);};
 },[pathname,preference]);return null;
}
