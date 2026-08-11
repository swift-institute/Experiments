#!/bin/bash
# run-mvp.sh
#
# Runs the MVP signal: 5 samples × {N=1, N=max} × {debug} × {clean} × {as-is}
# = 10 builds. Reports median wall-clock per cell.

set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"

echo "== generating variant-1 =="
"$HERE/scripts/generate-variant.sh" partition-1

echo "== generating variant-max =="
"$HERE/scripts/generate-variant.sh" max

echo
echo "== recording machine info =="
MACHINE_FILE="$HERE/Outputs/machine.txt"
mkdir -p "$HERE/Outputs"
{
  echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "hostname: $(hostname)"
  echo "uname: $(uname -a)"
  echo "sysctl machdep.cpu.brand_string: $(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo n/a)"
  echo "ncpu: $(sysctl -n hw.ncpu 2>/dev/null || echo n/a)"
  echo "physicalcpu: $(sysctl -n hw.physicalcpu 2>/dev/null || echo n/a)"
  echo "swift: $(swift --version 2>&1 | head -1)"
} | tee "$MACHINE_FILE"

echo
echo "== samples =="
for i in 1 2 3 4 5; do
  echo "-- sample $i: variant-1 debug --"
  "$HERE/scripts/run-sample.sh" 1 debug
done
for i in 1 2 3 4 5; do
  echo "-- sample $i: variant-max debug --"
  "$HERE/scripts/run-sample.sh" max debug
done

echo
echo "== median wall-clock per cell =="
python3 - "$HERE/Outputs/samples.csv" <<'PY'
import csv, sys, statistics
from collections import defaultdict

path = sys.argv[1]
cells = defaultdict(list)
with open(path) as f:
    r = csv.DictReader(f)
    for row in r:
        key = (row["variant"], row["mode"], row["scenario"], row["regime"])
        try:
            cells[key].append(float(row["wall_seconds"]))
        except ValueError:
            pass

for key, walls in sorted(cells.items()):
    med = statistics.median(walls)
    print(f"variant={key[0]:>6}  mode={key[1]:<7}  scenario={key[2]:<8}  regime={key[3]:<8}  n={len(walls)}  median_wall={med:.2f}s  min={min(walls):.2f}s  max={max(walls):.2f}s")
PY
