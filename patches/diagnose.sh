#!/bin/bash
# Run inside af2s/: bash diagnose.sh
echo "=== Checking what files exist ==="
ls src/components/simulation/Projectile*.tsx 2>/dev/null
ls src/app/simulations/projectile-motion/page.tsx 2>/dev/null

echo ""
echo "=== First 10 lines of ProjectileModeCanvas ==="
head -15 src/components/simulation/ProjectileModeCanvas.tsx 2>/dev/null || echo "FILE NOT FOUND"

echo ""
echo "=== Does page.tsx use ProjectileModeCanvas? ==="
grep "ProjectileModeCanvas\|isRunning\|resetKey" src/app/simulations/projectile-motion/page.tsx 2>/dev/null | head -10

echo ""
echo "=== Does page.tsx import from projectile-modes? ==="
grep "import" src/app/simulations/projectile-motion/page.tsx 2>/dev/null | head -10

echo ""
echo "=== What does package.json say about next version? ==="
grep '"next"' package.json

echo ""
echo "=== Does .next exist? ==="
ls .next 2>/dev/null && echo "YES — stale cache may exist" || echo "No .next cache"
