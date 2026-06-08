#!/bin/bash
# G1(i) — verify the slot-backed leaf DEPLOYS on Embedded Swift (arm64-apple-none-macho).
#
# InlineArray (SE-0453) has a macOS-26 floor only against the OS-shipped DYNAMIC stdlib;
# Embedded STATICALLY links its stdlib, so the OS-version floor does not apply. This check
# compiles the SlotStorage library (Slot/SparseInline/Slab — incl. the ~Copyable move-out)
# to the bare-metal Mach-O embedded triple. Requires a snapshot toolchain whose EMBEDDED
# stdlib ships InlineArray (the released 6.3.2 ships no embedded stdlib at all).
set -euo pipefail
SDK=$(xcrun --show-sdk-path)
env TOOLCHAINS=swift xcrun swiftc \
  -target arm64-apple-none-macho \
  -enable-experimental-feature Embedded \
  -wmo -parse-as-library \
  -Xcc -isysroot -Xcc "$SDK" \
  -c Sources/SlotStorage/*.swift -o /tmp/slotstorage-embedded.o
echo "EMBEDDED COMPILE OK → /tmp/slotstorage-embedded.o (slot-backed leaf deploys on Embedded)"
