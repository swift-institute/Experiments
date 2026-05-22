#!/bin/bash
#
# measure-compile-time.sh
#
# Cold-rebuild compile-time measurement for RepeatApple and RepeatInstitute.
# Wipes .build entirely between runs to ensure a true cold build per target.
#

set -e

cd "$(dirname "$0")/.."

echo "================================================"
echo "Cold compile-time measurement (release config)"
echo "================================================"
echo ""

# --- RepeatApple ---
echo "--- RepeatApple ---"
rm -rf .build .DS_Store 2>/dev/null; rm -rf .build 2>/dev/null; sleep 1; rm -rf .build 2>/dev/null || true
START=$SECONDS
swift build -c release --target RepeatApple > /dev/null 2>&1
APPLE_TIME=$((SECONDS - START))
echo "RepeatApple: ${APPLE_TIME}s"
echo ""

# --- RepeatInstitute ---
echo "--- RepeatInstitute ---"
rm -rf .build .DS_Store 2>/dev/null; rm -rf .build 2>/dev/null; sleep 1; rm -rf .build 2>/dev/null || true
START=$SECONDS
swift build -c release --target RepeatInstitute > /dev/null 2>&1
INST_TIME=$((SECONDS - START))
echo "RepeatInstitute: ${INST_TIME}s"
echo ""

# --- Ratio ---
if [ "$APPLE_TIME" -gt 0 ]; then
    RATIO=$(echo "scale=3; $INST_TIME / $APPLE_TIME" | bc)
    echo "Ratio (institute / apple): ${RATIO}x"
fi
echo ""
echo "Apple:     ${APPLE_TIME}s"
echo "Institute: ${INST_TIME}s"
