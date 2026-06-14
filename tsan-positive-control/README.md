# tsan-positive-control

The **positive control** for the carved ThreadSanitizer gate.

## Why this exists

The tower's TSan gate runs with a ratified carve on its sanitized legs —
`-Xllvm -sil-disable-pass=lifetime-dependence-diagnostics` ([TEST-037] + the compiler-bug
catalog §B8) — to work around a compiler interaction between TSan and lifetime-dependence
diagnostics. A carve that narrows a diagnostic risks *blinding* the sanitizer. This package is
the live-signal proof that it does not: it seeds intentional data races (through the exact
`Shared`-`Box` mechanism shape) that ThreadSanitizer MUST report. A quiet TSan run on a real
suite is only interpretable when this control still fires.

Per the standing ruling, the positive control rides **every** carved-TSan gate.

## What it tests

- `boxRace` — the canonical race: N tasks read-modify-write one box field unsynchronized.
- `gateBypassRace` — the `Shared`-misuse shape: sibling CoW copies share one box, each mutating
  through the assume-unique lane (uniqueness gate present at the type, bypassed at the call).

Both are **expected to fail** under TSan with `ThreadSanitizer: data race` reports.

## How to run

```bash
TOOLCHAINS=org.swift.632202605101a swift test \
  --sanitize=thread \
  -Xswiftc -Xllvm -Xswiftc -sil-disable-pass=lifetime-dependence-diagnostics
```

**Expected:** more than zero `ThreadSanitizer: data race` reports. **Zero reports means the gate
is blind** — investigate before trusting any quiet TSan run.

## Provenance

Re-homed from `.handoffs/probes-2026-06-11/tsan-spike/positive-control/` (the W1 shared-soundness
spike, `GOAL-tower-arc-shared-soundness §W1.3`) to this durable location in **Round P P0.4**, so
the carved-gate discipline survives publication.
