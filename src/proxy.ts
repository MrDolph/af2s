import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';

export const config = {
  matcher: ['/minitab/:path*'],
};

const SESSION_COOKIE = 'af2s_minitab_sid';

export async function proxy(req: NextRequest) {
  const { pathname } = req.nextUrl;

  // The login page and its own auth API call must stay reachable — otherwise
  // nobody could ever get past the gate to enter the passcode in the first place.
  if (pathname === '/minitab/login') {
    return NextResponse.next();
  }

  const expected = process.env.MINITAB_PASSCODE;
  if (!expected) {
    // Fails safe: with no passcode configured, don't silently expose the
    // section — send visitors to the login page, which will show a clear
    // "not configured yet" error instead of a confusing 500 deeper in the app.
    return NextResponse.redirect(new URL('/minitab/login', req.url));
  }

  const cookie = req.cookies.get(MINITAB_COOKIE)?.value;
  const expectedHash = await hashPasscode(expected);

  if (cookie !== expectedHash) {
    const loginUrl = new URL('/minitab/login', req.url);
    loginUrl.searchParams.set('next', pathname);
    return NextResponse.redirect(loginUrl);
  }

  const res = NextResponse.next();

  // Anonymous per-browser session id, used only to count distinct visitors
  // on the analytics dashboard — never tied to a name or any other identity.
  if (!req.cookies.get(SESSION_COOKIE)) {
    const sid = crypto.randomUUID();
    res.cookies.set(SESSION_COOKIE, sid, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'lax',
      path: '/',
      maxAge: 60 * 60 * 24 * 365, // a year — session counts are more meaningful if they don't churn every month
    });
  }

  return res;
}
