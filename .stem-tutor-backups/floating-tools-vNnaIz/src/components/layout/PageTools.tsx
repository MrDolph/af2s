'use client';
import { useAccessibility } from '@/components/accessibility/AccessibilityProvider';
type Explainer={label:string;dialogId:string;open:boolean;onOpen:()=>void};
export function PageTools({explainer}:{explainer?:Explainer}){
 const access=useAccessibility();
 const button='inline-flex min-h-11 min-w-0 items-center justify-center gap-2 rounded-xl border px-3 py-2 text-center text-sm font-medium leading-5 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-700';
 return <div className="af-page-tools shrink-0 border-b border-gray-200 bg-white px-3 py-2 text-gray-900 sm:px-6" style={{colorScheme:'light'}}><div role="group" aria-label="Page tools" className={`mx-auto grid min-w-0 max-w-7xl gap-2 ${explainer?'grid-cols-2':'grid-cols-1'} sm:flex sm:flex-wrap sm:justify-end`}>
  {explainer&&<button type="button" aria-haspopup="dialog" aria-controls={explainer.dialogId} aria-expanded={explainer.open} onClick={explainer.onOpen} className={`${button} border-indigo-200 bg-indigo-50 text-indigo-900`}><span aria-hidden="true">✦</span><span className="min-w-0 break-words">{explainer.label}</span></button>}
  <button type="button" aria-haspopup="dialog" onClick={access.openSettings} className={`${button} border-gray-300 bg-white text-gray-900`}><svg aria-hidden="true" width="19" height="19" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" className="shrink-0"><circle cx="12" cy="4" r="2"/><path d="M4 8l8 2 8-2M12 10v5M12 15l-5 6M12 15l5 6"/></svg><span className="min-w-0 break-words">Accessibility</span></button>
 </div></div>;
}
