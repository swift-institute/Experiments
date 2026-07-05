#!/usr/bin/env python3
"""Classify every `witness_method` occurrence in an emitted SIL file for the D9/M11
0-witness verdict.

Distinguishes:
  * REAL witness_method INSTRUCTIONS  — lines matching `= witness_method` (a dynamic
    protocol-witness dispatch); these are what "0-witness" is about.
  * convention ANNOTATIONS            — `$@convention(witness_method: P)` appearing in the
    TYPE of an `apply`/`function_ref`; NOT a dispatch, just how the raw `grep witness_method`
    over-counts. Reported separately for transparency.

For each REAL instruction it finds the enclosing `sil @<name>` function by scanning
backward, records its linkage attributes (public_external / shared / hidden / …) and its
demangled name (the `//` comment above the header), and reports whether it lands in one of
the three specialized client paths (which must be 0) or the retained Iterable.forEach
template (the allowed public_external residual)."""
import re
import sys

sil_path = sys.argv[1] if len(sys.argv) > 1 else "Outputs/client.sil"
with open(sil_path) as f:
    lines = f.readlines()

sil_hdr = re.compile(r'^sil\b(?P<attrs>.*?)@(?P<name>\$[A-Za-z0-9_]+)\b')
real_instr = re.compile(r'=\s*witness_method\b')


def enclosing_function(idx):
    """Return (header_lineno, attrs, mangled, demangled) for the `sil` fn containing line idx."""
    for j in range(idx, -1, -1):
        m = sil_hdr.match(lines[j])
        if m:
            # Walk up past `// Isolation: ...` to the demangled-name comment.
            demangled = m.group("name")
            k = j - 1
            while k >= 0 and lines[k].strip().startswith("//"):
                c = lines[k].strip()[2:].strip()
                if not c.startswith("Isolation:"):
                    demangled = c
                    break
                k -= 1
            return (j + 1, m.group("attrs").strip(), m.group("name"), demangled)
    return (None, "", "", "<no enclosing sil function>")


real_sites = []       # (lineno, header_lineno, attrs, mangled, demangled)
annotation_only = 0
raw_lines = 0

for i, raw in enumerate(lines):
    if "witness_method" not in raw:
        continue
    raw_lines += 1
    if real_instr.search(raw):
        hl, attrs, mangled, dem = enclosing_function(i)
        real_sites.append((i + 1, hl, attrs, mangled, dem))
    else:
        annotation_only += 1

# Group real instruction sites by enclosing function.
by_func = {}
for lineno, hl, attrs, mangled, dem in real_sites:
    key = (dem, attrs, mangled)
    by_func.setdefault(key, []).append(lineno)

print(f"SIL file: {sil_path}")
print(f"Raw `grep witness_method` line count ...... {raw_lines}")
print(f"  REAL `= witness_method` instructions .... {len(real_sites)}")
print(f"  `$@convention(witness_method:)` annots .. {annotation_only}  (type annotations, not dispatch)")
print()
print("=== REAL witness_method instructions, by enclosing SIL function ===")
for (dem, attrs, mangled), locs in sorted(by_func.items(), key=lambda kv: -len(kv[1])):
    linkage = "public_external" if "public_external" in attrs else \
              ("shared" if "shared" in attrs else (attrs or "(hidden/internal)"))
    print(f"- x{len(locs)}  [{linkage}]  {dem}")
    print(f"      attrs: [{attrs}]   at SIL line(s): {locs}")
    print(f"      mangled: {mangled}")

print()
print("=== Gate 1: the three specialized client paths MUST hold 0 each ===")
client_paths = ["countViaIterable", "sumViaLinearForEach", "sumViaRingForEach"]
gate1_ok = True
for p in client_paths:
    n = sum(len(locs) for (dem, _, _), locs in by_func.items() if p in dem)
    ok = (n == 0)
    gate1_ok &= ok
    print(f"- {p}: {'PASS (0)' if ok else f'FAIL ({n})'}")

print()
print("=== Gate 2: every REAL witness_method must be inside a public_external template ===")
leaks = [(dem, attrs, locs) for (dem, attrs, mangled), locs in by_func.items()
         if "public_external" not in attrs]
if not leaks:
    print("PASS — all REAL witness_method instructions are in public_external (unreachable) templates.")
    gate2_ok = True
else:
    gate2_ok = False
    print("FAIL — REAL witness_method instructions NOT in a public_external template:")
    for dem, attrs, locs in leaks:
        print(f"    x{len(locs)}  [{attrs}]  {dem}  at {locs}")

print()
print("=== Gate 3: the ONLY residual template is Iterable.forEach ===")
non_foreach = [(dem, locs) for (dem, attrs, mangled), locs in by_func.items()
               if "forEach" not in dem or "Iterable" not in dem]
if not non_foreach:
    print("PASS — every REAL witness_method is inside the Iterable.forEach template.")
    gate3_ok = True
else:
    gate3_ok = False
    print("Residual templates other than Iterable.forEach:")
    for dem, locs in non_foreach:
        print(f"    {dem}  at {locs}")

print()
verdict = "0-WITNESS CONFIRMED" if (gate1_ok and gate2_ok and gate3_ok) else "REVIEW REQUIRED"
print(f"VERDICT: {verdict}")
