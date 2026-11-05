import {NextRequest,NextResponse} from 'next/server';
import {sitePath,siteKinds,type SiteKind} from '@/lib/analytics/site-model';
import {recordSite,siteRedis} from '@/lib/analytics/site-store';
import {analyticsName,analyticsSecret,analyticsVisitorKey,optedOut,signedAnalyticsId,siteAdmin,SITE_VISITOR_COOKIE,SITE_SESSION_COOKIE,SITE_OPTOUT_COOKIE} from '@/lib/analytics/site-auth';
export const runtime='nodejs';
const noStore={'Cache-Control':'private, no-store'};
function response(data:object,status=200){return NextResponse.json(data,{status,headers:noStore});}
function sameOrigin(req:NextRequest){return req.headers.get('origin')===new URL(req.url).origin;}
const uuid=(s:unknown):s is string=>typeof s==='string'&&/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(s);
export async function POST(req:NextRequest){
 if(!sameOrigin(req))return response({error:'Origin rejected.'},403);
 if(optedOut(req)||/bot|spider|crawl|headless|preview|lighthouse/i.test(req.headers.get('user-agent')||''))return response({accepted:false});
 if(!analyticsSecret()||!siteRedis())return response({accepted:false,configured:false});
 try{
  if(await siteAdmin(req))return response({accepted:false});
  const text=await req.text();if(text.length>2048)return response({error:'Event too large.'},413);
  let b;try{b=JSON.parse(text);}catch{return response({error:'Invalid JSON.'},400);}if(!b||typeof b!=='object'||Array.isArray(b))return response({error:'Invalid event.'},400);const path=sitePath(b.path);
  if(!path||!uuid(b.id)||!uuid(b.viewId)||!siteKinds.includes(b.kind))return response({error:'Invalid event.'},400);
  const visitor=signedAnalyticsId(req.cookies.get(SITE_VISITOR_COOKIE)?.value),session=signedAnalyticsId(req.cookies.get(SITE_SESSION_COOKIE)?.value);
  const ua=req.headers.get('user-agent')||'';const device=/ipad|tablet/i.test(ua)?'Tablet':/mobile|android|iphone/i.test(ua)?'Mobile':'Desktop / other';
  let referrer='Direct / internal';try{const url=new URL(String(b.referrer||''));if(['http:','https:'].includes(url.protocol)&&url.origin!==new URL(req.url).origin)referrer=url.hostname.slice(0,100);}catch{}
  const seconds=typeof b.seconds==='number'&&Number.isFinite(b.seconds)?Math.max(0,Math.min(1800,Math.floor(b.seconds))):0;
  const result=await recordSite({id:b.id,viewId:b.viewId,visitor:analyticsVisitorKey(visitor.id),session:analyticsVisitorKey(session.id),path,kind:b.kind as SiteKind,seconds,name:await analyticsName(req),device,referrer});
  if(result===-1)return response({accepted:false},429);
  const res=response({accepted:true});const opts={httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax' as const,path:'/'};
  if(visitor.fresh)res.cookies.set(SITE_VISITOR_COOKIE,visitor.cookie,{...opts,maxAge:90*86400});
  res.cookies.set(SITE_SESSION_COOKIE,session.cookie,{...opts,maxAge:1800});return res;
 }catch{return response({accepted:false},503);}
}
export async function DELETE(req:NextRequest){
 if(!sameOrigin(req))return response({error:'Origin rejected.'},403);
 const res=response({ok:true});const opts={httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax' as const,path:'/'};
 res.cookies.set(SITE_VISITOR_COOKIE,'',{...opts,maxAge:0});res.cookies.set(SITE_SESSION_COOKIE,'',{...opts,maxAge:0});res.cookies.set(SITE_OPTOUT_COOKIE,'1',{...opts,maxAge:365*86400});return res;
}
export async function PUT(req:NextRequest){
 if(!sameOrigin(req))return response({error:'Origin rejected.'},403);
 const res=response({ok:true});res.cookies.set(SITE_OPTOUT_COOKIE,'',{httpOnly:true,secure:process.env.NODE_ENV==='production',sameSite:'lax',path:'/',maxAge:0});return res;
}
