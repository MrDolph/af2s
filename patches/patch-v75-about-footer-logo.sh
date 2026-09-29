#!/bin/bash
# A-Factor STEM Studio — crest logo in the About page footer
# Run inside af2s/ (the project ROOT, not inside patches/), AFTER v73:
#     bash patches/patch-v75-about-footer-logo.sh
#
# WHY THIS EXISTS
#   v74 fixed the logo in the main navbar. There was a THIRD copy of the same
#   placeholder (an indigo box with a generic diamond SVG) hardcoded into the
#   About page's own footer, separate from both the navbar and the favicon
#   files - I checked every page in the project for a <footer> and this is
#   the only one with a logo in it (the two simulation-page footers are plain
#   text/links, nothing to change there).
#
# WHAT IT CHANGES (targeted, idempotent, CRLF/LF-aware - never a full overwrite):
#   src/app/about/page.tsx
#     - adds: import Image from 'next/image';   (only if not already imported)
#     - replaces the footer's hardcoded indigo-box SVG with <Image src="/icon.png" .../>

set -e

if [ ! -f package.json ] || [ ! -d src ]; then
  echo "ERROR: run this from your project root (the folder containing package.json and src/),"
  echo "       e.g.   cd af2s   then   bash patches/patch-v75-about-footer-logo.sh"
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: 'node' was not found on your PATH. It is needed for this patch's edit."
  exit 1
fi
if [ ! -f src/app/icon.png ]; then
  echo "ERROR: src/app/icon.png was not found."
  echo "       This patch reuses that file - run patches/patch-v73-site-icon.sh first."
  exit 1
fi
if [ ! -f src/app/about/page.tsx ]; then
  echo "ERROR: src/app/about/page.tsx was not found."
  exit 1
fi

echo "Applying About page footer logo patch..."

node - << 'NODEEOF'
const fs = require('fs');
const p = 'src/app/about/page.tsx';
let s = fs.readFileSync(p, 'utf8');
const nl = s.includes('\r\n') ? '\r\n' : '\n';

if (/<Image\s+src="\/icon\.png"/.test(s)) {
  console.log('  About page footer already uses the crest logo - skipping');
} else {
  // 1. import (only add if genuinely missing - this file may already import
  //    Image for something else, e.g. a team photo)
  if (!/from\s+['"]next\/image['"]/.test(s)) {
    const m = /^import\s.+\sfrom\s+['"][^'"]+['"];?[ \t]*\r?\n/m.exec(s);
    if (!m) {
      console.log("  ERROR: couldn't find any import line to anchor on. Add this import by"
        + " hand:  import Image from 'next/image';");
      process.exit(1);
    }
    // anchor after the LAST top-of-file import, not just the first
    let last = m, mm, re2 = /^import\s.+\sfrom\s+['"][^'"]+['"];?[ \t]*\r?\n/gm, idx = 0;
    while ((mm = re2.exec(s)) !== null) { last = mm; idx = mm.index; }
    const at = idx + last[0].length;
    s = s.slice(0, at) + "import Image from 'next/image';" + nl + s.slice(at);
  }

  // 2. footer logo block — matched loosely (whitespace-insensitive) so minor
  //    formatting differences don't stop the patch from finding it.
  const re = /<div className="h-5 w-5 rounded bg-indigo-600 flex items-center justify-center">\s*<svg[^>]*viewBox="0 0 14 14"[^>]*>[\s\S]*?<\/svg>\s*<\/div>/;
  const m2 = re.exec(s);
  if (!m2) {
    console.log("  ERROR: couldn't find the placeholder footer logo block (it may already be edited).");
    console.log("         Replace it by hand with:");
    console.log('           <Image src="/icon.png" alt="A-Factor STEM Studio" width={20} height={20}');
    console.log('             className="h-5 w-5 rounded" />');
    process.exit(1);
  }
  const replacement = '<Image src="/icon.png" alt="A-Factor STEM Studio" width={20} height={20}' + nl
    + '                className="h-5 w-5 rounded" />';
  s = s.slice(0, m2.index) + replacement + s.slice(m2.index + m2[0].length);

  fs.writeFileSync(p, s, 'utf8');
  console.log('  About page footer: logo now uses /icon.png');
}

// ── Checklist ────────────────────────────────────────────────────────
console.log('');
console.log('Checking the result:');
const now = fs.readFileSync(p, 'utf8');
let failed = false;
const c = (label, ok) => { console.log((ok ? '  [OK]   ' : '  [FAIL] ') + label); if (!ok) failed = true; };
c('next/image imported', /from\s+['"]next\/image['"]/.test(now));
c('Footer logo uses /icon.png', /<Image\s+src="\/icon\.png"[^>]*width=\{20\}/.test(now));
c('Old placeholder SVG removed from footer', !/h-5 w-5 rounded bg-indigo-600/.test(now));
if (failed) { console.log(''); console.log('Something did not complete - see [FAIL] above.'); process.exit(1); }
console.log('');
console.log('All checks passed.');
NODEEOF

echo ""
echo "Rebuild and hard-refresh to see it (scroll to the bottom of /about):"
echo "  bash -c \"rm -rf .next\""
echo "  npm run dev --webpack"
echo "  then Ctrl+Shift+R in the browser"
