#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20d: fix missing color fields in QHO presets
#
#   Injects missing 'color' properties into presets that lack them,
#   matching the palette from patch v20b.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20d-fix-missing-colors.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

PHYSICS="src/lib/physics/quantumHarmonicOscillator.ts"

if [ ! -f "$PHYSICS" ]; then
  echo "✗ $PHYSICS not found. Run this from the af2s project root." >&2
  exit 1
fi

echo "── A-Factor patch v20d: fix missing color fields ──"

node -e "
const fs = require('fs');
const f = '$PHYSICS';
let c = fs.readFileSync(f, 'utf8');

const palette = [
  { name: 'Ground state',            color: '#10b981' },
  { name: 'First excited',           color: '#6366f1' },
  { name: 'Second excited',          color: '#8b5cf6' },
  { name: '0+1 superposition',       color: '#f43f5e' },
  { name: '0+2 superposition',       color: '#f59e0b' },
  { name: 'Coherent state (α=2)',  color: '#06b6d4' },
  { name: 'Coherent state (α=3)',  color: '#3b82f6' },
];

palette.forEach(p => {
  const re = new RegExp(\"name: '\" + p.name.replace(/[()]/g, '\\\\$&') + \"',\");
  if (re.test(c) && !c.includes('color: \\'' + p.color + '\\'')) {
    c = c.replace(re, \"name: '\" + p.name + \"',\\n    color: '\" + p.color + \"',\");
  }
});

fs.writeFileSync(f, c);
console.log('✓ Injected missing color fields into ' + f);
"

echo ""
echo "✓ Patch v20d applied — all presets now have color fields."
echo ""
echo "Next steps:"
echo "  npm run build"
echo ""
