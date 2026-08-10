#!/usr/bin/env bash
# fetch-fixtures.sh
#
# Populates ../Fixtures/ with twitter.json, canada.json, citm_catalog.json.
#
# Source: the swift-foundation clone at
#   /Users/coen/Developer/swiftlang/swift-foundation/Tests/NewCodableBenchmarks/Resources/
#
# These are the same fixtures Apple's NewCodableBenchmarks harness uses;
# they originate from the nativejson-benchmark / simdjson test corpora
# and are committed by Apple under Apache 2.0.
#
# Fixtures/ is .gitignored (~4 MB total); re-run this script per fresh clone.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/../Fixtures"
APPLE_RESOURCES="/Users/coen/Developer/swiftlang/swift-foundation/Tests/NewCodableBenchmarks/Resources"

mkdir -p "$FIXTURES_DIR"

if [[ ! -d "$APPLE_RESOURCES" ]]; then
    cat <<EOF >&2
fetch-fixtures.sh: source not found

Expected the swift-foundation clone at:
  $APPLE_RESOURCES

Either:
  1. Clone it:
       git clone https://github.com/swiftlang/swift-foundation.git \\
         /Users/coen/Developer/swiftlang/swift-foundation
  2. Check out the experimental branch:
       cd /Users/coen/Developer/swiftlang/swift-foundation
       git checkout experimental/new-codable
  3. Re-run this script.
EOF
    exit 1
fi

echo "Copying fixtures from $APPLE_RESOURCES"

missing=0
for fixture in twitter.json canada.json citm_catalog.json; do
    src="$APPLE_RESOURCES/$fixture"
    dst="$FIXTURES_DIR/$fixture"
    if [[ -f "$src" ]]; then
        cp "$src" "$dst"
        size=$(wc -c < "$dst" | tr -d ' ')
        printf "  ok  %-20s %s bytes\n" "$fixture" "$size"
    else
        printf "  MISSING  %s\n" "$fixture" >&2
        missing=$((missing + 1))
    fi
done

if (( missing > 0 )); then
    echo "$missing fixture(s) missing; check the source dir." >&2
    exit 2
fi

echo ""
echo "Fixtures ready in $FIXTURES_DIR"
