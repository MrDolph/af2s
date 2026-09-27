import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_ADMIN_COOKIE } from '@/lib/utils/minitabAuth';

export async function POST(req: NextRequest) {
  try {
    const body = (await req.json()) as { passcode?: string };
    const expected = process.env.MINITAB_ADMIN_PASSCODE;

    if (!expected) {
      console.error('[minitab-admin-auth] MINITAB_ADMIN_PASSCODE is not set in the environment.');
      return NextResponse.json({ error: 'Admin access is not configured yet.' }, { status: 500 });
    }
    if (!body.passcode || typeof body.passcode !== 'string') {
      return NextResponse.json({ error: 'Passcode is required.' }, { status: 400 });
    }
    if (body.passcode !== expected) {
      return NextResponse.json({ error: 'Incorrect passcode.' }, { status: 401 });
    }

    const token = await hashPasscode(expected);
    const res = NextResponse.json({ ok: true });
    res.cookies.set(MINITAB_ADMIN_COOKIE, token, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 30,
    });
    return res;
  } catch (error) {
    console.error('[minitab-admin-auth] Error', error);
    return NextResponse.json({ error: 'Something went wrong.' }, { status: 500 });
  }
}

export async function DELETE() {
  const res = NextResponse.json({ ok: true });
  res.cookies.set(MINITAB_ADMIN_COOKIE, '', {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: 0,
  });
  return res;
}
