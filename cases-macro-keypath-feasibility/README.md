# cases-macro-keypath-feasibility

**Spike B** — de-risks routing-arc **W1** (the arc's riskiest item). Determines
macro feasibility for the `@Cases` design's hard parts and lands a verdict. This
spike gates W1's approach; it does **not** start W1.

The production home for `@Cases` will be `swift-foundations/swift-dual` next to
`@Dual`. This experiment reproduces swift-dual's enum-analysis patterns in a
minimal member+extension macro **without importing or editing swift-dual**, and
**without any pointfreeco dependency** (no `swift-case-paths`) — the spike proves
the institute-native shape.

---

## Verdict: **FEASIBLE**

The R3-plan call-site shape — `KeyPath<Enum.Cases, Case.Path<Enum, Value>>` — type-checks
and behaves for all three hard parts on Apple Swift 6.3.3. `swift build` and
`swift test` both exit `0`; 9/9 behavioral test cases pass, exercised **across a
module boundary** (enums in `CasesSubject`, call sites in the `CasesTests` module)
per [EXP-017].

| Hard part | Result |
|---|---|
| 1. `.is(\.case)` / `.case(\.case)` keypath-literal shape | **CONFIRMED** |
| 2. Depth-3 `@dynamicMemberLookup` composition `\.authenticate.api.credentials` | **CONFIRMED** |
| 3. Coexistence next to another member/extension macro (the `@Dual` shape) | **CONFIRMED** (one call-site caveat, part 3 below) |

The verdict is **FEASIBLE**, not *feasible-with-shape-change*: no R3 call-site
shape had to change. But the spike surfaced **three load-bearing implementation
requirements** the R3 shape *implies* and W1 must honor — see "Requirements W1
must honor" below. The most important: the composition mechanics differ from
`@Dual`'s current prism surface.

---

## Hypothesis

A generated per-case witness type (`Enum.Cases`) plus a case-path value type
(`Case.Path<Root, Value>`) can be shaped so that:

1. a **keypath literal** `\.list` type-checks when passed to an `is(_:)` predicate
   (`route.is(\.list)`) and to a `.case(...)` combinator (`.case(\.list)`); and
2. nested `@Cases` enums compose to depth 3 (`\.authenticate.api.credentials`),
   with the composed embed/extract behaving correctly; and
3. the macro is attachable to an enum alongside another member/extension macro
   (the `@Dual` shape) without a name collision on the generated witness.

## Method

Minimal package, five targets:

| Target | Role |
|---|---|
| `CasesRuntime` | `Case.Path<Root, Value>` (embed/extract, `@dynamicMemberLookup`), the `CaseAnalyzable` witness protocol, `Routes<Root>` / `makeCase` combinators, `DualLikeMarker`. No deps. |
| `CasesMacrosImplementation` (`.macro`) | Reproduces swift-dual's `extractCases` / `isPublicDecl` analysis; `@Cases` (member + extension) and `@DualLike` (coexistence stand-in for `@Dual`). |
| `CasesMacros` | Public macro declarations; `@_exported import CasesRuntime`. |
| `CasesSubject` | Test enums with `@Cases`; a same-module type-check proof. |
| `CasesTests` | XCTest behavioral proof, **cross-module** (imports `CasesSubject`). |

The mechanism mirrors point-free's shipping `CaseKeyPath` composition, re-rooted at
the generated `Cases` witness (rather than a `Case<Root>` wrapper) so the composed
literal lands on exactly the R3-named type `KeyPath<Enum.Cases, Case.Path<Enum, Value>>`.

### The generated shape (per `@Cases enum Route`)

```swift
extension Route {
    struct Cases {
        var list: Case.Path<Route, Void> { … }   // one property per case
        var detail: Case.Path<Route, Int> { … }
    }
    static var cases: Cases { Cases() }
    func `is`<Value>(_ keyPath: KeyPath<Cases, Case.Path<Route, Value>>) -> Bool {
        Self.cases[keyPath: keyPath].extract(self) != nil
    }
}
extension Route: CaseAnalyzable {}
```

Depth-3 works because `Case.Path` is itself `@dynamicMemberLookup`: appending
`.api` to a `Case.Path<AppRoute, AuthRoute>` (where `AuthRoute: CaseAnalyzable`)
invokes `subscript(dynamicMember: KeyPath<AuthRoute.Cases, Case.Path<AuthRoute, Sub>>)`,
which threads embed/extract and returns `Case.Path<AppRoute, Sub>` — again
`@dynamicMemberLookup`. So `\.authenticate.api.credentials` is a
`KeyPath<AppRoute.Cases, Case.Path<AppRoute, Credentials>>`.

## Evidence

- **Build**: `swift build` → exit `0` (`Outputs/build.txt`, "Build complete!").
  `CasesSubject` compiles, which alone proves every keypath-literal call site
  type-checks (the same-module proof in `SameModuleTypecheck.swift`).
- **Test**: `swift test` → exit `0`; `Executed 9 tests, with 0 failures`
  (`Outputs/test.txt`). Cross-module.
- **Round-trips proven** (`Tests/CasesTests/CasesTests.swift`):
  - depth-1 embed/extract for no-payload, single-payload, and multi-payload (tuple) cases;
  - depth-3 `\.authenticate.api.credentials` embed → `.authenticate(.api(.credentials(c)))`
    and extract back to `c`, with negative extractions (`.home`, `.authenticate(.login)`,
    `.authenticate(.api(.status))`) all returning `nil`;
  - depth-1, depth-2, depth-3 `is(_:)` predicates;
  - `.case(\.case)` via `Routes<Route>.case(\.list)` (Root pinned by generic namespace)
    and `makeCase(\.detail)` (Root pinned by result-type annotation), including a
    composed `Routes<AppRoute>.case(\.authenticate.api.credentials)`.

---

## Requirements W1 must honor

These are not changes to the R3 call-site shape (which is confirmed as-is); they
are the machinery the shape depends on. W1's implementation in swift-dual must
carry them.

1. **Composition mechanics — the value type must be `@dynamicMemberLookup` + a
   witness protocol.** Depth-3 requires (a) `Case.Path<Root, Value>` to be
   `@dynamicMemberLookup` with a `KeyPath`-based `subscript(dynamicMember:)`
   composing embed/extract, and (b) every nested enum to conform to a witness
   protocol (`CaseAnalyzable` here: `associatedtype Cases` + `static var cases`),
   generated by the macro's extension role.
   **This is the key delta from `@Dual`.** `@Dual`'s current per-case value type
   is `Optic.Prism<Root, Value>`, which is **not** `@dynamicMemberLookup`, so
   `@Dual`'s `is(\.case)` is depth-1 only. `@Cases` cannot reuse the prism value
   type verbatim for composition — it needs the `Case.Path` value type shaped as
   above. (If W1 chose to reuse `@Dual`'s prism plumbing unchanged, *that* would
   be the shape change; building `Case.Path` fresh — as R3 names it — needs none.)

2. **`.case(\.case)` needs `Root` pinned by builder context.** A leading-dot
   keypath literal carries no root type of its own. `Routes<Route>.case(\.list)`
   (generic namespace) and `let p: Case.Path<Route, Int> = makeCase(\.detail)`
   (annotation) both work because they pin `Root`. A *fully unpinned*
   `makeCase(\.list)` cannot infer `Root` — this is expected and identical to
   point-free's requirement that a route builder fix the root type. Diagnostic
   captured on 6.3.3:

   ```
   error: generic parameter 'Root' could not be inferred
   error: generic parameter 'Value' could not be inferred
   error: cannot infer key path type from context; consider explicitly specifying a root type
   ```

   Implication for W1: the routing DSL's `.case` combinator must sit inside a
   context that fixes the route enum (a `OneOf`-style builder or a `Root`-generic
   namespace) — which it already does. No blocker.

3. **Coexistence caveat — do not co-attach `@Cases` and `@Dual` to the *same*
   enum.** Witness *types* do not collide: `@Cases` generates `Cases`/`cases`,
   `@Dual`/`@DualLike` generate `Prisms`/`prisms`; both extension macros' distinct
   conformances (`CaseAnalyzable`, `DualLikeMarker`) coexist. All confirmed
   (`testCoexistenceWitnessTypesDistinct`, `testCoexistenceConformancesBothPresent`).
   **But** if both macros are on one enum, each emits a case-named property on its
   own witness **and** an `is<Value>` overload, so a *bare* `route.is(\.beta)`
   becomes ambiguous (the literal roots at either `Cases` or `Prisms`):

   ```
   error: ambiguous use of 'is'
   ```

   Disambiguating the witness root (`route.is(\CoexistRoute.Cases.beta)`) resolves
   it. In production `@Cases` **supersedes** `@Dual`'s prism `is` surface (the arc
   removes the case-paths dependency), so co-attachment on one type is not the
   intended usage. "`@Cases` next to `@Dual`" means **same-package** coexistence,
   which is fully clean. W1 should not emit both surfaces on one type.

---

## How to reproduce

```bash
cd /Users/coen/Developer/swift-institute/Experiments/cases-macro-keypath-feasibility
swift build      # first run compiles swift-syntax from source (several minutes)
swift test       # 9/9 pass, cross-module

# To reproduce the part-2/part-3 diagnostics quoted above, add a source file to
# Sources/CasesSubject/ containing `_ = makeCase(\.list)` (unpinned) and, on a
# @Cases @DualLike enum value, `_ = value.is(\.beta)` (bare), then `swift build`.
```

## Toolchain

Apple Swift 6.3.3 (`swiftlang-6.3.3.1.3 clang-2100.1.1.101`), macOS 26 / arm64,
2026-07-11. swift-syntax pinned `602.0.0..<603.0.0` (matches swift-dual).

## See also

- `swift-foundations/swift-dual/Sources/Dual Macros Implementation/` — the
  enum-analysis machinery and generated-name conventions this spike reproduces
  (`extractCases`, `isPublicDecl`; `Prisms` witness; `is`/`subscript[prism:]`).
  swift-dual's `Optic.Prism` value type is depth-1 only — the composition delta
  in Requirement 1 above.
