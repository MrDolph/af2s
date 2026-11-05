import { NextRequest, NextResponse } from 'next/server';
import { recordVisit } from '@/lib/analytics/redis';
import { analyticsName, optedOut, siteAdmin } from '@/lib/analytics/site-auth';
import { SITE_PATHS } from '@/lib/analytics/site-model';

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function POST(req: NextRequest) {
  try {
    if(req.headers.get('origin')!==new URL(req.url).origin)return NextResponse.json({ok:false},{status:403});
    if(optedOut(req)||await siteAdmin(req))return NextResponse.json({ok:true});
    const verifiedName=await analyticsName(req);if(!verifiedName)return NextResponse.json({ok:false},{status:401});
    const body = (await req.json()) as { slug?: string };
    if (!body.slug || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'slug is required.' }, { status: 400 });
    }
    const sessionId = req.cookies.get(SESSION_COOKIE)?.value;
    if(!Object.hasOwn(SITE_PATHS,body.slug==='hub'?'/minitab':'/minitab/'+body.slug))return NextResponse.json({ok:false},{status:400});
    // Best-effort — never blocks or errors out the page for the student if
    // this fails; a missed analytics beacon is not worth a broken page.
    await recordVisit(body.slug, sessionId, verifiedName);

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error('[minitab-track] Error', error);
    return NextResponse.json({ ok: false });
  }
}
