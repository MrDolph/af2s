#!/bin/bash
# A-Factor STEM Studio — put the crest logo IN THE NAVBAR (not just the tab icon)
# Run inside af2s/ (the project ROOT, not inside patches/), AFTER v73:
#     bash patches/patch-v74-navbar-logo.sh
#
# WHY THIS EXISTS
#   v73 changed the browser TAB icon (favicon.ico / icon.png / apple-icon.png).
#   That is a different thing from the logo shown IN the site itself, next to
#   "A-Factor" in the top bar — that one was a plain hardcoded indigo square
#   with a generic diamond shape, unrelated to any of the icon files, and v73
#   never touched it. This patch replaces THAT one, using the same /icon.png
#   v73 already added (no new image file needed).
#
# WHAT IT CHANGES (targeted, idempotent, CRLF/LF-aware — never a full overwrite):
#   src/components/layout/AppHeader.tsx
#     - adds: import Image from 'next/image';
#     - replaces the hardcoded indigo-box SVG logo with <Image src="/icon.png" .../>

set -e

if [ ! -f package.json ] || [ ! -d src ]; then
  echo "ERROR: run this from your project root (the folder containing package.json and src/),"
  echo "       e.g.   cd af2s   then   bash patches/patch-v74-navbar-logo.sh"
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

echo "Applying navbar logo patch..."

node - << 'NODEEOF'
const fs = require('fs');
const p = 'src/components/layout/AppHeader.tsx';
let s = fs.readFileSync(p, 'utf8');
const nl = s.includes('\r\n') ? '\r\n' : '\n';
const orig = s;

if (s.includes("src/lib") && false) {} // no-op, keeps this block's shape consistent with other patches

if (s.includes('/icon.png') && s.includes('next/image')) {
  console.log('  AppHeader already uses the crest logo - skipping');
} else {
  // 1. import
  if (!s.includes("import Image from 'next/image';")) {
    const m = /import\s+Link\s+from\s+['"]next\/link['"];[ \t]*\r?\n/.exec(s);
    if (!m) {
      console.log("  ERROR: couldn't find the 'next/link' import to anchor on. Add this import"
        + " by hand:  import Image from 'next/image';");
      process.exit(1);
    }
    const at = m.index + m[0].length;
    s = s.slice(0, at) + "import Image from 'next/image';" + nl + s.slice(at);
  }

  // 2. logo block — match loosely (whitespace-insensitive) so minor formatting
  //    differences in your copy don't stop the patch from finding it.
  const re = /<div className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-600[^"]*">\s*<svg[^>]*viewBox="0 0 14 14"[^>]*>[\s\S]*?<\/svg>\s*<\/div>/;
  const m2 = re.exec(s);
  if (!m2) {
    console.log("  ERROR: couldn't find the placeholder logo block (it may already be edited).");
    console.log("         Replace it by hand with:");
    console.log('           <Image src="/icon.png" alt="A-Factor STEM Studio" width={32} height={32}');
    console.log('             className="h-7 w-7 rounded-lg" priority />');
    process.exit(1);
  }
  const replacement = '<Image src="/icon.png" alt="A-Factor STEM Studio" width={32} height={32}' + nl
    + '              className="h-7 w-7 rounded-lg" priority />';
  s = s.slice(0, m2.index) + replacement + s.slice(m2.index + m2[0].length);

  fs.writeFileSync(p, s, 'utf8');
  console.log('  AppHeader: navbar logo now uses /icon.png');
}

// ── Checklist ────────────────────────────────────────────────────────
console.log('');
console.log('Checking the result:');
const check = (label, ok) => console.log((ok ? '  [OK]   ' : '  [FAIL] ') + label);
const now = fs.readFileSync(p, 'utf8');
let failed = false;
const c = (label, ok) => { check(label, ok); if (!ok) failed = true; };
c('next/image imported', /from\s+['"]next\/image['"]/.test(now));
c('Navbar logo uses /icon.png', /<Image\s+src="\/icon\.png"/.test(now));
c('Old placeholder SVG removed', !/viewBox="0 0 14 14"/.test(now));
if (failed) { console.log(''); console.log('Something did not complete - see [FAIL] above.'); process.exit(1); }
console.log('');
console.log('All checks passed.');
NODEEOF

echo ""
echo "Rebuild and hard-refresh to see it:"
echo "  bash -c \"rm -rf .next\""
echo "  npm run dev --webpack"
echo "  then Ctrl+Shift+R in the browser"
