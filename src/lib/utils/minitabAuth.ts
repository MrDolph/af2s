// Shared by both the API route (Node runtime) and middleware (Edge runtime),
// so it can only use Web Crypto (`crypto.subtle`), not Node's `crypto` module
// — that's the one API guaranteed available in both environments.
//
// The cookie never stores the plaintext passcode — only this hash — so
// reading the cookie's value out of dev tools doesn't reveal the passcode
// itself. This is a classroom-level access gate, not meant to withstand a
// determined attacker; it just keeps the minitab out of the public listing
// and off search engines / casual visitors.

export async function hashPasscode(passcode: string): Promise<string> {
  const data = new TextEncoder().encode(passcode);
  const digest = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(digest))
    .map(b => b.toString(16).padStart(2, '0'))
    .join('');
}

export const MINITAB_COOKIE = 'af2s_minitab';
export const MINITAB_ADMIN_COOKIE = 'af2s_minitab_admin';
export const MINITAB_NAME_COOKIE = 'af2s_minitab_name';
