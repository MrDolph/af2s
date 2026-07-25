#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Hotfix: TypeScript null-check error in CoupledOscillatorsCanvas.tsx
# ══════════════════════════════════════════════════════════════════════════════
set -euo pipefail

if [ ! -f "package.json" ]; then
  echo "✗ Run this from the af2s project root (package.json not found)." >&2
  exit 1
fi

echo "── Hotfix: CoupledOscillatorsCanvas.tsx null-check ──"

# Use sed to fix the drawSpring function signature and calls
# The issue: drawSpring captures ctx from outer scope, but TS doesn't know it's non-null.
# Fix: pass ctx as a parameter.

cat > /tmp/fix_canvas.py << 'PYEOF'
import re

with open("src/components/simulation/CoupledOscillatorsCanvas.tsx", "r") as f:
    content = f.read()

# Fix 1: change drawSpring to accept ctx as first param
old_sig = "function drawSpring(xA: number, xB: number, y: number, coils: number, amp: number, color: string) {"
new_sig = "function drawSpring(ctx: CanvasRenderingContext2D, xA: number, xB: number, y: number, coils: number, amp: number, color: string) {"
content = content.replace(old_sig, new_sig)

# Fix 2: update the three drawSpring calls to pass ctx
content = content.replace(
    "drawSpring(wallX1, sx1 - mW1 / 2, trackY, 10, 12, '#6366f1');",
    "drawSpring(ctx, wallX1, sx1 - mW1 / 2, trackY, 10, 12, '#6366f1');"
)
content = content.replace(
    "drawSpring(sx1 + mW1 / 2, sx2 - mW2 / 2, trackY, 10, 12, '#f59e0b');",
    "drawSpring(ctx, sx1 + mW1 / 2, sx2 - mW2 / 2, trackY, 10, 12, '#f59e0b');"
)
content = content.replace(
    "drawSpring(sx2 + mW2 / 2, wallX2, trackY, 10, 12, '#10b981');",
    "drawSpring(ctx, sx2 + mW2 / 2, wallX2, trackY, 10, 12, '#10b981');"
)

with open("src/components/simulation/CoupledOscillatorsCanvas.tsx", "w") as f:
    f.write(content)

print("Fixed drawSpring null-check in CoupledOscillatorsCanvas.tsx")
PYEOF

python3 /tmp/fix_canvas.py

echo "✓ Hotfix applied. Rebuild with: rm -rf .next && npm run build"
