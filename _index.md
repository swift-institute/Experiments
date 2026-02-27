# Experiments Index

Ecosystem-wide experiments for Swift Institute.

## Experiments

### Swift Language Issues

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| bitwisecopyable-lifetime-inference | BitwiseCopyable blocks _read accessor lifetime inference | 2026-01-21 | Swift 6.2 | CONFIRMED |
| noncopyable-inline-deinit | ~Copyable inline storage deinit bug | 2026-01-20 | Swift 6.2 | BUG REPRODUCED |
| noncopyable-pointer-propagation | Test if constraint poisoning occurs | 2026-01-22 | Swift 6.2 | BUG REPRODUCED |
| noncopyable-pointer-propagation-multifile | Multi-file variant of above | 2026-01-22 | Swift 6.2 | BUG REPRODUCED |
| noncopyable-storage-poisoning | Isolated constraint poisoning test | 2026-01-22 | Swift 6.2 | BUG REPRODUCED |
| noncopyable-multifile-poisoning | File organization doesn't prevent poisoning | 2026-01-22 | Swift 6.2 | CONFIRMED |
| noncopyable-sequence-protocol-test | Same-file conformance still poisons | 2026-01-22 | Swift 6.2 | CONFIRMED |
| noncopyable-protocol-workarounds | Protocols without Element associatedtype | 2026-01-22 | Swift 6.2 | WORKAROUND FOUND |
| noncopyable-cross-module-propagation | ~Copyable constraint propagation across modules | 2026-01-20 | Swift 6.0 | INVESTIGATION |
| noncopyable-sequence-emit-module-bug | Module emission failure with ~Copyable + Sequence | 2026-01-20 | Swift 6.2 | BUG FILED #86669 |
| noncopyable-accessor-incompatibility | Accessor pattern incompatible with ~Copyable containers | 2026-01-20 | Swift 6.2 | CONFIRMED |
| separate-module-conformance | Module boundaries prevent poisoning | 2026-01-22 | Swift 6.2 | SOLUTION FOUND |
| wrapper-type-approach | Wrapper types avoid direct conformance | 2026-01-22 | Swift 6.2 | WORKAROUND FOUND |
| conditional-copyable-type | Conditional Copyable doesn't help | 2026-01-22 | Swift 6.2 | CONFIRMED FAILS |
| tagged-family-constraint | Swift cannot constrain to generic tag families | 2026-01-21 | Swift 6.2 | REFUTED |
| phantom-type-noncopyable-constraint | Phantom types require ~Copyable constraint | 2026-01-21 | Swift 6.2 | CONFIRMED |
| noncopyable-associatedtype-domain | `associatedtype Domain: ~Copyable` not supported in Swift 6.2 | 2026-02-04 | Swift 6.2.3 | REFUTED |
| phantom-tagged-string-unification | Phantom-tagged ~Copyable string with deinit, @_lifetime, _overrideLifetime, ~Escapable View, conditional namespaces, callAsFunction scope, protocol Domain, typealiases. 9 variants: 8 fully confirmed, V6 confirmed debug / crashes release (CopyPropagation #87029, @_optimize(none) workaround). Option D feasible today. | 2026-02-25 | Swift 6.2.3 | CONFIRMED (debug) |
| tagged-string-literal | Literally Tagged\<Domain, StringStorage\> (Option D'): deinit through Tagged, ~Escapable View, @_lifetime, Span, Sendable inheritance, conditional namespaces, callAsFunction, protocol Domain, .retag() domain migration, .map() value transformation, typealiases. 10 variants all confirmed (debug + release). V6 release needs @_optimize(none) workaround for CopyPropagation #87029. Finding: rawValue _read coroutine blocks @_lifetime propagation — must access _storage directly. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| memory-contiguous-owned | Memory.Contiguous\<Element: BitwiseCopyable\> as self-owning typed region: generic struct + deinit, Span access, protocol hoisting, String.Storage wrapping, Tagged composition, direct span property through 3-level chain, Sendable inheritance, retag domain migration, conditional namespace operations. 11 variants all confirmed (debug + release). No CopyPropagation #87029. Finding: direct stored property access works for @_lifetime propagation (unlike _read coroutine). | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| memory-contiguous-protocol-hoisting | Protocol hoisting from generic struct: hoist Memory.ContiguousProtocol outside generic struct, typealias back as Memory.Contiguous.Protocol. All consumer patterns work: conformance, constraints, protocol extensions, opaque return, generic parameters. 10 variants all confirmed (debug + release). Finding: Swift resolves typealiases in generic types without requiring the generic parameter. | 2026-02-25 | Swift 6.2.3 | CONFIRMED |
| input-slice-module-split-poisoning | Validate module-split fix for Input.Slice TestCollection ~Copyable constraint poisoning | 2026-02-13 | — | PLANNED |
| cross-module-protocol-shadowing | Validate that protocol refinement shadowing (Sequence tag → Collection tag) works across module boundaries | 2026-02-13 | — | PLANNED |
| protocol-inside-generic-namespace | Protocol nesting in generic enums: blocked. Non-generic namespace + element-agnostic protocol + [IMPL-026] Property.View delegation: works | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| protocol-typealias-hoisting | Hoist ONLY protocol outside generic namespace, typealias back as *.Protocol. Tags stay as real nested enums. All per-type methods use Storage<Never>.Tag as canonical witness. Full [IMPL-026] delegation works | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| protocol-default-accessor | Protocol default Property.View accessors. Static requirements (Variant 6b) are best: `var drain` + `static func drain(...)` don't collide, single protocol, no marker needed. Instance requirements with same name cause infinite recursion. associatedtype Element blocks ~Copyable | 2026-02-12 | Swift 6.2.3 | CONFIRMED |
| typealias-without-reexport | Stop @_exported re-export of String_Primitives; use typealias only. Finding: MemberImportVisibility blocks ALL member access through typealias when defining module not imported. Importing it re-introduces shadowing. Option A insufficient alone. | 2026-02-27 | Swift 6.2 | PARTIALLY REFUTED |
| phantom-type-conformance-limitation | Cannot have multiple conformances with different constraints | 2026-01-21 | Swift 6.2 | CONFIRMED |
| protocol-coroutine-accessor-limitation | Protocol extensions fail with _read/_modify + ~Copyable | 2026-01-21 | Swift 6.2 | CONFIRMED |
| ownership-overloading-limitation | Ownership modifiers cannot be used for overloading | 2026-01-22 | Swift 6.2 | CONFIRMED |
| value-generic-nested-type-bug | Nested types with value generics must be in body, not extension | 2026-01-20 | Swift 6.2 | CONFIRMED |
| nested-generic-performance | Performance overhead from nested generic types | 2026-01-20 | Swift 6.2 | CONFIRMED |
| suite-discovery-generic-extension | @Suite/@Test not discovered in extensions of generic type specializations | 2026-01-28 | Swift 6.2.3 | CONFIRMED |

### API Design Patterns

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| escapable-accessor-patterns | ~Escapable accessor patterns for pointer-holding types | 2026-01-21 | Swift 6.2 | CONFIRMED |
| property-view-pattern | Property.View pattern for protocol extensions | 2026-01-22 | Swift 6.2 | CONFIRMED |
| fluent-api-pattern | Fluent API patterns with Property.View | 2026-01-22 | Swift 6.2 | CONFIRMED |
| protocol-primitive-naming | Semantic naming for protocol primitives | 2026-01-21 | Swift 6.0 | ANALYSIS |
| stdlib-comparison-conformance | Dual-track architecture for stdlib Comparable integration | 2026-01-22 | Swift 6.0 | COMPLETE |
| consuming-iteration-pattern | Optimal consuming iteration with Property.View | 2026-01-22 | Swift 6.2 | CONFIRMED |
| doubly-nested-accessor-pattern | Doubly nested accessor patterns (.a.b.property) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| generic-method-where-clause | Generic where clause on method (not extension) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| nested-typed-multiparameter-pattern | Nested Typed<A>.Typed<B> for multi-parameter generics | 2026-01-21 | Swift 6.2 | CONFIRMED |
| api-totality-design | Totality (zero crashes) API design philosophy | 2026-01-22 | Swift 6.2 | CONFIRMED |

### Witness Infrastructure

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| witness-noncopyable-value-feasibility | ~Copyable witness value feasibility: `associatedtype Value: ~Copyable`, Shared+UnsafeRawPointer storage, closure-scoped borrowing, Mutex.withLock, constrained get + universal withValue coexistence, typed throws. Design constraint: protocol default `testValue { liveValue }` requires `where Value: Copyable`. | 2026-02-24 | Swift 6.2.3 | CONFIRMED |
| witness-noncopyable-default-forwarding | Root cause analysis of protocol property forwarding constraint for ~Copyable. Protocol witness table dispatches properties through `_read` coroutines (borrow); functions through direct return (owned). 15 variants isolate exact boundary. Solutions A–D evaluated; Solution A (constrain to Copyable) recommended. Not a compiler bug — semantic consequence of property dispatch model. | 2026-02-24 | Swift 6.2.3 | CONFIRMED |

### Concurrency & Isolation

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| nonsending-blocker-validation | Validate nonisolated(nonsending) on async closures, continuation and cancellation handler isolation | 2026-02-25 | Swift 6.2 | CONFIRMED |
| nonsending-blocker-validation-negative | Compiler rejects nonsending on sync function types | 2026-02-25 | Swift 6.2 | CONFIRMED |
| nonsending-sendable-iterator | Test nonisolated(nonsending) @Sendable stored closure isolation. Finding: @Sendable wins — isolation broken on stored closures. nonisolated(nonsending) without @Sendable preserves. | 2026-02-25 | Swift 6.2 | CONFIRMED |
| nonsending-generic-dispatch | Generic dispatch with NonisolatedNonsendingByDefault | 2026-02-25 | Swift 6.2 | — |
| stream-isolation-preservation | Determine theoretical max isolation preservation for async sequence pipelines. 13 test variants. Finding: concrete operator types preserve isolation (sync+async closures), @unchecked Sendable doesn't break it, late erasure preserves it. Type-erased sync map() breaks; async map() preserves. | 2026-02-25 | Swift 6.2 | PARTIALLY CONFIRMED |
| callback-isolated-prototype | Validate nonsending callback prototype: 5 approaches (A–E), 14 tests, 6 discoveries. Approach C (isolated parameter) and D (explicit nonsending) preserve map/flatMap isolation. Issue #83812 CONFIRMED: stored closure-in-closure loses isolation; method wrapper workaround. Non-Sendable Value works. Replacement feasibility confirmed (T11). | 2026-02-25 | Swift 6.2.3 | CONFIRMED |

### Architecture Patterns

| Directory | Purpose | Date | Toolchain | Status |
|-----------|---------|------|-----------|--------|
| storage-variant-patterns | Storage variant patterns (Inline/Bounded/Unbounded/Small) | 2026-01-21 | Swift 6.2 | CONFIRMED |
| index-bit-design | Index bit design investigation | - | - | - |
| associatedtype-output-collision | Renaming associatedtype Output resolves Parser/Rendering collision | 2026-02-10 | Swift 6.2 | CONFIRMED |

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

