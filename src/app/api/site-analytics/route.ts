import {NextRequest,NextResponse} from 'next/server';
import {siteAdmin} from '@/lib/analytics/site-auth';
import {siteSummary,sitePersonDetail} from '@/lib/analytics/site-store';
export const dynamic='force-dynamic';
export const runtime='nodejs';
const headers={'Cache-Control':'private, no-store'};
export async function GET(req:NextRequest){
 if(!await siteAdmin(req))return NextResponse.json({error:'Admin access required.'},{status:401,headers});
 const days=Number(req.nextUrl.searchParams.get('days')||30);if(![7,30,90].includes(days))return NextResponse.json({error:'Choose 7, 30 or 90 days.'},{status:400,headers});
 const id=req.nextUrl.searchParams.get('visitor');if(id&&!/^[a-f0-9]{64}$/.test(id))return NextResponse.json({error:'Invalid visitor.'},{status:400,headers});
 try{return NextResponse.json(id?await sitePersonDetail(id,days):await siteSummary(days),{headers});}catch{return NextResponse.json({error:'Analytics storage is temporarily unavailable. Try refresh.'},{status:503,headers});}
}
