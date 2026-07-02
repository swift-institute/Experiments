#!/bin/zsh
# adt-tower-walls probe runner — Apple Swift 6.3.3 re-probe of the tower walls.
# Each probe is a standalone swiftc unit ([EXP-004]: no build cache). Modes:
#   RUN       compile (debug) + execute
#   RUNO      compile -O + execute
#   FAIL      expect compile error (diagnostics are the result)
# Flags column is appended to swiftc. Output: Outputs/probes.txt
set -u
BIN="$(mktemp -d)"
OUT="Outputs/probes.txt"
: > "$OUT"
SAT="-enable-experimental-feature SuppressedAssociatedTypes"
RAW="-enable-experimental-feature RawLayout"
COR="-enable-experimental-feature CoroutineAccessors"
run_probe() {
  local name=$1 mode=$2 flags=$3
  echo "=== $name [$mode] flags: ${flags:-none} ===" | tee -a "$OUT"
  case $mode in
    TYPECHECK-OK)
      swiftc -typecheck ${=flags} "Probes/$name.swift" >> "$OUT" 2>&1
      echo "rc=$? (Sema accepts — the SIL layer is the gate; see FAILC twin)" | tee -a "$OUT" ;;
    FAILC)
      local bin2="$BIN/$name"
      swiftc ${=flags} "Probes/$name.swift" -o "$bin2" 2>&1 | grep -E "error" | head -4 >> "$OUT"
      echo "rc=${pipestatus[1]} (expected nonzero at SIL)" | tee -a "$OUT" ;;
    FAIL)
      swiftc -typecheck ${=flags} "Probes/$name.swift" 2>&1 | grep -E "error" | head -4 >> "$OUT"
      echo "rc=${pipestatus[1]} (expected nonzero)" | tee -a "$OUT" ;;
    RUN|RUNO)
      local opt=""; [ "$mode" = RUNO ] && opt="-O"
      if swiftc $opt ${=flags} "Probes/$name.swift" -o "$BIN/$name" >> "$OUT" 2>&1; then
        "$BIN/$name" >> "$OUT" 2>&1
        echo "run rc=$?" | tee -a "$OUT"
      else
        echo "compile FAILED" | tee -a "$OUT"
      fi ;;
  esac
}
run_probe p1-alias-in-namespace                    RUN  "$SAT"
run_probe p1b-alias-in-namespace-valuegeneric      RUN  "$SAT"
run_probe p2-alias-in-generic-type                 RUN  "$SAT"
run_probe p2b-alias-in-generic-type-valuegeneric   RUN  "$SAT"
run_probe p3-alias-top-level                       RUN  "$SAT"
run_probe p3b-extension-of-alias                   RUN  "$SAT"
run_probe p3c-alias-where-clause                   RUN  "$SAT"
run_probe p4-suppression-clause                    FAIL "$SAT"
run_probe p5-borrow-mutate-accessors               FAIL ""
run_probe p6-coroutine-accessors                   FAIL "$COR $SAT"
run_probe p7-extension-implies-copyable            FAIL ""
run_probe p8-wall3-dual-storage                    RUNO "$RAW"
run_probe p8b-wall3-field-after-rawlayout          RUNO "$RAW"
run_probe p8c-wall3-generic-dual                   RUNO "$RAW"
run_probe p10-default-generic-arg                  FAIL ""
run_probe p11-noncopyable-whole-value-get          TYPECHECK-OK "$SAT"
run_probe p11b-noncopyable-whole-value-get-full    FAILC "$SAT"
run_probe p12-inlinearray-deinit                   RUN  ""
run_probe p12-inlinearray-deinit                   RUNO ""
echo "--- done ---" | tee -a "$OUT"
