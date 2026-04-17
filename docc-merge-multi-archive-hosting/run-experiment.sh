#!/bin/bash
# Runs the docc-merge experiment pipeline end-to-end:
#   1. Convert each .docc catalog into a .doccarchive
#   2. Merge the three archives with a synthesized landing page
#   3. Transform for static hosting (merge output is already
#      statically hostable on Xcode-bundled DocC 6.3.1, but we
#      run the transform explicitly to mirror the intended CI flow)
#   4. Print resulting structure and a hint for local serving

set -euo pipefail

cd "$(dirname "$0")"

OUTPUT_DIR="Output"
ARCHIVES_DIR="${OUTPUT_DIR}/archives"
MERGED_ARCHIVE="${OUTPUT_DIR}/Merged.doccarchive"
HOSTED_DIR="${OUTPUT_DIR}/hosted"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${ARCHIVES_DIR}"

echo "=== Toolchain ==="
xcrun --find docc
swift --version | head -1

for name in AlphaDocs BetaDocs GammaDocs; do
    echo
    echo "=== Converting ${name} ==="
    xcrun docc convert "Catalogs/${name}.docc" \
        --output-path "${ARCHIVES_DIR}/${name}.doccarchive"
done

echo
echo "=== Merging archives ==="
xcrun docc merge \
    "${ARCHIVES_DIR}/AlphaDocs.doccarchive" \
    "${ARCHIVES_DIR}/BetaDocs.doccarchive" \
    "${ARCHIVES_DIR}/GammaDocs.doccarchive" \
    --synthesized-landing-page-name "Swift Institute Merge Experiment" \
    --synthesized-landing-page-kind "Experiment" \
    --synthesized-landing-page-topics-style detailedGrid \
    --output-path "${MERGED_ARCHIVE}"

echo
echo "=== Transform for static hosting ==="
xcrun docc process-archive transform-for-static-hosting \
    "${MERGED_ARCHIVE}" \
    --output-path "${HOSTED_DIR}"

echo
echo "=== Merged archive top-level structure ==="
find "${MERGED_ARCHIVE}" -maxdepth 2 -type d

echo
echo "=== Hosted archive top-level structure ==="
find "${HOSTED_DIR}" -maxdepth 2 -type d

echo
echo "=== Data documentation roots (merged) ==="
ls "${MERGED_ARCHIVE}/data/documentation" 2>/dev/null || echo "(no data/documentation dir)"

echo
echo "=== Data documentation roots (hosted) ==="
ls "${HOSTED_DIR}/data/documentation" 2>/dev/null || echo "(no data/documentation dir)"

echo
echo "=== Done ==="
echo "To serve the hosted archive locally on port 8000:"
echo "  cd '${PWD}/${HOSTED_DIR}' && python3 -m http.server 8000"
echo "Then browse:"
echo "  http://localhost:8000/documentation/"
