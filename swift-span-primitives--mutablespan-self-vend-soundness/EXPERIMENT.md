# mutablespan-self-vend-soundness

**Status:** CONFIRMED (concrete) · **Toolchain:** Apple Swift 6.3.2 · **Platform:** macOS 26 (arm64) · **Date:** 2026-06-23

## Question

The mutable-linchpin step of the `span-typealias-hosting` redesign makes a bare `Swift.MutableSpan` conform to the mutable span-vending capability by **vending itself** (requiring `~Escapable` restated on the protocol). The research doc `Research/span-capability-stdlib-alignment-and-escapable.md` flagged this as soundness-gated, not principle-gated. Is the `MutableSpan` self-vend **sound** — does the vended `mutableSpan` actually alias the backing storage — cross-module and in release? ([EXP-017].)

## Variants

| # | Self-vend body | Result | Evidence |
|---|---|---|---|
| V1 | `mutating get { self }` | **REFUTED** | full build: `error: missing reinitialization of inout parameter 'self' after consume` — returning `self` consumes the `~Copyable` MutableSpan. *(A `-typecheck`-only probe passes this — the error is an ownership-pass diagnostic, so this experiment requires a real build.)* |
| V2 | `mutating get { extracting(...) }` (non-consuming full-range re-borrow) | **CONFIRMED** | `Outputs/run.txt` + `run-release.txt`: `storage [21,5,9] → [42,105,109]` via the self-vended `mutableSpan`, **identical in debug and release**, cross-module. |

`extracting(_:)` (the unbounded-range, non-`@unsafe` `mutating func`, stdlib `MutableSpan` `:22516`) re-borrows `self` exclusively and returns a `MutableSpan` over its storage tied to the `&self` borrow — so it does not consume `self`, and writes through it reach the backing memory.

## Caveat (orthogonal, pre-existing)

Forwarding the `var mutableSpan` form **through a constrained generic** (`func f<T: …Mutable.Protocol>(_ t: inout T) { var m = t.mutableSpan … }`) fails with *"'t.mutableSpan' is borrowed and cannot be consumed."* This is the package's already-documented **no-generic-`mutableSpan` gate** (`Span.Mutable.Protocol.swift`: "probe-proven insufficient for generic forwarding … structural, not conventional") — it applies to the existing `var mutableSpan` requirement regardless of the linchpin, and the existing design routes generic forwarding through the `mutableSpan(count:)` **function** instead. The linchpin therefore inherits the existing var-form limitation; it does not introduce a new one. This spike tests the linchpin **concretely**, which is where its self-vend soundness lives.

## Outcome

**Status: CONFIRMED (concrete).** The `MutableSpan` mutable-linchpin is expressible and **soundly aliases** its backing storage (debug + release, cross-module) — provided the self-vend uses the non-consuming `extracting(...)`, not `{ self }`. The `~Escapable` restatement does not make any owner `~Escapable` (it only admits the already-`~Escapable` `MutableSpan`). So the research doc's gate is **passed for concrete use**; the open ergonomics question (a `borrow`/`mutate`-accessor form that also forwards generically) is deferred to a follow-on (V3) pending an SE-0507-capable toolchain.

## Reproduce

```bash
swift build && swift build -c release && swift run && swift run -c release
# expect: storage after mutate-via-linchpin = [42, 105, 109]  (debug AND release)
```
