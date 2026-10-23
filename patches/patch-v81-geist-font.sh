#!/bin/bash
# A-Factor STEM Studio — stop the "Failed to download `Geist` from Google Fonts" warning (v81)
# Run inside af2s/ (the project ROOT), AFTER:   npm i geist
#     bash patches/patch-v81-geist-font.sh
#
# WHY     src/app/layout.tsx used next/font/google, which downloads Geist from Google's servers at
#         dev/build time. If that download fails (offline, slow link, VPN/firewall), Next prints the
#         warning and falls back to a system font.
# FIX     Load Geist from the installed "geist" npm package instead. The font files ship inside
#         node_modules, so nothing is fetched from Google. The CSS variable names stay the same
#         (--font-geist-sans / --font-geist-mono), so globals.css keeps working.
# CHANGES only src/app/layout.tsx (a one-time layout.tsx.bak copy is kept). Idempotent.
# NOTE    globals.css sets  body { font-family: Arial, Helvetica, sans-serif },  so the site has been
#         rendering in Arial. This patch does NOT change how the site looks. See the end of the output
#         if you want Geist to actually be used for body text.

set -e
if [ ! -f package.json ] || [ ! -f src/app/layout.tsx ]; then
  echo "ERROR: run this from your project root (the folder containing package.json and src/app/layout.tsx)."
  exit 1
fi
if [ ! -d node_modules/geist ]; then
  echo "ERROR: the 'geist' package is not installed. Run:  npm i geist   then run this patch again."
  exit 1
fi
if ! command -v node >/dev/null 2>&1; then echo "ERROR: 'node' not found on PATH."; exit 1; fi

node - << 'NODEEOF'
const fs = require('fs');
const p = 'src/app/layout.tsx';
let s = fs.readFileSync(p, 'utf8');
const nl = s.includes('\r\n') ? '\r\n' : '\n';

if (s.includes("from 'geist/font/sans'") || s.includes('from "geist/font/sans"')) {
  console.log('  layout.tsx already uses the geist package - nothing to do');
  process.exit(0);
}

const importRe = /import\s*\{\s*Geist\s*,\s*Geist_Mono\s*\}\s*from\s*['"]next\/font\/google['"];?\r?\n/;
const sansRe = /const\s+geistSans\s*=\s*Geist\(\{[^}]*\}\);?\r?\n/;
const monoRe = /const\s+geistMono\s*=\s*Geist_Mono\(\{[^}]*\}\);?\r?\n/;
if (!importRe.test(s) || !sansRe.test(s) || !monoRe.test(s)) {
  console.error('ERROR: layout.tsx is not in the expected shape (Geist / Geist_Mono from next/font/google).');
  console.error('       No changes made. Replace the font code by hand with:');
  console.error("         import { GeistSans } from 'geist/font/sans';");
  console.error("         import { GeistMono } from 'geist/font/mono';");
  console.error('       and use  ${GeistSans.variable} ${GeistMono.variable}  in the <html> className.');
  process.exit(1);
}

fs.copyFileSync(p, p + '.bak');
s = s.replace(importRe, "import { GeistSans } from 'geist/font/sans';" + nl + "import { GeistMono } from 'geist/font/mono';" + nl);
s = s.replace(sansRe, '').replace(monoRe, '');
s = s.replace(/\$\{geistSans\.variable\}/g, '${GeistSans.variable}').replace(/\$\{geistMono\.variable\}/g, '${GeistMono.variable}');
// Tidy a leftover blank line pair where the constants were.
s = s.replace(new RegExp("(import '\\./globals\\.css';" + nl + ")(" + nl + "){2,}"), '$1' + nl);
fs.writeFileSync(p, s);
console.log('  updated src/app/layout.tsx (backup: src/app/layout.tsx.bak)');
NODEEOF

echo ""
echo "Done. Restart the dev server (npm run dev) - the Google Fonts warning should be gone."
echo ""
echo "Optional: to actually render body text in Geist, change this line in src/app/globals.css:"
echo "    font-family: Arial, Helvetica, sans-serif;"
echo "  to:"
echo "    font-family: var(--font-sans), Arial, Helvetica, sans-serif;"
echo "This changes the look of the whole site, so it is not applied automatically."
