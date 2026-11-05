import {Redis} from '@upstash/redis';
import {SITE_PATHS,SITE_RETENTION_DAYS,dateKeys,siteSubject,type SiteKind,type SiteRow,type SiteSummary,type SitePerson,type SitePersonDetail,type SiteEvent} from './site-model';
const P='afsite:v1:',TTL=95*86400;
let client:Redis|null=null;
export function siteRedis(){
 if(client)return client;
 const url=process.env.UPSTASH_REDIS_REST_URL??process.env.KV_REST_API_URL,token=process.env.UPSTASH_REDIS_REST_TOKEN??process.env.KV_REST_API_TOKEN;
 if(!url||!token)return null;
 client=new Redis({url,token,signal:()=>AbortSignal.timeout(5000)});return client;
}
// One atomic update prevents duplicate beacons and concurrent time reports from overcounting.
export const RECORD_SITE_LUA=`
local e=cjson.decode(ARGV[1])
local n=redis.call('INCR',KEYS[1]); redis.call('EXPIRE',KEYS[1],70)
if n>120 then return -1 end
if not redis.call('SET',KEYS[2],'1','NX','EX',600) then return 0 end
if e.kind=='engagement' then
 if redis.call('HGET',KEYS[3],'visitor')~=e.visitor or redis.call('HGET',KEYS[3],'path')~=e.path then return 0 end
 local prior=tonumber(redis.call('HGET',KEYS[3],'seconds') or '0')
 local seconds=math.min(1800,math.max(0,math.floor(e.seconds)))
 local delta=seconds-prior
 if delta<=0 then return 0 end
 redis.call('HSET',KEYS[3],'seconds',seconds)
 redis.call('HINCRBY',KEYS[4],'seconds',delta)
 redis.call('HINCRBY',KEYS[6],e.path,delta)
 redis.call('HINCRBY',KEYS[13],e.path,delta)
 for _,i in ipairs({4,6,13}) do redis.call('EXPIRE',KEYS[i],e.ttl) end
 return 1
end
if e.kind=='pageview' then
 if redis.call('EXISTS',KEYS[3])==1 then return 0 end
 redis.call('HSET',KEYS[3],'visitor',e.visitor,'path',e.path,'seconds',0)
 redis.call('EXPIRE',KEYS[3],86400)
 redis.call('HINCRBY',KEYS[4],'views',1)
 redis.call('HINCRBY',KEYS[5],e.path,1)
 redis.call('HINCRBY',KEYS[7],e.subject,1)
 redis.call('HINCRBY',KEYS[8],e.device,1)
 redis.call('HINCRBY',KEYS[9],e.referrer,1)
 redis.call('PFADD',KEYS[10],e.visitor)
 redis.call('PFADD',KEYS[11],e.session)
 redis.call('HINCRBY',KEYS[12],e.path,1)
 for _,i in ipairs({4,5,7,8,9,10,11,12}) do redis.call('EXPIRE',KEYS[i],e.ttl) end
else
 redis.call('HINCRBY',KEYS[4],e.kind,1); redis.call('EXPIRE',KEYS[4],e.ttl)
end
redis.call('HSET',KEYS[14],'id',e.visitor,'name',e.name,'last',e.t,'path',e.path,'device',e.device)
redis.call('EXPIRE',KEYS[14],e.ttl)
redis.call('ZADD',KEYS[15],e.t,e.visitor)
redis.call('ZREMRANGEBYSCORE',KEYS[15],'-inf',e.cutoff)
redis.call('EXPIRE',KEYS[15],e.ttl)
redis.call('LPUSH',KEYS[16],cjson.encode({t=e.t,kind=e.kind,path=e.path,visitor=e.visitor,name=e.name,device=e.device}))
redis.call('LTRIM',KEYS[16],0,199); redis.call('EXPIRE',KEYS[16],e.ttl)
return 1`;
export type SiteRecord={id:string;viewId:string;visitor:string;session:string;path:string;kind:SiteKind;seconds:number;name:string;device:string;referrer:string};
export async function recordSite(e:SiteRecord,redis=siteRedis(),now=Date.now()){
 if(!redis)return null;const day=new Date(now).toISOString().slice(0,10);
 const keys=[P+'rate:'+e.session+':'+Math.floor(now/60000),P+'dedupe:'+e.session+':'+e.id,P+'view:'+e.viewId,P+'day:'+day,P+'pages:'+day,P+'page-time:'+day,P+'subjects:'+day,P+'devices:'+day,P+'refs:'+day,P+'visitors:'+day,P+'sessions:'+day,P+'person-pages:'+day+':'+e.visitor,P+'person-time:'+day+':'+e.visitor,P+'person:'+e.visitor,P+'people',P+'recent'];
 return Number(await redis.eval(RECORD_SITE_LUA,keys,[JSON.stringify({...e,t:now,ttl:TTL,cutoff:now-SITE_RETENTION_DAYS*86400000,subject:siteSubject(e.path)})]));
}
function sum(records:unknown[]){const result:Record<string,number>=Object.create(null);for(const record of records)for(const [key,value]of Object.entries((record||{})as Record<string,unknown>)){const n=Number(value);if(Number.isFinite(n))result[key]=(result[key]||0)+n;}return result;}
function rows(counts:Record<string,number>):SiteRow[]{return Object.entries(counts).map(([key,count])=>({key,count})).sort((a,b)=>b.count-a.count);}
function person(raw:unknown):SitePerson|null{if(!raw||typeof raw!=='object')return null;const p=raw as Record<string,unknown>;if(!p.id)return null;return{id:String(p.id),name:String(p.name||''),last:Number(p.last)||0,path:String(p.path||''),device:String(p.device||'')};}
export async function siteSummary(days:number,redis=siteRedis()):Promise<SiteSummary>{
 const dates=dateKeys(days);const empty:SiteSummary={configured:false,days,views:0,visitors:0,sessions:0,seconds:0,pages:[],subjects:[],devices:[],referrers:[],actions:[],daily:[],people:[],recent:[]};if(!redis)return empty;
 const pipeline=redis.pipeline();for(const day of dates)for(const group of ['day:','pages:','page-time:','subjects:','devices:','refs:'])pipeline.hgetall(P+group+day);
 const raw=await pipeline.exec();const group=(n:number)=>dates.map((_,i)=>raw[i*6+n]);const totals=sum(group(0)),pageTime=sum(group(2));
 const [visitors,sessions,ids,recentRaw]=await Promise.all([redis.pfcount(P+'visitors:'+dates[0],...dates.slice(1).map(d=>P+'visitors:'+d)),redis.pfcount(P+'sessions:'+dates[0],...dates.slice(1).map(d=>P+'sessions:'+d)),redis.zrange<string[]>(P+'people','+inf',Date.parse(dates[0]+'T00:00:00Z'),{byScore:true,rev:true,offset:0,count:200}),redis.lrange(P+'recent',0,199)]);
 const peoplePipeline=redis.pipeline();for(const id of ids)peoplePipeline.hgetall(P+'person:'+id);const people=ids.length?(await peoplePipeline.exec()).map(person).filter((p):p is SitePerson=>!!p):[];
 const recent:SiteEvent[]=recentRaw.map(r=>typeof r==='string'?JSON.parse(r):r).filter((e:SiteEvent)=>e.t>=Date.parse(dates[0]+'T00:00:00Z')).slice(0,100);
 return{...empty,configured:true,views:totals.views||0,seconds:totals.seconds||0,visitors:Number(visitors),sessions:Number(sessions),pages:rows(sum(group(1))).map(r=>({...r,title:SITE_PATHS[r.key]||r.key,seconds:pageTime[r.key]||0})),subjects:rows(sum(group(3))),devices:rows(sum(group(4))),referrers:rows(sum(group(5))),actions:['run','pause','reset','classroom'].map(key=>({key,count:totals[key]||0})),daily:dates.map((day,i)=>({day,views:Number((raw[i*6]as Record<string,number>|null)?.views)||0,seconds:Number((raw[i*6]as Record<string,number>|null)?.seconds)||0})),people,recent};
}
export async function sitePersonDetail(id:string,days:number,redis=siteRedis()):Promise<SitePersonDetail>{
 if(!redis)return{person:null,pages:[],views:0,seconds:0};const dates=dateKeys(days),p=redis.pipeline();for(const day of dates){p.hgetall(P+'person-pages:'+day+':'+id);p.hgetall(P+'person-time:'+day+':'+id);}const data=await p.exec(),views=sum(data.filter((_,i)=>i%2===0)),times=sum(data.filter((_,i)=>i%2===1));return{person:person(await redis.hgetall(P+'person:'+id)),pages:rows(views).map(r=>({...r,title:SITE_PATHS[r.key]||r.key,seconds:times[r.key]||0})),views:Object.values(views).reduce((a,b)=>a+b,0),seconds:Object.values(times).reduce((a,b)=>a+b,0)};
}
