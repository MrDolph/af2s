import { NextRequest, NextResponse } from 'next/server';
import { getAnalyticsSummary } from '@/lib/analytics/redis';
import { siteAdmin } from '@/lib/analytics/site-auth';
export const dynamic='force-dynamic';
export async function GET(req:NextRequest) {
 if(!await siteAdmin(req))return NextResponse.json({error:'Admin access required.'},{status:401,headers:{'Cache-Control':'private, no-store'}});
 return NextResponse.json(await getAnalyticsSummary(),{headers:{'Cache-Control':'private, no-store'}});
}
