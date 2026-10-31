'use client';
import { useEffect } from 'react';
import { presetFromSearch } from './prepare';
export function useTopicPreset(id:string,numeric:Record<string,(value:number)=>void>,modes:Record<string,(value:string)=>void>={}) {
 useEffect(()=>{
  const preset=presetFromSearch(id,window.location.search);if(!preset)return;
  for(const [key,value] of Object.entries(preset.params))numeric[key]?.(value);
  for(const [key,value] of Object.entries(preset.modes))modes[key]?.(value);
  // Initial URL settings only. Normal in-page controls remain authoritative afterwards.
  // eslint-disable-next-line react-hooks/exhaustive-deps
 },[]);
}
