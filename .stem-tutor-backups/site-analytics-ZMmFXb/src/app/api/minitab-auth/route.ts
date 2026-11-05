import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE, MINITAB_NAME_COOKIE } from '@/lib/utils/minitabAuth';
import { recordLogin, sanitizeName } from '@/lib/analytics/redis';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { passcode?: string; name?: string };
    const expected = process.env.MINITAB_PASSCODE;

    if (!expected) {
      console.error('[minitab-auth] MINITAB_PASSCODE is not set in the environment.');
      return NextResponse.json({ error: 'Access is not configured yet.' }, { status: 500 });
    }
    if (!body.passcode || typeof body.passcode !== 'string') {
      return NextResponse.json({ error: 'Passcode is required.' }, { status: 400 });
    }
    const name = sanitizeName(typeof body.name === 'string' ? body.name : '');
    if (!name) {
      return NextResponse.json({ error: 'Please enter your name.' }, { status: 400 });
    }
    if (body.passcode !== expected) {
      return NextResponse.json({ error: 'Incorrect passcode.' }, { status: 401 });
    }

    const token = await hashPasscode(expected);
    const res = NextResponse.json({ ok: true });
    res.cookies.set(MINITAB_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30, // 30 days — students shouldn't need to re-enter it every visit
    });
    // Readable by client JS is unnecessary here — only the server (tracking
    // routes) needs this, so it stays httpOnly like the access cookie.
    res.cookies.set(MINITAB_NAME_COOKIE, encodeURIComponent(name), {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30,
    });

    // Best-effort, never blocks the login response if analytics isn't configured or fails.
    recordLogin(name);

    return res;
  } catch (error) {
    console.error('[minitab-auth] Error', error);
    return NextResponse.json({ error: 'Something went wrong.' }, { status: 500 });
  }
}

// Logout: clear the access cookie. Using DELETE keeps this in the same route
// as POST (login) — one file for the whole "session" resource — rather than
// a second, separate endpoint.
export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(MINITAB_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0, // expire immediately
  });
  res.cookies.set(MINITAB_NAME_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  });
  return res;
}
