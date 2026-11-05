import pages from './site-pages.json';
export const SITE_RETENTION_DAYS=90;
export const SITE_PATHS:Record<string,string>=pages;
export type SiteKind='pageview'|'engagement'|'run'|'pause'|'reset'|'classroom';
export const siteKinds:SiteKind[]=['pageview','engagement','run','pause','reset','classroom'];
export function sitePath(raw:unknown):string|null {
 if(typeof raw!=='string'||raw.length>180||raw.includes('?')||raw.includes('#'))return null;
 const p=raw==='/'?raw:raw.replace(/\/$/,'');return Object.hasOwn(SITE_PATHS,p)?p:null;
}
export function siteSubject(path:string){if(path.startsWith('/embed/'))return'Embedded activities';if(path.startsWith('/simulations'))return'Physics';if(path.startsWith('/geophysics'))return'Geophysics';if(path.startsWith('/mathematics'))return'Mathematics';if(path.startsWith('/chemistry'))return'Chemistry';if(path.startsWith('/biology'))return'Biology';if(path.startsWith('/minitab'))return'Minitab';return'Site navigation';}
export function dateKeys(days:number,now=Date.now()){const end=new Date(now);end.setUTCHours(0,0,0,0);return Array.from({length:days},(_,i)=>new Date(end.getTime()-(days-1-i)*86400000).toISOString().slice(0,10));}
export function csvCell(value:unknown){let s=String(value??'');if(/^[\s]*[=+\-@\t\r]/.test(s))s="'"+s;return '"'+s.replace(/"/g,'""')+'"';}
export type SiteRow={key:string;count:number};
export type SitePerson={id:string;name:string;last:number;path:string;device:string};
export type SiteEvent={t:number;kind:SiteKind;path:string;visitor:string;name:string;device:string};
export type SiteSummary={configured:boolean;days:number;views:number;visitors:number;sessions:number;seconds:number;pages:(SiteRow&{title:string;seconds:number})[];subjects:SiteRow[];devices:SiteRow[];referrers:SiteRow[];actions:SiteRow[];daily:{day:string;views:number;seconds:number}[];people:SitePerson[];recent:SiteEvent[]};
export type SitePersonDetail={person:SitePerson|null;pages:(SiteRow&{title:string;seconds:number})[];views:number;seconds:number};
