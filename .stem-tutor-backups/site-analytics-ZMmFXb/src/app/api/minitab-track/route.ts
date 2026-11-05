import { NextRequest, NextResponse } from 'next/server';
import { recordVisit } from '@/lib/analytics/redis';
import { MINITAB_NAME_COOKIE } from '@/lib/utils/minitabAuth';

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { slug?: string };
    if (!body.slug || typeof body.slug !== 'string') {
      return NextResponse.json({ error: 'slug is required.' }, { status: 400 });
    }
    const sessionId = req.cookies.get(SESSION_COOKIE)?.value;
    const nameCookie = req.cookies.get(MINITAB_NAME_COOKIE)?.value;
    const name = nameCookie ? decodeURIComponent(nameCookie) : undefined;

    // Best-effort — never blocks or errors out the page for the student if
    // this fails; a missed analytics beacon is not worth a broken page.
    recordVisit(body.slug, sessionId, name);

    return NextResponse.json({ ok: true });
  } catch (error) {
    console.error('[minitab-track] Error', error);
    return NextResponse.json({ ok: false });
  }
}
