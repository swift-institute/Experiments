#!/bin/zsh
# adt-tower-m11-iteration-0witness — the D9/M11 witness_method SIL leg.
#
# Emits the `-O` SIL for the executable `client` target against the release-built module
# search path, then classifies every `witness_method` occurrence (classify-sil.py). The
# verdict requires 0 real `= witness_method` instructions in the three specialized client
# paths (countViaIterable / sumViaLinearForEach / sumViaRingForEach) with the only residual
# inside the retained @inlinable generic `Iterable.forEach` `public_external` template.
#
# Prereq: `swift build -c release` (populates .build/release/Modules).
# Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101), arm64-apple-macosx26.0.
set -eu
cd "$(dirname "$0")"

SDK="$(xcrun --show-sdk-path)"
mkdir -p Outputs

# The client target enables SuppressedAssociatedTypes; LifetimeDependence/Lifetimes are
# enabled to deserialize the buffer/iterator modules' @inlinable bodies for specialization.
swiftc -O -emit-sil \
  -I .build/release/Modules \
  -sdk "$SDK" \
  -target arm64-apple-macosx26.0 \
  -swift-version 6 \
  -enable-experimental-feature SuppressedAssociatedTypes \
  -enable-experimental-feature LifetimeDependence \
  -enable-experimental-feature Lifetimes \
  Sources/client/main.swift \
  > Outputs/client.sil 2> Outputs/sil-emit-stderr.txt

python3 classify-sil.py Outputs/client.sil | tee Outputs/sil-witness-classification.txt
