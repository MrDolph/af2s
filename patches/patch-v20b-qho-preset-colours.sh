#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20b: QHO preset distinct colours
#
#   Each preset gets its own accent colour. When selected, the card background
#   tints, the left border glows, and a "Selected" chip appears — impossible
#   to miss at a glance.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20b-qho-preset-colours.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

PHYSICS="src/lib/physics/quantumHarmonicOscillator.ts"
PAGE="src/app/simulations/quantum-harmonic-oscillator/page.tsx"

if [ ! -f "$PHYSICS" ] || [ ! -f "$PAGE" ]; then
  echo "✗ Run this from the af2s project root (required files not found)." >&2
  exit 1
fi

echo "── A-Factor patch v20b: QHO preset distinct colours ──"

# ── 1. Add 'color' field to QHOPreset interface ─────────────────────────────
if ! grep -q "color: string;" "$PHYSICS"; then
  sed -i 's/export interface QHOPreset {/export interface QHOPreset {\n  color: string;/' "$PHYSICS"
  echo "  → Added 'color' to QHOPreset interface"
fi

# ── 2. Inject distinct colours into every preset ────────────────────────────
node -e "
const fs = require('fs');
const f = '$PHYSICS';
let c = fs.readFileSync(f, 'utf8');

const palette = [
  { name: 'Ground state',            color: '#10b981' }, // emerald
  { name: 'First excited',           color: '#6366f1' }, // indigo
  { name: 'Second excited',          color: '#8b5cf6' }, // violet
  { name: '0+1 superposition',       color: '#f43f5e' }, // rose
  { name: '0+2 superposition',       color: '#f59e0b' }, // amber
  { name: 'Coherent state (α=2)',  color: '#06b6d4' }, // cyan
  { name: 'Coherent state (α=3)',  color: '#3b82f6' }, // blue
];

palette.forEach(p => {
  const re = new RegExp(\"name: '\" + p.name.replace(/[()]/g, '\\\\$&') + \"',\");
  if (re.test(c) && !c.includes('color: \\'' + p.color + '\\'')) {
    c = c.replace(re, \"name: '\" + p.name + \"',\\n    color: '\" + p.color + \"',\");
  }
});

fs.writeFileSync(f, c);
console.log('  → Injected preset colours into ' + f);
"

# ── 3. Update the page to render coloured active cards ──────────────────────
node -e "
const fs = require('fs');
const f = '$PAGE';
let c = fs.readFileSync(f, 'utf8');

// Replace the preset buttons block
const oldBlock = \`<div className=\"flex gap-2 overflow-x-auto pb-1\">
            {PRESETS.map((preset, i) => (
              <button
                key={i}
                onClick={() => applyPreset(preset, i)}
                className={\\\`shrink-0 rounded-xl border px-3 py-2 text-left transition min-w-[200px] \\\${selectedPreset === i ? 'bg-indigo-50 border-indigo-400 ring-1 ring-indigo-200 shadow-sm' : 'bg-white border-gray-200 hover:border-indigo-300 hover:shadow-sm'}\\\`}
              >
                <p className={\\\`text-xs font-medium \\\${selectedPreset === i ? 'text-indigo-800' : 'text-indigo-700'}\\\`}>{preset.name}</p>
                <p className=\"text-[10px] text-gray-400 mt-0.5 leading-relaxed\">{preset.description}</p>
              </button>
            ))}
          </div>\`;

const newBlock = \`<div className=\"flex gap-2 overflow-x-auto pb-1\">
            {PRESETS.map((preset, i) => {
              const isActive = selectedPreset === i;
              return (
                <button
                  key={i}
                  onClick={() => applyPreset(preset, i)}
                  className={\\\`shrink-0 rounded-xl border px-3 py-2.5 text-left transition min-w-[200px] relative overflow-hidden \\\${
                    isActive
                      ? 'border-transparent shadow-md'
                      : 'bg-white border-gray-200 hover:border-gray-300 hover:shadow-sm'
                  }\\\`}
                  style={isActive ? { backgroundColor: preset.color + '12', borderLeft: '4px solid ' + preset.color } : undefined}
                >
                  {isActive && (
                    <span className=\"absolute top-2 right-2 text-[9px] font-bold px-1.5 py-0.5 rounded-full text-white\" style={{ backgroundColor: preset.color }}>
                      Selected
                    </span>
                  )}
                  <p className=\"text-xs font-medium\" style={{ color: isActive ? preset.color : '#4338ca' }}>
                    {preset.name}
                  </p>
                  <p className=\"text-[10px] text-gray-500 mt-1 leading-relaxed\">{preset.description}</p>
                </button>
              );
            })}
          </div>\`;

if (c.includes(oldBlock)) {
  c = c.replace(oldBlock, newBlock);
  fs.writeFileSync(f, c);
  console.log('  → Updated preset button styling in ' + f);
} else {
  console.log('  ⚠ Could not find exact preset block to replace in ' + f);
  console.log('    (The patch may already be applied or the file was edited manually.)');
}
"

echo ""
echo "✓ Patch v20b applied — presets now have distinct selection colours."
echo ""
echo "Next steps:"
echo "  npm run dev"
echo ""
