#!/bin/zsh
# Negative-control runner — Apple Swift 6.3.3.
# Compiles Probes/negative-control.swift (NOT a build target) with swiftc against
# the already-built SwiftPM modules (mimics adt-tower-walls' single-file probes).
# The compile MUST FAIL; the diagnostic is the result. Output: Outputs/negative-control.txt
set -u
OUT="Outputs/negative-control.txt"

# Locate the built module dir (SwiftPM debug build must exist first: `swift build`).
MODULES_DIR="$(find .build -type d -name Modules -path '*debug*' 2>/dev/null | head -1)"
if [ -z "$MODULES_DIR" ]; then
  echo "ERROR: no built Modules dir found under .build — run 'swift build' first." | tee "$OUT"
  exit 2
fi

SDK="$(xcrun --show-sdk-path)"
{
  echo "=== negative-control [expect: compile FAILS at type-check] ==="
  echo "modules: $MODULES_DIR"
  echo "command: swiftc -typecheck -enable-experimental-feature SuppressedAssociatedTypes \\"
  echo "         -target arm64-apple-macos26.0 -sdk <sdk> -I <modules> Probes/negative-control.swift"
  echo "--- diagnostics ---"
} > "$OUT"

swiftc -typecheck \
  -enable-experimental-feature SuppressedAssociatedTypes \
  -target arm64-apple-macos26.0 \
  -sdk "$SDK" \
  -I "$MODULES_DIR" \
  Probes/negative-control.swift >> "$OUT" 2>&1
rc=$?

{
  echo "--- end diagnostics ---"
  echo "swiftc rc=$rc  (nonzero == PASS: the un-retagged witness is correctly REJECTED)"
} >> "$OUT"

cat "$OUT"
# Invert: this script "succeeds" (rc 0) only when swiftc FAILED as expected.
[ "$rc" -ne 0 ]
