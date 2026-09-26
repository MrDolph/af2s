#!/bin/bash
# A-Factor STEM Studio — rename middleware.ts to proxy.ts (Next.js 16 convention)
# Run inside af2s/ folder: bash patches/patch-v61-middleware-to-proxy.sh
#
# Next.js 16 renamed the middleware.ts file convention to proxy.ts (the
# exported function renames too: middleware -> proxy). middleware.ts still
# works today but is deprecated, and Vercel's own migration notes warn that
# a future update could silently stop running it with no build error shown.
#
# This only affects src/middleware.ts from patch-v58 — same passcode-gate
# logic, same behavior, just the new file/function name Next.js expects.

set -e
echo "Renaming middleware.ts to proxy.ts..."

cat > src/proxy.ts << 'FILEEOF'
import { NextRequest, NextResponse } from 'next/server';
import { hashPasscode, MINITAB_COOKIE } from '@/lib/utils/minitabAuth';

export const config = {
  matcher: ['/minitab/:path*'],
};

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

  if (cookie === expectedHash) {
    return NextResponse.next();
  }

  const loginUrl = new URL('/minitab/login', req.url);
  loginUrl.searchParams.set('next', pathname);
  return NextResponse.redirect(loginUrl);
}
FILEEOF

if [ -f src/middleware.ts ]; then
  rm src/middleware.ts
  echo "  removed old src/middleware.ts"
fi

echo ""
echo "Done. src/proxy.ts now replaces src/middleware.ts."
echo "Clear your build cache and rebuild to confirm the warning is gone:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run build"
