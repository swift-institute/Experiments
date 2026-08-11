// Status: SUPERSEDED -- consuming Property.View pattern shipped in swift-property-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// EXPERIMENT: consuming-property-view
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: Property.View pattern cannot support `consuming` container
//             semantics because property accessors cannot be `consuming`.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// TEST SEQUENCE:
// 1. Can a property accessor be `consuming`?
// 2. Can a `consuming func` return a drainer that owns the container?
// 3. What is the viable pattern for consuming + draining?
//
// RESULT: [CONFIRMED] - consuming get exists but cannot move stored properties
//
// ===----------------------------------------------------------------------===//

// MARK: - Test Container

struct Container: ~Copyable {
    var elements: [Int] = [1, 2, 3]

    init() {}

    mutating func clear() {
        elements.removeAll()
    }
}

// MARK: - Test 1: Can property accessor be `consuming`?

// Uncomment to verify compiler error:
//
// extension Container {
//     var consumingProperty: Int {
//         consuming get {
//             return elements.count
//         }
//     }
// }
//
// Expected error: "property accessors cannot be 'consuming'"

// MARK: - Test 2: Mutating drain via Property.View pattern (SHOULD WORK)

@safe
struct DrainView: ~Copyable, ~Escapable {
    @usableFromInline
    internal let ptr: UnsafeMutablePointer<Container>

    @inlinable
    @_lifetime(borrow ptr)
    init(_ ptr: UnsafeMutablePointer<Container>) {
        unsafe self.ptr = ptr
    }

    @inlinable
    @_lifetime(&self)
    mutating func callAsFunction(_ body: (Int) -> Void) {
        for element in unsafe ptr.pointee.elements {
            body(element)
        }
        unsafe ptr.pointee.clear()
    }
}

extension Container {
    var drain: DrainView {
        mutating _read {
            yield unsafe DrainView(&self)
        }
        mutating _modify {
            var view = unsafe DrainView(&self)
            yield &view
        }
    }
}

// MARK: - Test 3: Consuming drain via wrapper (SHOULD WORK)

struct ConsumingDrainer: ~Copyable {
    var container: Container

    init(_ container: consuming Container) {
        self.container = container
    }

    consuming func forEach(_ body: (Int) -> Void) {
        for element in container.elements {
            body(element)
        }
        // container consumed when self is consumed
    }
}

extension Container {
    /// Returns a wrapper that owns this container for consuming iteration.
    /// Pattern: container.consumingDrain().forEach { }
    consuming func consumingDrain() -> ConsumingDrainer {
        ConsumingDrainer(self)
    }
}

// MARK: - Test Execution

func testMutatingDrain() {
    print("=== Test: Mutating drain (Property.View pattern) ===")
    var container = Container()
    container.drain { element in
        print("  Drained: \(element)")
    }
    print("  Container after drain: \(container.elements.count) elements")
    // Container survives, empty
}

func testConsumingDrain() {
    print("\n=== Test: Consuming drain (wrapper pattern) ===")
    let container = Container()
    container.consumingDrain().forEach { element in
        print("  Consumed: \(element)")
    }
    // container is consumed, cannot use it
    // print(container.elements)  // ERROR: used after consume
    print("  Container consumed (variable no longer accessible)")
}

testMutatingDrain()
testConsumingDrain()
testConsumingGet()
testConsumingPropertyDrain()
testConsumingProtocol()
testPropertyConsuming()
testConsumingView()

print("\n=== FINAL CONCLUSIONS ===")
print("""
EMPIRICAL FINDINGS:

1. `consuming get` accessor:
   - Syntactically valid in Swift 6.2
   - CANNOT move stored properties ("self is borrowed and cannot be consumed")
   - NOT useful for draining containers

2. Protocols with `consuming func`:
   - SUPPORTED - protocols CAN require `consuming func` methods
   - Associated types CANNOT be ~Copyable (SE-0427 limitation)
   - Viable patterns:
     a. `consuming func consumingForEach(_ body: (Element) -> Void)`
     b. `consuming func makeConsumingIterator() -> CopyableIterator`

WHAT CAN BE UNIFIED IN swift-sequence-primitives:

1. MUTATING DRAIN (container survives, empty):
   - Sequence.Drainable protocol
   - Sequence.Drain tag
   - Property.View extension for `.drain { }`
   - Set types conform -> get `.drain { }` for free

2. CONSUMING DRAIN (container consumed):
   - Sequence.ConsumingDrainable protocol with:
     `consuming func consumingForEach(_ body: (Element) -> Void)`
   - Set types conform -> consistent API across packages
   - Internal iterator types remain in each package (need ~Copyable)

RECOMMENDATION FOR swift-set-primitives:

Current API:
- drain(_ body:)           -> mutating, container survives
- consumingForEach(_ body:) -> consuming, container consumed

Unified API via sequence-primitives:
- Conform to Sequence.Drainable    -> .drain { }
- Conform to Sequence.ConsumingDrainable -> .consumingForEach { }

The consuming iterator implementations stay in set-primitives as internal
details. The PUBLIC API becomes protocol conformance.
""")
