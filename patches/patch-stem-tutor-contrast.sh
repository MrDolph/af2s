#!/usr/bin/env bash
set -euo pipefail
command -v node >/dev/null || { echo 'Node.js is required.' >&2; exit 1; }
node <<'STEM_CONTRAST_NODE'
const fs = require('node:fs');
const file = 'src/app/tutor/page.tsx';
if (!fs.existsSync('package.json') || !fs.existsSync(file)) {
  console.error('Run from your project root after installing the STEM Tutor patch.'); process.exit(1);
}
const original = fs.readFileSync(file, 'utf8');
if (original.includes('data-stem-tutor-contrast')) { console.log('Contrast fix is already applied.'); process.exit(0); }
let updated = original.replace('return <><AppHeader />', 'return <div data-stem-tutor-contrast style={{ backgroundColor: "#f1f5f9", color: "#111827", colorScheme: "light", minHeight: "100vh" }}><AppHeader />');
updated = updated.replace('</main></>;', '</main></div>;');
updated = updated.replace(/text-gray-500/g, 'text-gray-600');
if (updated === original || !updated.includes('data-stem-tutor-contrast') || !updated.includes('</main></div>;')) {
 console.error('Tutor page differs from the expected version; no changes made.'); process.exit(1);
}
fs.mkdirSync('.stem-tutor-backups', { recursive: true });
const backup = fs.mkdtempSync('.stem-tutor-backups/contrast-');
fs.writeFileSync(backup + '/page.tsx', original);
fs.writeFileSync(file, updated);
console.log('Tutor background and text contrast updated. Backup: ' + backup);
console.log('Refresh /tutor. Other pages keep their existing styles.');
STEM_CONTRAST_NODE
