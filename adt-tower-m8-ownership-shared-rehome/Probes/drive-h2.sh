#!/bin/zsh
# Manual swiftc drive for the H2 arity-collision probe.
#
# Two-module reproduction of the M8(a)-before-M8(b) ordering hazard:
#   1. Build OwnershipBoxStub (the faithful 1-param `Ownership.Shared<Value>` box class).
#   2. `-typecheck` the probe, which imports the stub AND declares a 2-param
#      `extension Ownership { public struct Shared<Element, B> }` from THIS module.
# Captures the compiler's verbatim diagnostics — no binary is emitted, the main package build
# stays green.
set -u
HERE="${0:A:h}"
cd "$HERE"
OUT="../Outputs/h2-collision.txt"
BUILD="./.build-h2"
mkdir -p "$BUILD"

SWIFTC_COMMON=(-swift-version 6 -enable-experimental-feature SuppressedAssociatedTypes)

{
  echo "=== H2 arity-collision probe — manual swiftc drive ==="
  echo "Toolchain: $(swift --version 2>&1 | tr '\n' ' ')"
  echo
  echo "--- Step 1: build stub module OwnershipBoxStub (faithful 1-param Ownership.Shared class) ---"
} > "$OUT"

swiftc "${SWIFTC_COMMON[@]}" -emit-module -parse-as-library \
  -module-name OwnershipBoxStub \
  -emit-module-path "$BUILD/OwnershipBoxStub.swiftmodule" \
  OwnershipBoxStub.swift >> "$OUT" 2>&1
echo "step1 swiftc exit: $?" >> "$OUT"

{
  echo
  echo "--- Step 2: -typecheck the probe (imports the stub + declares 2-param Ownership.Shared struct) ---"
} >> "$OUT"

swiftc "${SWIFTC_COMMON[@]}" -typecheck \
  -module-name H2Probe \
  -I "$BUILD" \
  h2-collision.swift >> "$OUT" 2>&1
echo "step2 swiftc exit: $?" >> "$OUT"

{
  echo
  echo "--- Step 3: emit H2Probe module (the 2-param Ownership.Shared struct) for the use-site leg ---"
} >> "$OUT"

swiftc "${SWIFTC_COMMON[@]}" -emit-module -parse-as-library \
  -module-name H2Probe \
  -I "$BUILD" \
  -emit-module-path "$BUILD/H2Probe.swiftmodule" \
  h2-collision.swift >> "$OUT" 2>&1
echo "step3 swiftc exit: $?" >> "$OUT"

{
  echo
  echo "--- Step 4: -typecheck a use-site importing BOTH — does Ownership.Shared<…> resolve by arity? ---"
} >> "$OUT"

swiftc "${SWIFTC_COMMON[@]}" -typecheck \
  -module-name H2UseSite \
  -I "$BUILD" \
  h2-usesite.swift >> "$OUT" 2>&1
echo "step4 swiftc exit: $?" >> "$OUT"

echo "(diagnostics above are verbatim compiler output; empty step blocks == zero diagnostics)" >> "$OUT"
