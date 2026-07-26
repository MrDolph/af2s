#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20c: QHO preset obvious selection highlight
#
#   Makes the selected preset button impossible to miss:
#     • Selected: solid indigo-600 background, white text, white border
#     • Unselected: white background, gray border, dark text
#     • Checkmark icon on the active preset for extra clarity
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20c-qho-preset-obvious.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

PAGE="src/app/simulations/quantum-harmonic-oscillator/page.tsx"

if [ ! -f "$PAGE" ]; then
  echo "✗ $PAGE not found. Run this from the af2s project root." >&2
  exit 1
fi

echo "── A-Factor patch v20c: QHO preset obvious selection highlight ──"

node -e "
const fs = require('fs');
const f = '$PAGE';
let c = fs.readFileSync(f, 'utf8');

// Find and replace the preset buttons block with obvious styling
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
                  className={\\\`shrink-0 rounded-xl border-2 px-3 py-2.5 text-left transition min-w-[200px] \\\${
                    isActive
                      ? 'bg-indigo-600 border-white text-white shadow-lg'
                      : 'bg-white border-gray-200 text-gray-900 hover:border-indigo-300 hover:shadow-sm'
                  }\\\`}
                >
                  <div className=\"flex items-center justify-between\">
                    <p className={\\\`text-xs font-bold \\\${isActive ? 'text-white' : 'text-indigo-700'}\\\`}>
                      {preset.name}
                    </p>
                    {isActive && <span className=\"text-xs font-bold ml-2\">✓</span>}
                  </div>
                  <p className={\\\`text-[10px] mt-1 leading-relaxed \\\${isActive ? 'text-indigo-100' : 'text-gray-500'}\\\`}>
                    {preset.description}
                  </p>
                </button>
              );
            })}
          </div>\`;

if (c.includes(oldBlock)) {
  c = c.replace(oldBlock, newBlock);
  fs.writeFileSync(f, c);
  console.log('✓ Updated preset buttons in ' + f);
} else {
  // Try a looser match
  const regex = /<div className=\"flex gap-2 overflow-x-auto pb-1\">[\\s\\S]*?{PRESETS\\.map\\(\\(preset, i\\) =>[\\s\\S]*?<\\/div>/;
  if (regex.test(c)) {
    c = c.replace(regex, newBlock);
    fs.writeFileSync(f, c);
    console.log('✓ Updated preset buttons in ' + f + ' (loose match)');
  } else {
    console.log('⚠ Could not find preset block. File may already be patched or manually edited.');
    process.exit(1);
  }
}
"

echo ""
echo "✓ Patch v20c applied — selected preset is now obvious."
echo ""
echo "Next steps:"
echo "  npm run dev"
echo ""
