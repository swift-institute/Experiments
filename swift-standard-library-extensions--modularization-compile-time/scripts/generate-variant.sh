#!/bin/bash
# generate-variant.sh <partition-file-or-"max">
#
# Generates a standalone SwiftPM package under variants/variant-<name>/
# that mirrors swift-standard-library-extensions with a different target partition.
#
# Source files are symlinked from the canonical Sources/Standard Library Extensions/
# so no source duplication occurs.
#
# "max" is a special keyword: generates one target per source file, target name
# derived from the filename (dots replaced with spaces, wrapped as
# "Standard Library <Stem> Extensions").

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <partition-file | max>" >&2
  exit 2
fi

PARTITION_ARG="$1"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
CANONICAL_SOURCES="$HERE/../../Sources/Standard Library Extensions"
VARIANTS_DIR="$HERE/variants"

if [[ ! -d "$CANONICAL_SOURCES" ]]; then
  echo "error: canonical sources not found at: $CANONICAL_SOURCES" >&2
  exit 1
fi

# Resolve partition name + produce a temporary mapping of file -> target.
TMP_MAP="$(mktemp -t partition-map.XXXXXX)"
trap 'rm -f "$TMP_MAP"' EXIT

if [[ "$PARTITION_ARG" == "max" ]]; then
  PARTITION_NAME="max"
  # Strict (no Core) mode: one target per extended TYPE. Files extending the
  # same type co-locate: Array.swift + Array.Builder.swift → one Array target.
  # Target name derives from the filename stem up to the first dot (e.g.,
  # "Array.Builder.swift" → stem "Array" → target "Standard Library Array Extensions").
  # Zero intra-package dependencies.
  find "$CANONICAL_SOURCES" -type f -name "*.swift" -print0 \
    | while IFS= read -r -d '' file; do
        fname="$(basename "$file")"
        base="$(basename "$file" .swift)"
        # Take stem up to first dot; preserve spaces (e.g., "Set String")
        stem="${base%%.*}"
        target="Standard Library ${stem} Extensions"
        printf '%s\t%s\n' "$fname" "$target"
      done >"$TMP_MAP"
else
  PARTITION_FILE="$HERE/partitions/${PARTITION_ARG}.txt"
  if [[ ! -f "$PARTITION_FILE" ]]; then
    echo "error: partition file not found: $PARTITION_FILE" >&2
    exit 1
  fi
  PARTITION_NAME="$(basename "$PARTITION_FILE" .txt | sed 's/^partition-//')"
  # Read rules; apply in order. "* -> X" matches any remaining unmatched file.
  declare -a RULE_GLOBS=()
  declare -a RULE_TARGETS=()
  while IFS= read -r line; do
    # strip comments + blanks
    line="${line%%#*}"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    glob="${line%% -> *}"
    target="${line#* -> }"
    RULE_GLOBS+=("$glob")
    RULE_TARGETS+=("$target")
  done <"$PARTITION_FILE"
  # Walk sources and apply first matching rule.
  find "$CANONICAL_SOURCES" -type f -name "*.swift" -print0 \
    | while IFS= read -r -d '' file; do
        fname="$(basename "$file")"
        matched=""
        for i in "${!RULE_GLOBS[@]}"; do
          glob="${RULE_GLOBS[$i]}"
          target="${RULE_TARGETS[$i]}"
          # Match: `*` matches all, otherwise exact filename
          if [[ "$glob" == "*" || "$glob" == "$fname" ]]; then
            matched="$target"
            break
          fi
        done
        if [[ -z "$matched" ]]; then
          echo "warning: no rule matched $fname" >&2
          continue
        fi
        printf '%s\t%s\n' "$fname" "$matched"
      done >"$TMP_MAP"
fi

# Collect unique target names in first-seen order (bash 3.2 compatible: linear scan).
UNIQUE_TARGETS=()
while IFS=$'\t' read -r _file target; do
  already_seen=0
  for existing in "${UNIQUE_TARGETS[@]:-}"; do
    if [[ "$existing" == "$target" ]]; then
      already_seen=1
      break
    fi
  done
  if [[ "$already_seen" -eq 0 ]]; then
    UNIQUE_TARGETS+=("$target")
  fi
done <"$TMP_MAP"

N="${#UNIQUE_TARGETS[@]}"
VARIANT_DIR="$VARIANTS_DIR/variant-${PARTITION_NAME}"

# Fresh start.
rm -rf "$VARIANT_DIR"
mkdir -p "$VARIANT_DIR/Sources"

# Place each source file into its target directory. Symlink for Core / single-target
# variants (no modification needed); COPY with prepended import for non-Core targets
# in Core-using partitions, because Swift's extension-member visibility rule is
# per-file (not per-target), so sibling `_imports.swift` does not suffice.
CORE_TARGET="Standard Library Extensions Core"
PARTITION_HAS_CORE=0
while IFS=$'\t' read -r _fname target; do
  if [[ "$target" == "$CORE_TARGET" ]]; then
    PARTITION_HAS_CORE=1
    break
  fi
done <"$TMP_MAP"

while IFS=$'\t' read -r fname target; do
  mkdir -p "$VARIANT_DIR/Sources/$target"
  DEST="$VARIANT_DIR/Sources/$target/$fname"
  if [[ "$PARTITION_HAS_CORE" -eq 1 && "$target" != "$CORE_TARGET" ]]; then
    # Copy + prepend import so nested-type references into Core resolve per-file.
    {
      echo "// Generated prepend — do not edit. See generate-variant.sh."
      echo "public import Standard_Library_Extensions_Core"
      echo ""
      cat "$CANONICAL_SOURCES/$fname"
    } >"$DEST"
  else
    ln -sf "$CANONICAL_SOURCES/$fname" "$DEST"
  fi
done <"$TMP_MAP"

# Generate Package.swift.
PKG_FILE="$VARIANT_DIR/Package.swift"
{
  cat <<'HEADER'
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "standard-library-extensions-variant",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .tvOS(.v26),
        .watchOS(.v26),
        .visionOS(.v26),
    ],
    products: [
HEADER

  # Expose every target as a library so downstream consumers (future scenarios)
  # can import narrowly. Umbrella is also a product.
  for t in "${UNIQUE_TARGETS[@]}"; do
    printf '        .library(name: "%s", targets: ["%s"]),\n' "$t" "$t"
  done

  cat <<'MIDDLE'
    ],
    targets: [
MIDDLE

  # When N > 1 there is no canonical umbrella in the partition; if multiple
  # targets exist, synthesize an umbrella re-exporting all of them.
  if [[ "$N" -gt 1 ]]; then
    UMBRELLA_TARGET="Standard Library Extensions Umbrella"
    UMBRELLA_DIR="$VARIANT_DIR/Sources/$UMBRELLA_TARGET"
    mkdir -p "$UMBRELLA_DIR"
    {
      echo "// Generated umbrella re-export. Do not edit."
      for t in "${UNIQUE_TARGETS[@]}"; do
        # Module name: replace spaces with underscores.
        mod="${t// /_}"
        echo "@_exported public import $mod"
      done
    } >"$UMBRELLA_DIR/exports.swift"
    # Emit variant .target declarations. Non-Core targets depend on Core if present.
    CORE_NAME="Standard Library Extensions Core"
    HAS_CORE=0
    for t in "${UNIQUE_TARGETS[@]}"; do
      if [[ "$t" == "$CORE_NAME" ]]; then
        HAS_CORE=1
        break
      fi
    done
    for t in "${UNIQUE_TARGETS[@]}"; do
      if [[ "$HAS_CORE" -eq 1 && "$t" != "$CORE_NAME" ]]; then
        cat <<EOF
        .target(
            name: "$t",
            dependencies: ["$CORE_NAME"],
            path: "Sources/$t"
        ),
EOF
      else
        cat <<EOF
        .target(
            name: "$t",
            path: "Sources/$t"
        ),
EOF
      fi
    done
    # Emit umbrella target.
    {
      echo "        .target("
      echo "            name: \"$UMBRELLA_TARGET\","
      echo "            dependencies: ["
      for t in "${UNIQUE_TARGETS[@]}"; do
        echo "                \"$t\","
      done
      echo "            ],"
      echo "            path: \"Sources/$UMBRELLA_TARGET\""
      echo "        ),"
    }
  else
    # Single-target case: emit the one target as-is.
    for t in "${UNIQUE_TARGETS[@]}"; do
      cat <<EOF
        .target(
            name: "$t",
            path: "Sources/$t"
        ),
EOF
    done
  fi

  cat <<'FOOTER'
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]
}
FOOTER
} >"$PKG_FILE"

echo "generated: $VARIANT_DIR ($N target$([ "$N" -eq 1 ] || echo s))"
