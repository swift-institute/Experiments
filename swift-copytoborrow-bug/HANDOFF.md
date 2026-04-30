# CopyToBorrowOptimization Miscompiles Actor State Under WMO

## Summary

`CopyToBorrowOptimization` + WMO causes an actor's `guard state == .running`
to be constant-folded to `true` after shutdown. Three swift-io shutdown tests
fail in release mode. Self-contained 87-line reproducer at
`/Users/coen/Developer/swift-institute/Experiments/copytoborrow-actor-state-mutex-miscompile/`.

## Reproducer (Self-Contained)

`/Users/coen/Developer/swift-institute/Experiments/copytoborrow-actor-state-mutex-miscompile/` — zero external deps.

```bash
swift build -c release && .build/release/BugTest                        # BUG 100/100
swift build -c release -Xswiftc -Xllvm \
  -Xswiftc -sil-disable-pass=copy-to-borrow-optimization && \
  .build/release/BugTest                                                 # PASS
```

Swift 6.3 (swiftlang-6.3.0.123.5), macOS 26.2, arm64.

## Reproducer (Original, Local Deps)

`/Users/coen/Developer/swift-copytoborrow-bug/` — uses swift-kernel, swift-async,
swift-ownership-primitives, swift-buffer-primitives. Same reproduction steps.

## Essential Trigger Conditions

All six are required. Removing any one makes the bug disappear.

| Ingredient | Required? | Detail |
|---|---|---|
| `enum State` on actor | **Yes** | `Bool` doesn't trigger — needs `select_enum` SIL pattern |
| `consuming func close()` on `~Copyable` Scope | **Yes** | `mutating` doesn't trigger |
| `Mutex<Bool>` field on the `~Copyable` Scope | **Yes** | Plain `~Copyable` padding doesn't trigger; stdlib `Mutex` specifically required. Field never needs to be read — just stored. |
| `Selector` struct wrapping Runtime with `register()` forwarding | **Yes** | Direct `runtime.register()` from caller segfaults (separate lifetime issue with `consuming` + `~Copyable`) |
| Custom serial executor (`SerialExecutor` + `unownedExecutor`) | **Yes** | Default actor executor doesn't trigger |
| Cross-module async call | **Yes** | Single-module doesn't trigger |

## What C2B Actually Changes (SIL Analysis)

SIL for `register()`, `shutdown()`, and `Selector.register()` is **identical** between
with-C2B and without-C2B — at SIL, LLVM IR, and machine code levels. The state load
(`ldrb w8, [x8, #0x18]`) and branch (`cbz w8, ...`) are present and correct.

In the original reproducer with real Kernel deps, C2B removes `strong_retain`/`strong_release`
around the `Synchronization` class reference in `enqueue`. But the standalone reproducer has
**no lock, no thread, no job queue** — just `job.runSynchronously(on:)` in `enqueue` — and
still triggers. The Lock/Synchronization retain/release removal was a red herring for root cause,
though it may have been the original catalyst that destabilized the optimization pipeline.

## Where the Bug Manifests

The bug is in **LLVM's optimization of the calling context** (BugTest's `run` function):

1. BugLib compiles with WMO + C2B → produces `.swiftmodule`
2. BugTest compiles against this `.swiftmodule`
3. LLVM optimizes BugTest's `run` function
4. The optimized calling code causes the register continuation to misread the state

**Evidence:**
- `@_optimize(none)` on BugTest's `run()` → **PASS** (100/100)
- Adding diagnostic reads of the state byte in BugTest → **PASS** (Heisenbug)
- `withExtendedLifetime(selector)` does NOT fix it (not a use-after-free)
- BugModule is NOT recompiled between diagnostic/non-diagnostic builds
- BugTest does NOT inline `register` from BugModule (`nm` shows `U` undefined)
- No LTO active (native Mach-O objects, not bitcode)

## Configuration Matrix

| Config | Result |
|--------|--------|
| WMO + C2B enabled (default release) | **FAIL** (100/100) |
| WMO + C2B disabled (`-sil-disable-pass=copy-to-borrow-optimization`) | PASS |
| Debug mode (`-c debug`) | PASS |
| WMO + C2B + `@_optimize(none)` on calling function | PASS |
| WMO + C2B + diagnostic reads of actor state | PASS (Heisenbug) |
| `enum State` replaced with `Bool` | PASS |
| `consuming close()` replaced with `mutating close()` | PASS |
| `Mutex<Bool>` replaced with plain `~Copyable` padding | PASS |
| Selector removed (direct runtime.register() call) | Segfault (separate issue) |

## Workaround for swift-io

Remove `Mutex<Token?>` from the `~Copyable` Scope. Manage shutdown token
via actor isolation instead (e.g., `Actor.run` pattern from
swift-standard-library-extensions). The bug requires stdlib `Mutex` stored
on the `~Copyable` struct — eliminating that breaks the trigger chain.

## Dead Ends

- 4 prior standalone reproducers (single-file, multi-module) — all pass
- `@_optimize(none)` on BugModule functions — does not prevent elimination
- 11 SIL passes tested individually — only `copy-to-borrow-optimization` fixes it
- Fake `@inlinable` FakeKernel module — does not trigger (real deps needed for original repro)
- SIL/IR/asm diff of register/shutdown — identical, not the direct cause
- `withExtendedLifetime(selector)` — does not fix (not use-after-free)
- Lock class retain/release removal — red herring (threadless executor still triggers)

## Reduction History

See `git log --oneline` in `/Users/coen/Developer/swift-institute/Experiments/copytoborrow-actor-state-mutex-miscompile/`:
1. 9-file standalone reproducer with Lock, Loop threads, pipes, TaskExecutor
2. Single-file BugLib
3. Eliminated Lock class (inline os_unfair_lock)
4. Eliminated threads, pipes, job queue (always-inline executor)
5. Eliminated Darwin import, deinit, Failure enum
6. Confirmed: `enum State` required (Bool passes), `consuming` required (mutating passes),
   `Mutex` required (plain ~Copyable passes)

## Environment

- Swift 6.3 (swiftlang-6.3.0.123.5 clang-2100.0.123.102)
- macOS 26.2, arm64
- Xcode default toolchain
