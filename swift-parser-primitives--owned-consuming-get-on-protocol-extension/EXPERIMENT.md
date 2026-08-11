# `@_owned consuming get` on a Protocol Extension with `~Copyable` Self

<!--
---
version: 1.0.0
last_updated: 2026-05-14
status: COMPLETE
question: Does `@_owned consuming get` on a `Parser.\`Protocol\``-shaped protocol extension work for a generic `~Copyable` Self, on Swift 6.3.2 AND Swift 6.4-dev?
parent_research:
  - swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md (v1.1.0, DECISION)
  - swift-institute/Research/feature-flags-coroutine-borrow-accessors.md
  - swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md (Option A in the Tier-3 doc)
predecessor_experiments:
  - swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables/
  - swift-institute/Experiments/property-consuming-get-and-read/ (V1-V5 REFUTED, V6 CONFIRMED for stored-property struct, 2026-05-04)
production_target:
  - swift-parser-primitives/Sources/Parser Error Primitives/Parser.Error.swift:53-54 (the `.error` accessor)
  - swift-parser-primitives/Sources/Parser Error Primitives/Parser.Error.Map.swift:56-60 (the `.map` follow-up)
toolchains_tested:
  - Swift 6.3.1 RELEASE (`org.swift.631202604131a`) — already installed
  - Swift 6.3.2 RELEASE (`org.swift.632202605101a`) — installed via swiftly 2026-05-14
  - Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`) — already installed
  - Swift 6.4-dev nightly 2026-05-12-a (`org.swift.64202605121a`) — installed via swiftly 2026-05-14 (latest at experiment time)
---
-->

## Question

Does `@_owned consuming get` on a **protocol extension** work for a
`Parser.\`Protocol\``-shaped generic `~Copyable` Self, on **Swift 6.3.2**
AND **Swift 6.4-dev** (latest nightly available)?

The prior research at
`swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md`
v1.1.0 confirmed `@_owned consuming get`:

- **PASS** for non-generic `~Copyable` types (struct + monomorphic enum) on
  Swift 6.4-dev nightly 2026-03-16.
- **FAIL** for generic `~Copyable` enums on Swift 6.4-dev nightly 2026-05-07
  (different structural rejection: "noncopyable 'X' cannot be consumed when
  captured by an escaping closure or borrowed by a non-Escapable type").
- **NOT TESTED**: generic `~Copyable` STRUCTS.
- **NOT TESTED**: protocol-Self extensions (the actual case we care about).

User hint: "might also work in 6.3.2." Verify; some of the Apr 2026 consuming-
accessor PRs may have backported.

## Hypothesis

If the Apr 2026 SILGen / Sema fixes resolved the
"borrowed by a non-Escapable type" rejection for the generic case, then a
`@_owned consuming get` on a protocol extension with generic `Self: ~Copyable`
will compile end-to-end on Swift 6.4-dev, and the production call-site
`parser.error.map { ... }` will compose. The user's hint suggests the same may
hold on Swift 6.3.2.

## Variants

Five variants exercise the gating shapes incrementally per [EXP-004a]:

| # | Shape | What it isolates |
|---|---|---|
| **V1** | Non-generic struct `V1_NC: ~Copyable` with `@_owned var extracted: V1_NC { consuming get { V1_NC(...) } }` | Baseline replication of the prior research's PASS shape — confirms the toolchain has the `@_owned` attribute. |
| **V2A** | Generic struct `V2_Container<T: ~Copyable>: ~Copyable` with `@_owned var marker: Int { consuming get { 42 } }` (return type is unrelated copyable Int) | Generic-struct shape + `@_owned`; isolates whether the GENERIC-STRUCT case (untested in prior research) fails the same way as generic-enum. |
| **V2B** | Generic struct `V2_ContainerExtract<T: ~Copyable>: ~Copyable` with `@_owned var value: T { consuming get { stored } }` (extracts stored generic field) | Generic-struct shape with stored-field extraction — the V6-equivalent property form gated by `@_owned`. |
| **V3** | Protocol `V3_Protocol: ~Copyable`; generic conformer `V3_Container<T>: V3_Protocol, ~Copyable`; `@_owned var transform: V3_Transform<Self>` defined on `extension V3_Protocol where Self: ~Copyable` | The PROTOCOL-EXTENSION case — directly analogous to `Parser.\`Protocol\`.error`. |
| **V4** | Full end-to-end: `c.error.map { _ in V4_NewFailure.mapped(99) } → V4_Map<V3_Container<Int>, V4_NewFailure>` chain, with all types `~Copyable`, `V4_Map` conforming to `V3_Protocol` | End-to-end production-shape composition: does `parser.error.map { ... }` compose? |
| **V5** | Direct call-site (NO consuming-parameter wrapper) of V2A, V3, V4, plus explicit `consume c` keyword variant | Whether the wrappers used in V1-V4 are mandatory or whether the production call-site shape `parser.error.map { ... }` compiles directly. |

## Toolchain results matrix

| Variant | 6.3.1 | 6.3.2 | 6.4-dev 2026-05-07 | 6.4-dev 2026-05-12 |
|---|---|---|---|---|
| V1 (non-generic struct, wrapped via direct call) | FAIL: unknown attribute '_owned' | FAIL: unknown attribute '_owned' | **PASS** | **PASS** |
| V2A (generic struct returning Int, wrapped) | FAIL: unknown attribute '_owned' | FAIL: unknown attribute '_owned' | **PASS** | **PASS** |
| V2B (generic struct extracting stored T, wrapped) | FAIL: unknown attribute '_owned' | FAIL: unknown attribute '_owned' | **PASS** | **PASS** |
| V3 (protocol-extension Transform<Self>, wrapped) | FAIL: unknown attribute '_owned' | FAIL: unknown attribute '_owned' | **PASS** | **PASS** |
| V4 (end-to-end `error.map` chain, wrapped) | FAIL: unknown attribute '_owned' | FAIL: unknown attribute '_owned' | **PASS** | **PASS** |
| V5a (V2A direct call-site, no wrapper) | n/a — earlier rejection | n/a — earlier rejection | **FAIL**: borrowed by non-Escapable | **FAIL**: borrowed by non-Escapable |
| V5b (V3 direct call-site, no wrapper) | n/a | n/a | **FAIL**: borrowed by non-Escapable | **FAIL**: borrowed by non-Escapable |
| V5c (V4 direct call-site, no wrapper) | n/a | n/a | **FAIL**: borrowed by non-Escapable | **FAIL**: borrowed by non-Escapable |
| V5d (`consume c` keyword on V3) | n/a | n/a | not retested | **CRASH**: SIL verifier abort (`MemoryLifetimeVerifier.cpp:263`) |

**Runtime verification** of V1-V4 on Swift 6.4-dev nightly 2026-05-12:

```
=== owned-consuming-get-on-protocol-extension ===
V1 (non-generic struct, @_owned consuming get) -> 42
V2A (generic struct, @_owned returning Int marker) -> 42
V2B (generic struct, @_owned extracting stored ~Copyable field) -> 99
V3 (protocol-extension @_owned consuming get) -> 42
V4 (end-to-end parser.error.map chain) -> 7
All variants PASS.
```

`[Verified: 2026-05-14]`

## Diagnostic transcripts (verbatim)

### V1-V4 on Swift 6.3.2 — `@_owned` attribute not recognized

Verbatim from `TOOLCHAINS=org.swift.632202605101a swift build`:

```
/Users/coen/Developer/swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/Sources/owned-consuming-get-on-protocol-extension/V1_NonGenericStruct.swift:17:6: error: unknown attribute '_owned'
15 |     }
16 | 
17 |     @_owned
   |      `- error: unknown attribute '_owned'
18 |     public var extracted: V1_NC {
19 |         consuming get {
```

Same error fires 20 times across V1-V4 on 6.3.2 and 6.3.1 (one per `@_owned` site).

`[Verified: 2026-05-14]` on both 6.3.1 (`org.swift.631202604131a`) and 6.3.2 (`org.swift.632202605101a`).

### V1-V4 on Swift 6.4-dev (BOTH 2026-05-07 and 2026-05-12) — first attempt without consuming-parameter wrappers

Verbatim from `TOOLCHAINS=org.swift.64202605121a swift build`, when V2-V4 were authored as direct
function-scope reads:

```
/Users/coen/Developer/swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension/Sources/owned-consuming-get-on-protocol-extension/V2_GenericStruct.swift:54:14: error: noncopyable 'c' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type
52 | public func runV2A() -> Int {
53 |     let c = V2_Container<V1_NC>(V1_NC(99))
54 |     return c.marker // 42
   |              `- error: noncopyable 'c' cannot be consumed when captured by an escaping closure or borrowed by a non-Escapable type
```

This is the **same structural rejection** that blocked Phase 2 of the prior
research at
`noncopyable-property-extract-via-underscore-owned.md` v1.1.0 for generic
`~Copyable` enums. Empirically, it generalises to:

- Generic `~Copyable` structs (V2A — returning unrelated copyable type)
- Generic `~Copyable` structs (V2B — extracting stored generic field)
- Protocol-extension `@_owned` getters on `~Copyable` Self (V3)
- End-to-end chained accessors (V4)

`[Verified: 2026-05-14]` on Swift 6.4-dev nightlies 2026-05-07-a and 2026-05-12-a.

### V5d (`consume c` keyword on V3) on Swift 6.4-dev 2026-05-12 — SIL verifier crash

Verbatim from `TOOLCHAINS=org.swift.64202605121a swift build`:

```
SIL memory lifetime failure in @$s41owned_consuming_get_on_protocol_extension19runV5ConsumeKeywordSiyF: store-borrow location cannot be written
memory location:   %22 = store_borrow %20 to %21 : $*V3_Container<Int> // users: %25, %24
at instruction:   %24 = apply %23<V3_Container<Int>>(%15, %22) : $@convention(method) <τ_0_0 where τ_0_0 : V3_Protocol, τ_0_0 : ~Copyable> (@in τ_0_0) -> @out V3_Transform<τ_0_0>

Abort: function reportError at MemoryLifetimeVerifier.cpp:263
```

The compiler reports:

```
1.	Apple Swift version 6.5-dev (LLVM 7c86461e21cca7e, Swift 6da4da7153e8252)
2.	Compiling with the current language version
3.	While evaluating request ASTLoweringRequest(Lowering AST to SIL for file ".../V5_DirectCallSite.swift")
4.	While silgen visitDecl 'runV5ConsumeKeyword()' (at .../V5_DirectCallSite.swift:37:8)
5.	While silgen emitFunction SIL function "@$s41owned_consuming_get_on_protocol_extension19runV5ConsumeKeywordSiyF".
6.	While verifying SIL function "@$s41owned_consuming_get_on_protocol_extension19runV5ConsumeKeywordSiyF".
7.	Abort: function reportError at MemoryLifetimeVerifier.cpp:263
```

This is a distinct compiler bug (SIL verifier failure on `store_borrow` of a
`consume`-keyword-promoted noncopyable value into a `@in` argument slot of a
`~Copyable` protocol witness). Reportable as an issue.

`[Verified: 2026-05-14]` on Swift 6.4-dev nightly 2026-05-12-a (latest at
experiment time, builds the `swift-DEVELOPMENT-SNAPSHOT-2026-05-12-a` toolchain
which reports `Apple Swift version 6.5-dev` internally).

### V1-V4 on Swift 6.4-dev with consuming-parameter wrappers — PASS

After refactoring V2-V4 to route the read through a consuming-parameter wrapper:

```swift
@inlinable
public func extractV3Transform<P: V3_Protocol & ~Copyable>(_ p: consuming P) -> V3_Transform<P> {
    p.transform
}

@inlinable
public func runV3() -> Int {
    let c = V3_Container<Int>(42)
    let t = extractV3Transform(c)
    return t.tokenize() // 42
}
```

…all five variants (V1, V2A, V2B, V3, V4) compile cleanly and produce the
expected runtime values. The protocol-extension `@_owned consuming get` works
**only when the reader is a consuming-parameter function**, not when invoked at
the binding site of the noncopyable value.

`[Verified: 2026-05-14]` on Swift 6.4-dev nightlies 2026-05-07-a and 2026-05-12-a.

## Empirical findings

1. **Swift 6.3.2 does NOT support `@_owned`.** The attribute is gated behind
   the experimental feature `UnderscoreOwned`, which (as of 6.3.2) is not yet
   present in the Sema attribute table. The user's hint "might also work in
   6.3.2" is **REFUTED**: 20 instances of `error: unknown attribute '_owned'`
   fire on both 6.3.1 (`org.swift.631202604131a`) and 6.3.2
   (`org.swift.632202605101a`).

2. **On Swift 6.4-dev nightlies (both 2026-05-07-a and 2026-05-12-a),
   `@_owned consuming get` works on:**
   - non-generic `~Copyable` structs (V1) — replicates prior research
   - **generic `~Copyable` structs** (V2A, V2B) — NEW finding, not in prior
     research
   - **protocol extensions with generic `~Copyable` Self** (V3) — NEW finding
   - **end-to-end chained accessors** (V4) — NEW finding
   …**but ONLY when the read is wrapped in a consuming-parameter function**.

3. **The "borrowed by a non-Escapable type" diagnostic still fires at the
   direct call-site (V5).** This is the same structural rejection that blocked
   Phase 2 in the prior generic-enum research. The Apr 2026 SILGen wave did
   NOT resolve the local-binding read pattern; it appears to have moved the
   resolution point into the consuming-parameter signature where the compiler
   can prove the value flows directly into the consuming accessor.

4. **`consume c` keyword at the direct call-site CRASHES the compiler** with a
   SIL verifier failure (`MemoryLifetimeVerifier.cpp:263`,
   "store-borrow location cannot be written"). This is a separate, reportable
   compiler bug.

5. **The production call-site shape `parser.error.map { ... }` does NOT
   compile** when invoked on a noncopyable parser local at function scope on
   any tested toolchain. The wrapper-only success pattern requires every
   caller to wrap `parser.error.map { ... }` in a consuming-parameter helper
   function — which is API-disruptive and ergonomically worse than the
   method-form migration the user explicitly rejected.

## Conclusion

**Status**: BLOCKED for production use.

**For Tier-3 Option A** (preserve `parser.error.map { ... }` via
`@_owned consuming get`):

- **Empirically VIABLE in narrow form**: `@_owned consuming get` on a protocol
  extension with generic `~Copyable` Self compiles and runs correctly on
  Swift 6.4-dev nightlies 2026-05-07-a and later, **when invoked from a
  consuming-parameter function**.

- **Empirically NOT VIABLE for production**: the typical production call-site
  shape — a parser bound to a local `let` and read via
  `parser.error.map { ... }` — fails to compile on every tested toolchain
  with the "borrowed by a non-Escapable type" diagnostic. Adopting Option A
  would require every consumer of the `.error` accessor to wrap the call in
  a consuming-parameter helper, defeating the purpose of preserving the
  fluent-property syntax.

- **Toolchain floor**: Swift 6.4-dev (any nightly from 2026-05-07 forward).
  The narrow-form viability is locked behind a not-yet-released toolchain;
  the production toolchain (6.3.2) cannot recognise `@_owned` at all.

**Recommendation**:

- **Option A is empirically BLOCKED.** Even on the latest nightly, the
  direct-call-site shape that production callers use does not compile. The
  consuming-parameter-wrapper workaround is no better than the
  user-rejected method-form migration (worse, actually — it pushes the
  consuming-binding requirement to every call site instead of one
  declaration site).

- **Recommend Option B or Option C** per the Tier-3 doc:
  - Option B: `Property.View` as ownership-transfer layer.
  - Option C: `Map: ~Copyable, ~Escapable` with pointer storage.

  Pick between B and C based on the broader cohort-level constraints
  documented in
  `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`,
  not on this experiment.

**Phase 3 implications (commit `3ed1961` reverted cascade)**: this empirical
result does **not** unblock the combinator cascade. The cascade requires
fluent property access at call sites (`parser.error.map`,
`parser.tracked.range`, etc.); the wrapper workaround would force every
combinator's `.error`, `.tracked`, etc. accessor to be invoked via a
consuming-parameter helper — equivalent in disruption to the method-form
migration that has been rejected.

**Phase 4 implications (`Parser.Machine.Compiled: ~Copyable`, Row 11)**: this
finding tightens the constraint. If `Parser.Machine.Compiled` becomes
`~Copyable`, its consumer surface (which uses `.compile`, `.run`, etc. as
property accessors) inherits the same direct-call-site blocker. Any
combinator-style accessor on Compiled would have the same wrapper requirement.

## Reproducing

```bash
cd /Users/coen/Developer/swift-primitives/swift-parser-primitives/Experiments/owned-consuming-get-on-protocol-extension
rm -rf .build

# Swift 6.3.2 (Apple default, installed via swiftly):
TOOLCHAINS=org.swift.632202605101a swift build
# Expected: 20 × "error: unknown attribute '_owned'"

# Swift 6.4-dev nightly 2026-05-07-a:
TOOLCHAINS=org.swift.64202605071a swift run
# Expected: V1-V4 PASS

# Swift 6.4-dev nightly 2026-05-12-a (latest at experiment time):
TOOLCHAINS=org.swift.64202605121a swift run
# Expected: V1-V4 PASS

# To re-test V5 direct-call-site (currently commented out in V5_DirectCallSite.swift):
# uncomment the runV5Direct* functions in V5_DirectCallSite.swift and rebuild.
# Expected: "borrowed by non-Escapable" errors on each direct-call function.
# DO NOT uncomment runV5ConsumeKeyword — it crashes the compiler.
```

## References

- Parent research:
  - `swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md` v1.1.0 (DECISION, 2026-05-09)
  - `swift-institute/Research/feature-flags-coroutine-borrow-accessors.md`
  - `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`

- Predecessor experiments:
  - `swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables/` (witness-table SIGSEGV REFUTED, 2026-05-13)
  - `swift-institute/Experiments/property-consuming-get-and-read/` (V1-V5 REFUTED, V6 CONFIRMED, 2026-05-04)

- Production target:
  - `swift-parser-primitives/Sources/Parser Error Primitives/Parser.Error.swift:53-54` — the `.error` accessor
  - `swift-parser-primitives/Sources/Parser Error Primitives/Parser.Error.Map.swift:56-60` — the `.map` follow-up
  - `swift-parser-primitives/Sources/Parser Primitives Core/Parser.Parser.swift:90` — `Parser.\`Protocol\``

- swiftlang/swift HEAD context:
  - `include/swift/AST/DeclAttr.def:611` — `@_owned` attribute definition
  - `include/swift/Basic/Features.def:611` — `UnderscoreOwned` experimental feature
  - PR #88699 (`645e2dc3bad`, 2026-04-30) — consuming-accessor resilient base
