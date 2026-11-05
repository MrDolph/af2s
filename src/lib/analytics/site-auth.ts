import {createHmac,randomUUID,timingSafeEqual} from 'node:crypto';
import type {NextRequest} from 'next/server';
import {hashPasscode,MINITAB_ADMIN_COOKIE,MINITAB_COOKIE,MINITAB_NAME_COOKIE} from '@/lib/utils/minitabAuth';
export const SITE_VISITOR_COOKIE='af_site_vid',SITE_SESSION_COOKIE='af_site_sid',SITE_OPTOUT_COOKIE='af_analytics_optout';
export function analyticsSecret(){return process.env.ANALYTICS_HASH_SECRET||process.env.MINITAB_ADMIN_PASSCODE||'';}
export function sameSecret(a:string,b:string){const x=Buffer.from(a),y=Buffer.from(b);return x.length===y.length&&timingSafeEqual(x,y);}
export async function siteAdmin(req:NextRequest){const pass=process.env.MINITAB_ADMIN_PASSCODE;return !!pass&&sameSecret(req.cookies.get(MINITAB_ADMIN_COOKIE)?.value||'',await hashPasscode(pass));}
function mac(value:string){return createHmac('sha256',analyticsSecret()).update(value).digest('hex');}
export function signedAnalyticsId(cookie:string|undefined){
 if(cookie){const [id,signature]=cookie.split('.');if(/^[a-f0-9-]{36}$/.test(id||'')&&sameSecret(signature||'',mac(id)))return {id,cookie,fresh:false};}
 const id=randomUUID();return{id,cookie:id+'.'+mac(id),fresh:true};
}
export function analyticsVisitorKey(id:string){return mac('visitor:'+id);}
export async function analyticsName(req:NextRequest){
 const pass=process.env.MINITAB_PASSCODE;if(!pass||!sameSecret(req.cookies.get(MINITAB_COOKIE)?.value||'',await hashPasscode(pass)))return'';
 try{return decodeURIComponent(req.cookies.get(MINITAB_NAME_COOKIE)?.value||'').replace(/[\x00-\x1f\x7f]/g,'').trim().replace(/\s+/g,' ').slice(0,40);}catch{return'';}
}
export function optedOut(req:NextRequest){return req.cookies.get(SITE_OPTOUT_COOKIE)?.value==='1'||req.headers.get('dnt')==='1'||req.headers.get('sec-gpc')==='1';}
