# Experiments Index

Ecosystem-wide experiments for Swift Institute.

## Consolidated Packages

| Directory | Theme | Absorbed | Date | Status |
|-----------|-------|----------|------|--------|
| noncopyable-constraint-behavior | Constraint poisoning from Sequence conformance, cross-module propagation | 8 experiments | 2026-04-02 | CONSOLIDATED |
| noncopyable-access-patterns | Consuming, borrowing, iteration, Optional unwrap for ~Copyable | 7 experiments (2 institute + 5 primitives) | 2026-04-02 | CONSOLIDATED |
| nonescapable-patterns | ~Escapable accessor, storage, protocol, lazy sequence, pointer patterns | 7 experiments | 2026-04-02 | CONSOLIDATED |
| nonsending-dispatch | nonisolated(nonsending) behavior across dispatch contexts | 4 experiments | 2026-04-02 | CONSOLIDATED |

## Experiments

### Name Resolution and Imports

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| exported-import-name-shadowing | @_exported import gives custom Array precedence over Swift.Array in all contexts | 2026-04-04 | Swift 6.3 | CONFIRMED |

### Swift Language Issues

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| bitwisecopyable-lifetime-inference | BitwiseCopyable blocks _read accessor lifetime inference | 2026-01-21 | Swift 6.2 | CONFIRMED |
| noncopyable-inline-deinit | ~Copyable inline storage deinit bug | 2026-01-20 | Swift 6.2 | FIXED 6.2.4 |
| noncopyable-pointer-propagation | Sequence conformance poisons ~Copyable stored properties | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-pointer-propagation-multifile | Multi-file variant of above | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-storage-poisoning | Isolated constraint poisoning test | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-multifile-poisoning | File organization doesn't prevent poisoning | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-sequence-protocol-test | Same-file conformance still poisons | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-protocol-workarounds | Protocols without Element associatedtype | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-cross-module-propagation | ~Copyable constraint propagation across modules | 2026-01-20 | Swift 6.0 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-sequence-emit-module-bug | Module emission failure with ~Copyable + Sequence | 2026-01-20 | Swift 6.2 | SUPERSEDED → noncopyable-constraint-behavior |
| noncopyable-accessor-incompatibility | _read/_modify accessors with ~Copyable containers | 2026-01-20 | Swift 6.2 | FIXED 6.2.4 |
| separate-module-conformance | Module boundaries prevent poisoning | 2026-01-22 | Swift 6.2 | SOLUTION FOUND |
| wrapper-type-approach | Wrapper types avoid direct conformance | 2026-01-22 | Swift 6.2 | WORKAROUND FOUND |
| conditional-copyable-type | Conditional Copyable + deinit conflict | 2026-01-22 | Swift 6.2 | STILL PRESENT 6.3 |
| tagged-family-constraint | Swift cannot constrain to generic tag families | 2026-01-21 | Swift 6.2 | REFUTED |
| phantom-type-noncopyable-constraint | Phantom types require ~Copyable constraint | 2026-01-21 | Swift 6.2 | CONFIRMED |
| noncopyable-associatedtype-domain | `associatedtype Domain: ~Copyable` not supported in Swift 6.2 | 2026-02-04 | Swift 6.2.3 | REFUTED |
| phantom-tagged-string-unification | Phantom-tagged ~Copyable string with deinit, @_lifetime, _overrideLifetime, ~Escapable View, conditional namespaces, callAsFunction scope, protocol Domain, typealiases. 9 variants: 8 fully confirmed, V6 confirmed debug / crashes release (CopyPropagation #87029, @_optimize(none) workaround). Option D feasible today. | 2026-02-25 | Swift 6.2.3 | CONFIRMED (debug) |
| tagged-string-literal | Literally Tagged\<Domain, StringStorage\> (Option D'): deinit through Tagged, ~Escapable View, @_lifetime, Span, Sendable inheritance, conditional namespaces, callAsFunction, protocol Domain, .retag() domain migration, .map() value transformation, typealiases. 10 variants all confirmed (debug + release). V6 release needs @_optimize(none) workaround for CopyPropagation #87029. Finding: rawValue _read coroutine blocks @_lifetime propagation — must access _storage directly. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| memory-contiguous-owned | Memory.Contiguous\<Element: BitwiseCopyable\> as self-owning typed region: generic struct + deinit, Span access, protocol hoisting, String.Storage wrapping, Tagged composition, direct span property through 3-level chain, Sendable inheritance, retag domain migration, conditional namespace operations. 11 variants all confirmed (debug + release). No CopyPropagation #87029. Finding: direct stored property access works for @_lifetime propagation (unlike _read coroutine). | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| memory-contiguous-protocol-hoisting | Protocol hoisting from generic struct: hoist Memory.ContiguousProtocol outside generic struct, typealias back as Memory.Contiguous.Protocol. All consumer patterns work: conformance, constraints, protocol extensions, opaque return, generic parameters. 10 variants all confirmed (debug + release). Finding: Swift resolves typealiases in generic types without requiring the generic parameter. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| protocol-inside-generic-namespace | Protocol nesting in generic enums: blocked. Non-generic namespace + element-agnostic protocol + [IMPL-026] Property.View delegation: works | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| protocol-typealias-hoisting | Hoist ONLY protocol outside generic namespace, typealias back as *.Protocol. Tags stay as real nested enums. All per-type methods use Storage<Never>.Tag as canonical witness. Full [IMPL-026] delegation works | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| protocol-default-accessor | Protocol default Property.View accessors. Static requirements (Variant 6b) are best: `var drain` + `static func drain(...)` don't collide, single protocol, no marker needed. Instance requirements with same name cause infinite recursion. associatedtype Element blocks ~Copyable | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| typealias-without-reexport | Stop @_exported re-export of String_Primitives; use typealias only. Finding: MemberImportVisibility blocks ALL member access through typealias when defining module not imported. Importing it re-introduces shadowing. Option A insufficient alone. | 2026-02-27 | Swift 6.2 | PARTIALLY REFUTED |
| tagged-string-crossmodule | Cross-module Tagged\<Tag, StringStorage\> (Option D'): 3 modules (TaggedLib/StringLib/Consumer). 9/11 confirmed, 2 falsified. Critical finding 1: @usableFromInline internal does NOT enable cross-module source access — must use package access. Critical finding 2: @_lifetime propagation through package _storage works cross-module for ~Escapable views. Critical finding 3: generic arity (String\<Tag\> vs String) does NOT prevent shadowing — Swift.String qualification still required. | 2026-02-27 | Swift 6.2.3 | 9/11 CONFIRMED |
| tagged-escapable-accessor | Cross-PACKAGE Tagged accessor for @_lifetime: 5 variants testing _read coroutine vs stored property rawValue for Span and ~Escapable View across separate SwiftPM packages. V1/V3/V5 REFUTED: _read coroutine universally blocks _overrideLifetime across package boundaries. V2/V4 CONFIRMED: public stored property rawValue propagates @_lifetime correctly. Production Tagged MUST change _storage + _read/_modify to public stored property rawValue. | 2026-02-27 | Swift 6.2.3 | 3 REFUTED / 2 CONFIRMED |
| tagged-two-level-lifetime | Two-level @_lifetime chain through Tagged\<Domain, ConcreteType\>: 6 variants testing chained Span (V1/V2), ~Escapable View (V3), direct Span (V4), domain-specific forwarding (V5), type distinctness (V6). Validates D' architecture: concrete types (String, Path) as RawValue, domain (Kernel) as Tag. Kind × Domain = two orthogonal axes. ALL 6 CONFIRMED (debug + release). Prerequisite: stored property rawValue from tagged-escapable-accessor. | 2026-02-27 | Swift 6.2.3 | ALL CONFIRMED |
| phantom-type-conformance-limitation | Cannot have multiple conformances with different constraints | 2026-01-21 | Swift 6.2 | CONFIRMED |
| protocol-coroutine-accessor-limitation | Protocol extensions fail with _read/_modify + ~Copyable | 2026-01-21 | Swift 6.2 | STILL PRESENT 6.3 |
| ownership-overloading-limitation | Ownership modifiers cannot be used for overloading | 2026-01-22 | Swift 6.2 | CONFIRMED |
| value-generic-nested-type-bug | Nested types with value generics in extensions | 2026-01-20 | Swift 6.2 | FIXED 6.2.4 |
| nested-generic-performance | Performance overhead from nested generic types | 2026-01-20 | Swift 6.2 | CONFIRMED |
| suite-discovery-generic-extension | @Suite/@Test not discovered in extensions of generic type specializations | 2026-01-28 | Swift 6.2.3 | CONFIRMED |
| set-protocol-noncopyable-conformance | `where Element: ~Copyable` in conformance clause breaks witness matching. Closures consume captured ~Copyable values — no borrowing closure capture. `hashValue` computed property not found on `T: HashProto & ~Copyable`. 12 variants. | 2026-03-02 | Swift 6.2.4 | CONFIRMED |
| suppressed-associatedtype-domain | Re-test `associatedtype Domain: ~Copyable` WITH SuppressedAssociatedTypes feature flag. Tagged wrapper, cross-type operators, cross-domain rejection, full Phase 2, ~Copyable tag as Domain witness. 6 variants all confirmed. Phase 2 Domain unification unblocked. | 2026-02-13 | Swift 6.2.3 | CONFIRMED |
| throws-overloading-limitation | Throws modifier cannot be used for overloading | 2026-01-22 | Swift 6.2 | STILL PRESENT 6.3 |
| ~~noncopyable-nested-deinit-chain~~ | **Moved to** `swift-buffer-primitives/Experiments/noncopyable-nested-deinit-chain/` (its natural home alongside the other @_rawLayout experiments). | 2026-03-21 | — | MOVED |
| member-import-visibility-body-conflict | MemberImportVisibility + stored `body` property: does `public import SwiftUI` in same file cause SwiftUI.View.Body collision? 6 variants testing same-file, MIV enabled/disabled, internal/package import, Content associatedtype. | 2026-03-13 | Swift 6.2 | CONFIRMED |
| member-import-visibility-reexport | MemberImportVisibility with @_exported re-export: does re-exporting a module propagate member visibility to downstream consumers? 3 modules (Upstream/Reexporter/Consumer). | 2026-03-13 | Swift 6.2 | CONFIRMED |
| nsviewrepresentable-body-witness | NSViewRepresentable + custom protocol `body` witness: does AppKit's NSViewRepresentable collide with custom protocol's `body` associated type? 4 variants testing minimal, associatedtype collision, generic Body param, result builder. | 2026-03-13 | Swift 6.2 | CONFIRMED |
| unsafe-forin-release-crash | Expression-level `unsafe` on `for-in` loops over `[UnsafeMutablePointer<T>]` crashes SIL optimizer with signal 6 in release builds. | 2026-03-14 | Swift 6.2.4 | CONFIRMED (workaround applied) |
| copypropagation-noncopyable-switch-consume | SILGen produces `load [take]` for trivial field in ~Copyable generic enum tuple payload, mismatching `switch_enum forwarding: @none`. Signal 6 in release, passes in debug. | 2026-03-31 | Swift 6.3 | CONFIRMED |
| noncopyable-equatable-stdlib | Swift.Equatable does NOT support ~Copyable on Swift 6.3 (SE-0499 landed on main only, not release/6.3). | 2026-03-30 | Swift 6.3 | CONFIRMED |
| noncopyable-throwing-init | ~Copyable throwing init patterns: throw before init, self = try factory(), throw after full init, Optional ~Copyable, locals first. All 5 variants compile. | 2026-03-30 | Swift 6.2 | CONFIRMED |
| async-let-typed-throws | Verify whether `async let` / `withThrowingTaskGroup` preserve typed throws or erase to any Error. Both erase. Result wrapper workaround. 5 variants. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| backtick-protocol-type-member | Backtick-escaped type named `` `Protocol` `` (a Swift keyword) used as nested type, property type, and in expression position. Type annotation works; expression position does NOT. | 2026-04-12 | Swift 6.3 | PARTIAL |

### API Design Patterns

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| escapable-accessor-patterns | ~Escapable accessor patterns for pointer-holding types | 2026-01-21 | Swift 6.2 | SUPERSEDED → nonescapable-patterns |
| property-view-pattern | Property.View pattern for protocol extensions | 2026-01-22 | Swift 6.2 | CONFIRMED |
| fluent-api-pattern | Fluent API patterns with Property.View | 2026-01-22 | Swift 6.2 | CONFIRMED |
| protocol-primitive-naming | Semantic naming for protocol primitives | 2026-01-21 | Swift 6.0 | ANALYSIS |
| stdlib-comparison-conformance | Dual-track architecture for stdlib Comparable integration | 2026-01-22 | Swift 6.0 | COMPLETE |
| consuming-iteration-pattern | Optimal consuming iteration with Property.View | 2026-01-22 | Swift 6.2 | SUPERSEDED → noncopyable-access-patterns |
| doubly-nested-accessor-pattern | Doubly nested accessor patterns (.a.b.property) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| generic-method-where-clause | Generic where clause on method (not extension) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| nested-typed-multiparameter-pattern | Nested Typed<A>.Typed<B> for multi-parameter generics | 2026-01-21 | Swift 6.2 | CONFIRMED |
| api-totality-design | Totality (zero crashes) API design philosophy | 2026-01-22 | Swift 6.2 | CONFIRMED |
| declarative-parser-typed-throws | Parser.Take.Sequence builder composition with typed throws: Void-skipping, tuple flattening, `var body` pattern, error type assessment. 10 variants. `var body` incompatible with typed throws (V8 REFUTED). `@_disfavoredOverload` fix for buildPartialBlock ambiguity. | 2026-03-04 | Swift 6.2 | PARTIAL |
| canonical-witness-capability | Protocol canonical + witness alternatives: Parseable/Serializable/Codable protocols with single canonical, witness properties for alternatives, generic constrainability, Codable shadowing stdlib, separate failure types, parameterized factory. 10 variants all CONFIRMED. Validates Option C from canonical-witness-capability-attachment research. | 2026-03-04 | Swift 6.2.4 | CONFIRMED |
| foreach-consuming-accessor | .forEach.consuming accessor pattern: Property.View with callAsFunction (borrowing), .borrowing, .consuming() paths. Consuming via _read + defer + state class works. Pattern works with ~Copyable containers. Pointer-based consuming (Variant 7) optimal. | 2026-01-22 | Swift 6.2.3 | SUPERSEDED → noncopyable-access-patterns |
| hash-table-context-passing-lookup | Context-passing overload on hash-table lookup avoids closure capture for ~Copyable elements. `position(forHash:context:equals:)` with `borrowing Context: ~Copyable`. Probe iterator closure-free path. Implicit `where Element: Copyable` on extensions of ~Copyable generic types. 8 findings. | 2026-03-02 | Swift 6.2.4 | CONFIRMED |
| index-totality | Systematic totality (zero crashes) exploration for Index_Primitives. Eliminate all preconditions, typed throws for runtime validation, type system compile-time guarantees. Index_Primitives ~95% total; only ExpressibleByIntegerLiteral non-total. | 2026-01-22 | Swift 6.2 | CONFIRMED |
| parameter-pack-concrete-extension | Can concrete extensions of parameter-pack types unwrap the pack for positional tuple access and labeled accessors? Blocked by "same-type requirements between packs and concrete types are not yet supported" (swiftlang test/Generics/variadic_generic_types.swift:128). Pack not unwrapped in extension bodies; no generic pack-shape extensions; no pack Codable. Free functions and external dynamicMemberLookup work. 9 variants (6 CONFIRMED, 3 REFUTED). Motivating example: Geometry.Insets as Product typealias. | 2026-03-20 | Swift 6.2.4 | REFUTED |
| lazy-pipeline-release-mode | Compiler optimization of lazy pipelines vs eager/hand-rolled. Release mode: lazy matches hand-rolled within 2%, eager 7x slower. Compiler fully eliminates lazy intermediate type overhead in -O. 4 variants all confirmed. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| lazy-sequence-operator-unification | One type conditionally conforms to both sync sequence protocol and AsyncSequence. Chained operators (map->filter) work for both sync and async. ~Copyable containers work with lazy operators. Async isolation preservation through shared type. 7 variants all confirmed. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| contiguous-protocol-escapable | @lifetime on protocol PROPERTY blocked (all toolchains). @_lifetime on protocol METHOD works (6.2.4+). ~Copyable-only protocol with var span { get } is the correct pattern for Swift 6.2. | 2026-03-19 | Swift 6.2.4 / 6.3 / 6.4-dev | SUPERSEDED → nonescapable-patterns |
| contiguous-protocol-roundtrip | Protocol with `init(_ span:) throws(Error)` where Error is associatedtype, Never makes init non-throwing via throws covariance. 10 variants all confirmed. | 2026-03-19 | Swift 6.2.4 | CONFIRMED |
| literal-vs-throwing-init-disambiguation | `try` does NOT disambiguate between ExpressibleByStringLiteral and throwing init(_ string:). Swift unconditionally selects literal conformance. Only labeled inits disambiguate. | 2026-03-19 | Swift 6.2 | CONFIRMED |
| span-to-string-array-conversion | Span-to-String and Span-to-Array conversion paths. UTF8Span(validating:) then String(copying:) is best path. Span is not Collection/Sequence. 6 of 8 pass. | 2026-03-19 | Swift 6.2.4 | CONFIRMED |
| span-utf8-property | String.init(_ span: Span\<UInt8\>) throws(UTF8.ValidationError) via UTF8Span(validating:) then String(copying:). All 8 variants pass. | 2026-03-19 | Swift 6.2.4 | CONFIRMED |
| path-operator-overload-resolution | Path `/` operator overload resolution with ExpressibleByStringLiteral. No exponential type-checker timeout even at 15-chain depth. All configurations under 2ms. | 2026-03-19 | Swift 6.2.4 | CONFIRMED |
| callasfunction-noncopyable-consuming-sending | `callAsFunction` + ~Copyable + consuming sending + ~Escapable: full IO.Stream pattern compiles and runs. E1/E1b/E2/E2b/E3/E3b/E3c all confirmed. | 2026-04-06 | Swift 6.3 | CONFIRMED |

### Witness Infrastructure

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| witness-noncopyable-value-feasibility | ~Copyable witness value feasibility: `associatedtype Value: ~Copyable`, Shared+UnsafeRawPointer storage, closure-scoped borrowing, Mutex.withLock, constrained get + universal withValue coexistence, typed throws. Design constraint: protocol default `testValue { liveValue }` requires `where Value: Copyable`. | 2026-02-24 | Swift 6.2.3 | CONFIRMED |
| witness-noncopyable-default-forwarding | Root cause analysis of protocol property forwarding constraint for ~Copyable. Protocol witness table dispatches properties through `_read` coroutines (borrow); functions through direct return (owned). 15 variants isolate exact boundary. Solutions A–D evaluated; Solution A (constrain to Copyable) recommended. Not a compiler bug — semantic consequence of property dispatch model. | 2026-02-24 | Swift 6.2.3 | CONFIRMED |
| protocol-diamond-noncopyable-refinement | Protocol diamond with shared `~Copyable & Sendable` associated type: `WitnessKey: DependencyKey, WitnessKeyTest`. 8 variants: diamond compiles, `= Self` default propagates, default chain `testValue → previewValue → liveValue` resolves correctly, `~Copyable` conformers work, IS-A resolution through `K: DependencyKey` subscript works. Validates Option D of `dependency-witness-store-coherence.md`. | 2026-03-03 | Swift 6.2.4 | CONFIRMED |
| witness-macro-noncopyable-feasibility | @Witness macro ~Copyable support via Projection pattern: Action enum stores Copyable projections via WitnessProjectable. Borrowing/consuming forwarding through closure wrappers. Typed throws requires explicit closure annotations. WitnessProjectable unifies Copyable/~Copyable. inout parameters forward cleanly. 12 variants (V1a REFUTED, rest CONFIRMED). | 2026-03-04 | Swift 6.2.4 | CONFIRMED |
| dual-defunctionalize-composition | @Dual + @Defunctionalize composition on same struct: 5 variants testing categorical dual, defunctionalized call algebra, combined generation, PointFree model. Variant 5 (PointFree model) cleanest. All variants compile. | 2026-03-16 | Swift 6.2.4 | CONFIRMED |

### Concurrency & Isolation

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| nonsending-closure-type-constraints | Where can nonisolated(nonsending) be applied? Async closures in structs (B1a) and actors (B1b): yes. Sync function types (B1d): no — compiler rejects. Key discovery: nonsending ONLY applies to async function types. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| stdlib-concurrency-isolation | Do stdlib concurrency primitives propagate caller isolation? withCheckedContinuation (B2): yes, via #isolation. withTaskCancellationHandler (B3): yes, nonisolated(nonsending) overload. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| nonsending-clock-feasibility | Can a NonsendingClock protocol refining Clock be defined? Yes — ImmediateClock with nonisolated(nonsending) sleep preserves MainActor with zero thread hop (B5). Foundation for deterministic temporal testing. | 2026-02-25 | Swift 6.2.3 | SUPERSEDED → nonsending-dispatch |
| nonsending-sendable-iterator | Test nonisolated(nonsending) @Sendable stored closure isolation. Finding: @Sendable wins — isolation broken on stored closures. nonisolated(nonsending) without @Sendable preserves. | 2026-02-25 | Swift 6.2 | SUPERSEDED → nonsending-dispatch |
| nonsending-generic-dispatch | Generic dispatch with NonisolatedNonsendingByDefault. nonisolated(nonsending) on concrete Clock.sleep survives protocol witness dispatch (<C: Clock>) and opaque type dispatch (some Clock). No separate NonsendingClock protocol needed. | 2026-02-25 | Swift 6.2.3 | SUPERSEDED → nonsending-dispatch |
| stream-isolation-preservation | Determine theoretical max isolation preservation for async sequence pipelines. 13 test variants. Finding: concrete operator types preserve isolation (sync+async closures), @unchecked Sendable doesn't break it, late erasure preserves it. Type-erased sync map() breaks; async map() preserves. | 2026-02-25 | Swift 6.2 | PARTIALLY CONFIRMED |
| callback-isolated-prototype | Validate nonsending callback prototype: 5 approaches (A–E), 14 tests, 6 discoveries. Approach C (isolated parameter) and D (explicit nonsending) preserve map/flatMap isolation. Issue #83812 CONFIRMED: stored closure-in-closure loses isolation; method wrapper workaround. Non-Sendable Value works. Replacement feasibility confirmed (T11). | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| sync-overload-resolution | Sync-closure overload of map/filter on AsyncSequence wins over stdlib's async-closure overload. Chaining produces concrete Isolated.Filter\<Isolated.Map\<...\>\>. Explicitly async closures still resolve to stdlib. Isolation preserved through concrete pipeline. | 2026-02-25 | Swift 6.2 | PARTIALLY CONFIRMED |
| nonsending-method-annotation | nonisolated(nonsending) on callAsFunction() method propagates isolation identically to deprecated isolation: parameter. Map/flatMap/chained/flatMap/Non-Sendable all preserve MainActor. 7 tests. | 2026-03-22 | Swift 6.2 | SUPERSEDED → nonsending-dispatch |
| se0461-concurrent-body-sensitivity | SE-0461 @concurrent inference for @Sendable async closures is body-sensitive: only triggers when closure body contains await. Sync closure promoted sync->async without @concurrent inference. | 2026-04-01 | Swift 6.2 | CONFIRMED |
| sending-mutex-noncopyable-region | Returning non-Sendable ~Copyable action types from Mutex.withLock. Wrapper methods do NOT get special compiler region disconnection. Slot pattern with direct Mutex.withLock is the solution. 23 variants (5 CONFIRMED, 18 REFUTED). | 2026-04-01 | Swift 6.3 | CONFIRMED |
| noncopyable-operation-closure-pipeline | A+E feasibility spike: ~Copyable Sendable Operation through stored closure pipeline. Non-Sendable closure → box → Operation → Lane → Job → execute. 13/14 CONFIRMED, 1 REFUTED. Key finding: UnsafeMutableRawPointer is @unsafe Sendable in 6.3 — requires nonisolated(unsafe) on field. Pipeline mechanics (consuming, forwarding, deinit cleanup, async) all work. | 2026-04-03 | Swift 6.3 | CONFIRMED |
| detach-exit-signal | Detached pthread exit signaling via Swift Concurrency primitives. 6 variants: basic exit signal (V1), last-action resume (V2), 10 independent signals (V3), ~Copyable ~Escapable scope with consuming close() async (V4a), deinit fallback (V4b), 50 concurrent non-blocking awaits in 106ms (V5). Validates zero-blocking shutdown for swift-io lifecycle. | 2026-04-01 | Swift 6.3 | CONFIRMED |
| executor-serial-mode-task-preference | Serial-mode executor with withTaskExecutorPreference: serial mode works (V2), dual use actor pinning + preference on same executor (V3), async let inherits serial-mode preference (V4), no deadlock on same-executor actor calls (V5). Unblocks swift-io executor-first Phase 2: single `.serial` executor for both actor pinning and task preference. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| async-closure-noncopyable-escaping | ~Copyable values can be BORROWED in closures but never CONSUMED. Language constraint (not a bug) across sync/async, escaping/non-escaping. Workarounds catalogued. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| sending-vs-sendable-structured-concurrency | `sending` cannot replace `Sendable` for ~Copyable types in addTask/async let because of the borrowing/consuming closure constraint. Transfer-wrapper pattern (V9) is the only path. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| actor-run-noncopyable-return | Does `Actor.run` support ~Copyable returns? Overloads with R: ~Copyable + sending + isolated Self + typed throws compile; full IO.Event.Selector.register pattern works. 6 hypotheses. | 2026-04-13 | Swift 6.3 | CONFIRMED |
| actor-run-sending-closure | Can `sending` on the closure parameter replace `@Sendable`, enabling capture of non-Sendable and borrowing ~Copyable values? Full pattern validated. 8 hypotheses. | 2026-04-13 | Swift 6.3 | CONFIRMED |
| actor-run-closure-alternatives | `isolated Actor` parameter alternative to Actor.run for borrowing ~Copyable across actor boundary without closures. 6 hypotheses, eliminates 2-hop Selector.register. | 2026-04-13 | Swift 6.3 | CONFIRMED |
| shared-executor-actor-communication | Two actors sharing a SerialExecutor: cross-actor call cost, hop elision on same executor, Actor.run atomicity, async variant trade-offs. 5 hypotheses. | 2026-04-13 | Swift 6.3 | CONFIRMED |

### ~Escapable & Ownership

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| nonescapable-closure-storage | Can ~Escapable types store closures? Immortal lifetime: yes (V2). Scoped consuming: yes (V3). Borrow-lifetime closure capture: prevented (V4). @_lifetime on Escapable closure: rejected (V8). ~Escapable + Sendable: orthogonal (B4b). Across await: works (V6). To Task: works (V7). | 2026-02-25 | Swift 6.2.3 | SUPERSEDED → nonescapable-patterns |
| resumption-nonescapable-noncopyable | Validate Resumption as ~Copyable + ~Escapable: 7 variants (struct, Optional, consuming, drain, let-bind, closure param, optional binding). All PASS in isolation. **Production deployment REVERTED** — cache/pool need `[Resumption]` (heap-backed, requires Escapable). | 2026-03-02 | Swift 6.2.4 | CONFIRMED (pattern works; deployment reverted) |
| conditional-escapable-container | Conditional Escapable containers: Box (PASS), heap-backed FixedArray (BLOCKED), Ring (BLOCKED), nested Box (PASS), Pair (PASS). Heap-backed containers blocked by UnsafeMutablePointer requiring Escapable. | 2026-03-02 | Swift 6.2.4 | PARTIAL |
| nonescapable-gap-revalidation-624 | Gap A/B re-validation on Swift 6.2.4. Gap A still blocked, Gap B (stored) still blocked, Gap B+ (immediately-invoked) NEW PASS. | 2026-03-02 | Swift 6.2.4 | SUPERSEDED → nonescapable-patterns |
| pointer-nonescapable-storage | Exhaustive storage mechanism test: 17 variants (9 PASS, 11 BLOCKED). Enum-based variable-occupancy (V14/V15 PASS). @_rawLayout declaration (V16 PASS), @_rawLayout element access (V17/V17b BLOCKED). Layout-vs-access gap confirmed. | 2026-03-02 | Swift 6.2.4 | SUPERSEDED → nonescapable-patterns |
| escapable-lazy-sequence-borrowing | ~Escapable lazy operator types with borrowing/consuming patterns. Both sequence AND iterator protocols suppress ~Escapable. @_lifetime(self: immortal) on mutating func next(). 9 variants all confirmed. | 2026-02-25 | Swift 6.2.3 | SUPERSEDED → nonescapable-patterns |
| pointer-primitives-feasibility | swift-pointer-primitives ~Copyable and ~Escapable support. Builtin.load requires BOTH Copyable AND Escapable. UnsafeMutablePointer works with ~Copyable (different mechanism). C interop: local ~Escapable works, generic ~Escapable blocked. | 2026-01-24 | Swift 6.2.3 | PARTIALLY VIABLE |
| escapable-protocol-cross-module | Cross-module ~Escapable protocol conformance: Path.View from module A conforms to Path.Protocol in consuming module B. @_lifetime requirements, Span returns, owned ~Copyable returns all work cross-module. 6 variants confirmed. | 2026-04-01 | Swift 6.3 | SUPERSEDED → nonescapable-patterns |
| escapable-protocol-navigation | ~Copyable, ~Escapable type conforming to protocol with @_lifetime Span returns and owned ~Copyable returns. Validates path decomposition architecture. 7 variants confirmed. | 2026-04-01 | Swift 6.3 | CONFIRMED |
| span-async-parameter | ~Escapable types (Span, MutableSpan) as async function parameters: caller memory is valid across suspension. Design validates a zero-copy async I/O API. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| mutablespan-async-read | `inout MutableSpan<UInt8>` as async read destination. The ideal read API `read(into: inout MutableSpan<UInt8>) async throws -> Int?` is achievable. Array + `_modify` sources both work. | 2026-04-06 | Swift 6.3 | CONFIRMED |
| escapable-slot-inlinable-sqe | ~Escapable Slot + `@inlinable` mutating entry methods: the io_uring SQE pointer-elimination architecture. ~Copyable ~Escapable slot types with `nonmutating _modify` support @inlinable mutating methods. V1/V2/V4–V6 confirmed; V3 refuted. | 2026-04-14 | Swift 6.3 | CONFIRMED |

### Test Framework Integration

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| atexit-swiftsyntax-rewrite | SwiftSyntax parsing, SyntaxRewriter, and atomic file write inside atexit handler. 4 variants: file I/O (V1), parse (V2), rewrite "hello"→"goodbye" (V3), LIFO ordering (V4). Validates Option R1 from expectation-failure-bridge research. | 2026-03-03 | Swift 6.2.4 | CONFIRMED |
| atexit-testing-runner-lifecycle | atexit fires after Swift Testing runner (V1, marker file verified), #if canImport(Testing) resolves to Apple's Testing (V2), Testing.Issue.record reports failures (V3), drain() idempotency (V4), nil-collector guard (V5). Validates Options A + R1 from expectation-failure-bridge research. | 2026-03-03 | Swift 6.2.4 | CONFIRMED |
| noncopyable-expect-throws | Isolate whether closures capturing ~Copyable vars for mutating throwing calls release borrow correctly after throw. Phase 1: minimal ~Copyable + #expect(throws:) works fine. Cross-module phases testing incremental complexity factors. | 2026-02-10 | Swift 6.2.3 | INVESTIGATION |
| dependency-scope-writeback | Verify Dependency.Scope mutability from within scoped operation. Direct value mutation impossible (struct copy). Reference type (class) injected via Dependency.Scope IS visible after mutation — works across await, nested scopes. Full benchmark pattern (scope provider injects Box, measure {} writes, provider reads back) confirmed. 6 variants all pass. | 2026-03-10 | Swift 6.2 | CONFIRMED |
| trait-gated-test-support | SE-0450 trait-gated test support: validate cross-package test infrastructure sharing using Swift Testing traits for conditional target inclusion. 4 modules (test-primitives, rendering, consumer, consumer-no-trait). | 2026-03-14 | Swift 6.2 | CONFIRMED |
| testing-discovery-revalidation | Revalidation of backticked test names, nested suites, generic nesting discovery in Swift 6.2.4. Backticked names/suites/deep nesting all work. Generic specialization still broken (swiftlang/swift-testing#1508). | 2026-03-20 | Swift 6.2.4 | PARTIALLY RESOLVED |

### Architecture Patterns

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| storage-variant-patterns | Storage variant patterns (Inline/Bounded/Unbounded/Small) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| associatedtype-output-collision | Renaming associatedtype Output resolves Parser/Rendering collision | 2026-02-10 | Swift 6.2 | CONFIRMED |
| github-url-spm-resolution | GitHub URL patterns, SPM package name uniqueness, redirect behavior for org migration. Basic resolution, multi-package resolution, repo rename redirect validation. | 2026-02-23 | Swift 6.2.3 | CONFIRMED |
| implicit-graph-diff-benchmark | 0-1 BFS on implicit edit graph vs Myers O(ND) for sequence diff. BFS 10-110x slower with O(N*M) space vs O(D²). Graph-primitives cannot subsume specialized Myers. | 2026-02-27 | Swift 6.2.3 | REFUTED |
| rendering-context-protocol-vs-witness | Protocol vs witness vs action vs existential dispatch for Rendering.Context. V2 Witness ≈ V1 Protocol (0.99–1.04x release). Action 1.20–1.36x. AnyView 1.03–1.07x. Decision: hybrid (protocol + Action enum). | 2026-03-14 | Swift 6.2.4 | CONFIRMED |
| async-rendering-transport | ~Copyable async context for transport-layer HTML streaming. Tests nonsending closures, inout/borrowing across await, actor sinks, AsyncRenderable protocol, @Sendable Task.detached, suspension squashing. 7/8 CONFIRMED, ~Escapable DEFERRED. Two-mode design: nonsending for inline, @Sendable for concurrent streaming. | 2026-03-15 | Swift 6.2 | CONFIRMED |
| markdown-rendering-performance-profiling | Capture-based vs pure action markdown rendering. Per-element: Paragraph 17.6x, InlineCode 7.0x, ListItem 36.4x. Full pipeline: 3 pure elements → 9% improvement. Children replay amplification dominates — incremental conversion yields diminishing returns. All-or-nothing conversion recommended. | 2026-03-15 | Swift 6.2 | CONFIRMED |
| zero-copy-event-pipeline-validation | Memory.Pool event pipeline (Phase 1 + Phase 2) zero-copy design validation: pool sizing under poll batch loads, contention with concurrent producers/consumers, backpressure when exhausted. | 2026-03-15 | Swift 6.2 | DEFERRED — awaiting pool design completion |
| rendering-context-algebra-composition | ~Copyable witness struct algebra composition for Rendering.Context: consuming transformers, nested Action enum, push/pop state management. Validates witness architecture composability. | 2026-03-14 | Swift 6.2 | CONFIRMED |
| rendering-witness-migration-blockers | Rendering.Context witness migration blocker validation: Property.View delegation, ownership forwarding, consuming transformer patterns across package boundaries. | 2026-03-14 | Swift 6.2 | CONFIRMED |
| nested-package-source-ownership | Nested package source ownership: validates that parent and nested Package.swift can share Sources/ directory without conflicts. | 2026-03-13 | Swift 6.2 | CONFIRMED |
| iterative-tuple-rendering-trampoline | Validate trampoline approach for iterative _Tuple rendering to avoid stack overflow from deeply nested types. | 2026-03-16 | Swift 6.2.4 | DEFERRED — awaiting iterative-tuple-rendering.md research |
| for-loop-result-builder | For-loop buildArray stack overflow reproduction: find nesting depth threshold where rendering crashes for deeply nested _Tuple view types via for-loop iteration. Multi-package (RenderingPrimitives + HTMLRenderable). | 2026-03-17 | Swift 6.2.4 | PENDING |
| extension-extraction-scope-resolution | Extracting methods from nested extension bodies to explicit extensions changes scope resolution: sibling types lose implicit scope and must be fully qualified. | 2026-04-01 | Swift 6.2 | CONFIRMED |
| predictable-memopt-destroy-value-source | Spurious `destroy_value` in CopyPropagation ~Escapable crash (#88022) comes from `completeOSSALifetime` during alloc_stack removal in PredictableDeadAllocationElimination, not from `forceDelete` compensation. | 2026-03-19 | Swift 6.2.4 | SUPERSEDED — #88022 fixed in Swift 6.3 |
| swiftpm-visionos-implicit-platform | `platforms` array does not control platform availability in either swift-tools-version 5.9 or 6.2. Both compile for visionOS when SDK is provided regardless of listing. | 2026-03-31 | Swift 6.3 | REFUTED |
| with-closure-to-property-migration | with* { } closure pattern to property migration: ~Copyable owners, ~Escapable views, Copyable owners, cross-package patterns. 14/15 escape attempts correctly rejected. | 2026-04-01 | Swift 6.2 | CONFIRMED |

## Bug: ~Copyable Inline Storage Deinit (Swift Compiler Bug)

**Location**: `noncopyable-inline-deinit/`

**Symptom**: ~Copyable structs fail to call element deinitializers when destroyed. Elements are leaked.

### Root Cause: Precise Trigger Conditions

The bug is triggered by this **exact combination**:

1. `InlineArray<capacity, ...>` where `capacity` is a **value generic parameter** (not a literal)
2. ~Copyable struct containing only value-type properties
3. **Cross-module boundary**: Element type (e.g., `TrackedElement`) defined in a different module than the container
4. deinit that performs manual element cleanup

### Isolation Test Results

| Configuration | Deinit Called? |
|---------------|----------------|
| `InlineArray<4, ...>` (literal capacity) | ✅ YES |
| Value generic `<let capacity: Int>` without InlineArray | ✅ YES |
| `InlineArray<capacity, ...>` with value generic | ❌ NO (BUG) |
| Same + `var _deinitWorkaround: AnyObject? = nil` | ✅ YES |

### Minimal Reproduction

```swift
// In Module A (ContainerLib):
public struct Container<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, (Int, Int, Int, Int, Int, Int, Int, Int)>
    var _count: Int
    // NO reference type properties

    deinit {
        // This code path is never executed for cross-module ~Copyable elements
        for i in 0..<_count {
            // deinitialize elements...
        }
    }
}

// In Module B (Tests):
struct TrackedElement: ~Copyable {
    deinit { print("deinit called") }  // NEVER PRINTED
}

var container = Container<TrackedElement, 4>()
container.push(TrackedElement())
// container goes out of scope - TrackedElement.deinit NOT called
```

### Workaround

Add a reference type property to the struct:

```swift
var _deinitWorkaround: AnyObject? = nil
```

This forces the compiler to generate correct deinit dispatch.

### NOT Contributing Factors

These were tested and do NOT affect the bug:
- `@inlinable` / `@usableFromInline` attributes
- Nesting inside a generic outer container
- Whether outer container is generic or not
- Ring buffer logic / modulo calculations
- `withUnsafeBytes` vs `withUnsafePointer` pattern

### Affected Packages

| Package | Type | Status |
|---------|------|--------|
| swift-deque-primitives | `Deque.Inline` | Fixed (workaround applied) |
| swift-queue-primitives | `Queue.Inline` | Fixed (workaround applied) |
| swift-stack-primitives | `Stack.Inline` | Fixed (workaround applied) |

### Filing Bug Report

This experiment provides a minimal reproduction case suitable for a Swift compiler bug report:

```
noncopyable-inline-deinit/
├── Package.swift
├── Sources/ContainerLib/Container.swift  (library with bug trigger)
└── Tests/ContainerTests.swift            (reproduction tests)
```

Run `swift test --filter "Critical"` to demonstrate the bug.

**TODO**: File Swift compiler bug report with this reproduction case.

## Issue: ~Copyable Constraint Poisoning (Compiler Limitation)

**Related experiments**: `noncopyable-pointer-propagation`, `noncopyable-storage-poisoning`, `noncopyable-multifile-poisoning`, `noncopyable-sequence-protocol-test`

**Research paper**: `Noncopyable Generics Constraint Propagation.md`

**Symptom**: Adding a conditional conformance `where Element: Copyable` causes stored properties using `Element` to fail with "type 'Element' does not conform to protocol 'Copyable'"—even when those properties (like `UnsafeMutablePointer<Element>`) explicitly support ~Copyable elements.

### Root Cause

When a type `T<E: ~Copyable>` gains a conformance with `where E: Copyable`, Swift's type checker propagates the `Copyable` constraint backwards to the type definition. This "poisons" stored properties:

```swift
struct Container<Element: ~Copyable>: ~Copyable {
    var storage: UnsafeMutablePointer<Element>  // ❌ Poisoned by conformance below
}

extension Container: Sequence where Element: Copyable {
    // This conformance causes the error above
}
```

### What Does NOT Prevent Poisoning

| Approach | Result |
|----------|--------|
| Conformance in separate file | ❌ Still poisons |
| Conformance in same file | ❌ Still poisons |
| Custom protocol instead of Swift.Sequence | ❌ Still poisons |
| Protocol without `associatedtype Element` | ✅ Works (but loses Sequence) |
| Conditional `Copyable` on the type itself | ❌ Still poisons |

### What DOES Prevent Poisoning

| Approach | Result |
|----------|--------|
| **Separate SPM module** | ✅ Works |
| **Wrapper type** | ✅ Works (less ergonomic) |

### Solution: Module Boundary Isolation

Module boundaries are real compilation boundaries. The compiler processes each target independently:

```
Package/
├── Sources/
│   ├── Core/           # Type with ~Copyable support, NO Sequence conformance
│   │   └── Container.swift
│   ├── Sequence/       # Conformances for Copyable elements
│   │   └── Container+Sequence.swift  (imports Core)
│   └── Public/         # Re-exports both
│       └── exports.swift
```

When Sequence module adds conformances, Core has already been compiled—its stored properties validated without the Copyable constraint.

### Applied Solution

| Package | Implementation |
|---------|----------------|
| swift-array-primitives | Split into Core/Sequence internal modules |

### Wrapper Alternative

When module splitting is impractical, wrapper types avoid direct conformance:

```swift
extension Container where Element: Copyable {
    public var iterable: IterableView { ... }
}
for x in container.iterable { }  // Not `for x in container`
```

Trade-off: Requires `.iterable` accessor; copies elements upfront.

### Related Swift Evolution

- **SE-0427**: Noncopyable Generics (implemented, constraint propagation is intended)
- **SE-0437**: Noncopyable Stdlib Primitives (UnsafeMutablePointer supports ~Copyable)
- **Suppressed Associated Types Pitch**: Would solve this if accepted (not available today)

