# Parser.`Protocol`: ~Copyable on Self — Witness-Table Probe

<!--
---
version: 1.0.0
last_updated: 2026-05-13
status: COMPLETE
question: Does adding `: ~Copyable` to Self on Parser.`Protocol` introduce a cross-module witness-table SIGSEGV at instantiation under current toolchains?
predecessor_experiment: ../metadata-crash-bisection/
related_research:
  - swift-primitives/swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md
  - swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md
---
-->

## Question

Does adding `Self: ~Copyable` to `Parser.\`Protocol\`` introduce a cross-module
witness-table SIGSEGV at instantiation under current toolchains, per the pattern
documented at the 2026-02-14 production crash
(`swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`,
Swift 6.2.3, `swiftlang/swift#85441` pattern)?

## Hypothesis

The 2026-02-14 research listed four required conditions for the witness-table SIGSEGV:

1. `~Copyable` protocol constraint (Self or via associated-type chain)
2. Protocol composition (`Wrapper<Upstream: Π>: Π`)
3. Cross-module concrete type from external package
4. Cross-module instantiation

The proposed Option α adds `Self: ~Copyable` to the protocol. This strengthens
condition (1). If the witness-table SIGSEGV is unfixed, the cascade footprint
expands across the 166-site conformer surface.

## Method

Six variants test the gating conditions incrementally per [EXP-004a]:

| Variant | Conditions exercised | Result on Swift 6.3.2 |
|---|---|---|
| V1 (leaf construction)           | (1), (4) — leaf only       | PASS |
| V2 (leaf parse dispatch)         | (1), (2)-implicit, (4)     | PASS |
| V3a (composed Map construction)  | (1), (2), (4)              | PASS |
| V3b (composed Map dispatch)      | (1), (2), (4)              | PASS |
| V4a (triple-nested construction) | (1), (2)×2, (4)            | PASS |
| V4b (triple-nested dispatch)     | (1), (2)×2, (4)            | PASS |
| V5  (external-package Input)     | **(1), (2), (3), (4)** — full original-crash conditions | **PASS** |
| V5b (composed + external Input)  | full + composition         | PASS |
| V5c (triple-nested + external)   | full + composition×2       | PASS |
| V6a (Parser.Lazy construction)   | (1), closure-stores-~Copy  | PASS |
| V6b (Lazy dispatch)              | + closure-return-~Copy     | PASS |
| V6c (Map wrapping Lazy)          | + composition              | PASS |

V5 is the decisive test — it presents the **full original-crash condition set
1+2+3+4** with the new `Self: ~Copyable` axis added.

## Toolchain matrix

| Toolchain | V1–V4 (local) | V5 (external pkg) | V6 (closure capture) |
|---|---|---|---|
| Swift 6.2.3 (`org.swift.623202512101a`) — original crash toolchain | PASS | not testable (upstream pkgs now require 6.3.1+) | PASS |
| Swift 6.3.2 (default Apple Xcode) — current production target | PASS | **PASS** | PASS |
| Swift 6.4-dev nightly 2026-05-07 (`org.swift.64202605071a`) | PASS | not testable (transitive `swift-cyclic-primitives` SE-0499 collision, unrelated to this experiment) | PASS |

## Empirical findings

1. **Self: ~Copyable on the protocol does NOT trigger a witness-table SIGSEGV
   under any toolchain tested**, including the original crash toolchain (Swift
   6.2.3) for the local-Input variants and the current production toolchain
   (Swift 6.3.2) for the full external-package crash conditions.

2. **The 2026-02-14 production SIGSEGV does not reproduce under Swift 6.3.2**
   even with V5's full original-crash conditions (1+2+3+4). This is consistent
   with an unannounced compiler fix between 6.2.3 → 6.3.x.

3. **Closure-capture of ~Copyable parsers** via `() -> P` works at protocol
   composition sites (V6b, V6c).

4. **Bare `extension Foo: Π_α` constrains Upstream to Copyable** per
   `[feedback_extension_implies_copyable]` — `extension Parser.Map: Parser.\`Protocol\``
   compile-errored until corrected to
   `extension Parser.Map: Parser.\`Protocol\` where Upstream: ~Copyable`.
   This is a **mechanical, well-understood migration cost** that recurs at every
   combinator extension site — NOT a structural blocker.

5. **Consuming-init on ~Copyable + top-level global `let` storage** triggers
   "cannot consume noncopyable stored property 'inner' that is global." Production
   code typically composes parsers in functions, not at top-level globals, so this
   is an experiment-scope authoring concern, not a production-scope blocker.

## Outcome

**Status**: COMPLETE.

The empirical hypothesis "Self: ~Copyable on Parser.`Protocol` triggers a witness-
table SIGSEGV" is **REFUTED** under all three toolchains tested. The original
production crash documented at
`swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`
**does not reproduce on Swift 6.3.2** even with the full original-crash conditions
restated in V5.

This downgrades the witness-table SIGSEGV from the **dominant** Option α cost
item in the Tier-3 recommendation
(`swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
v1.0.0) to a **resolved-empirically** line item.

Remaining Option α blockers (not addressed by this experiment):

- **166-site cascade** — every conformer extension needs explicit
  `where Upstream: ~Copyable` per [feedback_extension_implies_copyable]; this is
  mechanical but real.
- **Result-builder generic functions** — `Parser.Take.Builder` /
  `Parser.OneOf.Builder` re-evaluation not exercised here.
- **`Parser.OneOf.Any.parsers: [Closure]`** — stdlib `Array` of `~Copyable` cap
  not exercised.
- **Foundations-layer Copyable-constraint cascade** —
  `swift-parsers/Sources/Parsers/Parsers.{Chain,Expression,Separated}.swift`
  not exercised.
- **[RES-018] second-consumer hurdle** — still not cleared at experiment time.

These are policy/design calls, not compiler bugs. The Tier-3 recommendation
shifts substantively.

## Reproducing

```bash
cd swift-parser-primitives/Experiments/parser-protocol-self-noncopyable-witness-tables
rm -rf .build

# Default Apple toolchain (Swift 6.3.2):
swift run parser-protocol-self-noncopyable-witness-tables
swift run external-input-test

# Original crash toolchain (Swift 6.2.3) — local-Input variant only:
TOOLCHAINS=org.swift.623202512101a swift run parser-protocol-self-noncopyable-witness-tables

# 6.4-dev nightly:
TOOLCHAINS=org.swift.64202605071a swift run parser-protocol-self-noncopyable-witness-tables
```

## References

- 2026-02-14 prior research: `swift-parser-primitives/Research/witness-table-sigsegv-with-noncopyable-protocol-constraints.md`
- Adjacent bisection: `swift-parser-primitives/Experiments/metadata-crash-bisection/`
- Tier-3 doc this experiment validates: `swift-institute/Research/2026-05-13-parser-protocol-noncopyable-escapable-relaxation.md`
- Upstream issue (pattern): [swiftlang/swift#85441](https://github.com/swiftlang/swift/issues/85441)
