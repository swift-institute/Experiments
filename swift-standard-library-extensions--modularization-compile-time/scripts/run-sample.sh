#!/bin/bash
# run-sample.sh <variant-name> <mode>
#
# mode ∈ {debug, release}. Runs one clean build of variants/variant-<name>/
# with timing instrumentation; appends one CSV row to Outputs/samples.csv.

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <variant-name> <debug|release>" >&2
  exit 2
fi

VARIANT="$1"
MODE="$2"

case "$MODE" in
  debug) SWIFT_MODE="" ;;
  release) SWIFT_MODE="-c release" ;;
  *) echo "error: mode must be debug or release" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")/.." && pwd)"
VARIANT_DIR="$HERE/variants/variant-$VARIANT"
OUTPUTS="$HERE/Outputs"

if [[ ! -d "$VARIANT_DIR" ]]; then
  echo "error: variant not generated: $VARIANT_DIR" >&2
  echo "run scripts/generate-variant.sh first" >&2
  exit 1
fi

mkdir -p "$OUTPUTS"
CSV="$OUTPUTS/samples.csv"
if [[ ! -f "$CSV" ]]; then
  echo "timestamp,variant,mode,scenario,regime,wall_seconds,user_cpu_seconds,max_rss_bytes,swift_version" >"$CSV"
fi

# Clean build — verify .build is actually gone before proceeding (per EXP-004).
rm -rf "$VARIANT_DIR/.build"
if [[ -d "$VARIANT_DIR/.build" ]]; then
  echo "error: .build still present after rm -rf" >&2
  exit 1
fi

SWIFT_VERSION="$(swift --version 2>&1 | head -1 | tr ',' ';')"
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TIME_OUT="$(mktemp -t run-sample.XXXXXX)"
trap 'rm -f "$TIME_OUT"' EXIT

# /usr/bin/time -l on macOS gives wall, user cpu, and max RSS.
# shellcheck disable=SC2086
if ! ( cd "$VARIANT_DIR" && /usr/bin/time -l swift build $SWIFT_MODE ) 2>"$TIME_OUT" 1>/dev/null; then
  echo "error: swift build failed for variant=$VARIANT mode=$MODE" >&2
  cat "$TIME_OUT" >&2
  exit 1
fi

# Parse the time -l output. Format varies slightly between macOS versions; look
# for the canonical "real ... user ... sys" line plus "maximum resident set size".
WALL="$(grep -E 'real' "$TIME_OUT" | awk '{print $1}' | head -1)"
USER_CPU="$(grep -E 'user' "$TIME_OUT" | awk '{print $1}' | head -1)"
MAX_RSS="$(grep -E 'maximum resident set size' "$TIME_OUT" | awk '{print $1}' | head -1)"

echo "$TIMESTAMP,$VARIANT,$MODE,clean,as-is,$WALL,$USER_CPU,$MAX_RSS,$SWIFT_VERSION" >>"$CSV"
echo "sample: variant=$VARIANT mode=$MODE wall=${WALL}s user=${USER_CPU}s rss=${MAX_RSS}B"
