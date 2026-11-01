export const ACCESSIBILITY_KEY='afactor-accessibility-v1';
export type AccessibilitySettings={textScale:number;readingSpace:boolean;strongFocus:boolean;underlineLinks:boolean;reduceMotion:boolean;rate:number;pitch:number;voiceURI:string;localVoicesOnly:boolean;voiceInput:boolean;autoHideTools:boolean};
export const DEFAULT_SETTINGS:AccessibilitySettings={textScale:1,readingSpace:false,strongFocus:false,underlineLinks:false,reduceMotion:false,rate:1,pitch:1,voiceURI:'',localVoicesOnly:true,voiceInput:false,autoHideTools:true};
export function sanitizeSettings(value:unknown):AccessibilitySettings {
 const v=value&&typeof value==='object'?value as Record<string,unknown>:{};
 const numeric=(key:keyof AccessibilitySettings,min:number,max:number)=>typeof v[key]==='number'&&Number.isFinite(v[key])?Math.min(max,Math.max(min,v[key] as number)):DEFAULT_SETTINGS[key] as number;
 const bool=(key:keyof AccessibilitySettings)=>typeof v[key]==='boolean'?v[key] as boolean:DEFAULT_SETTINGS[key] as boolean;
 return {textScale:numeric('textScale',1,1.5),readingSpace:bool('readingSpace'),strongFocus:bool('strongFocus'),underlineLinks:bool('underlineLinks'),reduceMotion:bool('reduceMotion'),rate:numeric('rate',.6,1.5),pitch:numeric('pitch',.8,1.2),voiceURI:typeof v.voiceURI==='string'?v.voiceURI.slice(0,500):'',localVoicesOnly:bool('localVoicesOnly'),voiceInput:bool('voiceInput'),autoHideTools:bool('autoHideTools')};
}
export function speechLanguage(language:string){return ({en:'en-NG',yo:'yo-NG',ha:'ha-NG',ig:'ig-NG'} as Record<string,string>)[language]||language||'en-NG';}
export function speechText(text:string,language:string){
 if(!language.startsWith('en'))return text;
 return text.replace(/F\s*=\s*ma\b/g,' force equals mass times acceleration ').replace(/V\s*=\s*IR\b/g,' voltage equals current times resistance ').replace(/v\s*=\s*fλ/g,' wave speed equals frequency times wavelength ').replace(/m\/s²/g,' metres per second squared ').replace(/m\/s/g,' metres per second ').replace(/²/g,' squared ').replace(/³/g,' cubed ').replace(/₀/g,' zero ').replace(/₁/g,' one ').replace(/₂/g,' two ').replace(/λ/g,' wavelength ').replace(/θ/g,' theta ').replace(/π/g,' pi ').replace(/Ω/g,' ohms ').replace(/×/g,' times ').replace(/÷/g,' divided by ').replace(/=/g,' equals ').replace(/−/g,' minus ');
}
export function speechChunks(text:string,max=300){const words=text.replace(/\s+/g,' ').trim().split(' ');const chunks:string[]=[];let chunk='';for(const word of words){if(chunk&&chunk.length+word.length+1>max){chunks.push(chunk);chunk='';}chunk+=(chunk?' ':'')+word;}if(chunk)chunks.push(chunk);return chunks;}
export function normalizeDictation(text:string,language:string){if(!language.startsWith('en'))return text;return text.replace(/\bvolts?\b/gi,'V').replace(/\bnewtons?\b/gi,'N').replace(/\bkilograms?\b/gi,'kg').replace(/\bhertz\b/gi,'Hz').replace(/\bmet(?:re|er)s? per second\b/gi,'m/s').replace(/\bequals?\b/gi,'=');}
