#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# A-Factor STEM Studio — patch v20a: QHO preset selection highlight
#
#   Adds active-state visual feedback to the preset buttons on the Quantum
#   Harmonic Oscillator simulation page so users know which preset is loaded.
#
# Run from the af2s project root (Git Bash):   bash patches/patch-v20a-qho-preset-highlight.sh
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

FILE="src/app/simulations/quantum-harmonic-oscillator/page.tsx"

if [ ! -f "$FILE" ]; then
  echo "✗ $FILE not found. Run this from the af2s project root." >&2
  exit 1
fi

echo "── A-Factor patch v20a: QHO preset selection highlight ──"

TMP=$(mktemp)
cat > "$TMP" << 'JSSCRIPT'
const fs = require('fs');
const f = 'src/app/simulations/quantum-harmonic-oscillator/page.tsx';
let c = fs.readFileSync(f, 'utf8');

// 1. Add selectedPreset state
if (!c.includes('setSelectedPreset')) {
  c = c.replace(
    'const [openEx, setOpenEx] = useState<number | null>(null);',
    'const [openEx, setOpenEx] = useState<number | null>(null);\n  const [selectedPreset, setSelectedPreset] = useState<number | null>(null);'
  );
}

// 2. Update applyPreset signature to accept index
if (c.includes('const applyPreset = useCallback((preset: QHOPreset) => {')) {
  c = c.replace(
    'const applyPreset = useCallback((preset: QHOPreset) => {',
    'const applyPreset = useCallback((preset: QHOPreset, index: number) => {'
  );
}

// 3. Track selection inside applyPreset (before setLiveStats)
if (!c.includes('setSelectedPreset(index);')) {
  c = c.replace(
    '    setIsRunning(false); setIsPaused(false);\n    setResetKey((k) => k + 1);\n    setLiveStats({',
    '    setIsRunning(false); setIsPaused(false);\n    setResetKey((k) => k + 1);\n    setSelectedPreset(index);\n    setLiveStats({'
  );
}

// 4. Clear selection on manual reset (before setLiveStats)
if (!c.includes('setSelectedPreset(null);')) {
  c = c.replace(
    '    setIsRunning(false);\n    setIsPaused(false);\n    setResetKey((k) => k + 1);\n    setLiveStats({',
    '    setIsRunning(false);\n    setIsPaused(false);\n    setResetKey((k) => k + 1);\n    setSelectedPreset(null);\n    setLiveStats({'
  );
}

// 5. Pass index into applyPreset on click
if (c.includes('onClick={() => applyPreset(preset)}')) {
  c = c.replace(
    'onClick={() => applyPreset(preset)}',
    'onClick={() => applyPreset(preset, i)}'
  );
}

// 6. Conditional button styling
if (c.includes('className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]"')) {
  c = c.replace(
    'className="shrink-0 rounded-xl border border-gray-200 bg-white px-3 py-2 text-left hover:border-indigo-300 hover:shadow-sm transition min-w-[200px]"',
    'className={`shrink-0 rounded-xl border px-3 py-2 text-left transition min-w-[200px] ${selectedPreset === i ? \'bg-indigo-50 border-indigo-400 ring-1 ring-indigo-200 shadow-sm\' : \'bg-white border-gray-200 hover:border-indigo-300 hover:shadow-sm\'}`}'
  );
}

// 7. Conditional text colour
if (c.includes('<p className="text-xs font-medium text-indigo-700">{preset.name}</p>')) {
  c = c.replace(
    '<p className="text-xs font-medium text-indigo-700">{preset.name}</p>',
    '<p className={`text-xs font-medium ${selectedPreset === i ? \'text-indigo-800\' : \'text-indigo-700\'}`}>{preset.name}</p>'
  );
}

fs.writeFileSync(f, c);
console.log('✓ ' + f + ' updated');
JSSCRIPT

node "$TMP"
rm -f "$TMP"

echo ""
echo "✓ Patch v20a applied — preset selection is now highlighted."
echo ""
echo "Next steps:"
echo "  npm run dev"
echo ""
