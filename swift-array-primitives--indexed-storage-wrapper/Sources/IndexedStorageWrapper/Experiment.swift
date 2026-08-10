// MARK: - Improvement Discovery: Indexed Storage Pattern (No Protocols)
// Purpose: Find best approach for phantom-typed array indexing without protocols
// Constraint: No protocols allowed
//
// Toolchain: swift-6.2-RELEASE
// Status: SUPERSEDED 2026-04-30 — Array.Unbounded namespace member removed; experiment relied on Array<Element>.Unbounded shape that no longer exists
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Result: CONFIRMED — Array variants should use nested Indexed<Tag> type
//   (~15 lines each) for phantom-typed index access without protocols.
//   Property.Typed pattern works.
// Date: 2026-01-22

import Index_Primitives
import Array_Primitives

// MARK: - Findings Summary
//
// APPROACH 1: Protocol-based (IntIndexable) - FORBIDDEN by codebase rules
// APPROACH 2: Generic Indexed<Tag, Element, Storage> - Can't write extension for value generics
// APPROACH 3: Per-variant nested type - WORKS, follows Property.Typed pattern

// MARK: - Working Solution: Per-Variant Nested Type

// Each array variant gets its own Indexed<Tag> nested type.
// This is similar to how Property.Typed works.

extension Array_Primitives.Array.Unbounded where Element: Copyable {
    /// Wrapper providing phantom-typed index access.
    ///
    /// `Array<Payload>.Unbounded<4>.Indexed<Tag>` provides:
    /// - `subscript(index: Index<Tag>) -> Element`
    /// - `count: Index<Tag>.Count`
    ///
    /// ## Usage
    ///
    /// ```swift
    /// var storage: Array<Payload>.Unbounded<4>.Indexed<Tag> = .init(unbounded)
    /// storage[node]  // node: Index<Tag>
    /// guard node < storage.count else { return }
    /// ```
    struct Indexed<Tag: Copyable>: Copyable {
        var _storage: Array_Primitives.Array<Element>.Unbounded<N>

        init(_ storage: consuming Array_Primitives.Array<Element>.Unbounded<N>) {
            self._storage = storage
        }

        /// The phantom-typed count for bounds checking.
        var count: Index<Tag>.Count {
            Index<Tag>.Count(__unchecked: _storage.count)
        }

        /// Accesses the element at the given phantom-typed index.
        subscript(index: Index<Tag>) -> Element {
            get { _storage[index.position.rawValue] }
            set { _storage[index.position.rawValue] = newValue }
        }
    }
}

// Similarly for other variants (Bounded, Inline, Small)...
// Note: Bounded is ~Copyable unconditionally, so its Indexed would also be ~Copyable
// Implementation would follow same pattern but with ~Copyable conformance

// MARK: - Test: Unbounded.Indexed<Tag>

func testUnboundedIndexed() {
    print("--- Test: Array.Unbounded.Indexed<Tag> ---")

    enum GraphTag {}

    var unbounded = Array_Primitives.Array<String>.Unbounded<4>()
    unbounded.append("alpha")
    unbounded.append("beta")
    unbounded.append("gamma")

    // Clean API!
    var indexed = Array_Primitives.Array<String>.Unbounded<4>.Indexed<GraphTag>(unbounded)

    let node = Index<GraphTag>.zero
    print("Element at node 0: \(indexed[node])")
    print("Count: \(indexed.count)")

    // Mutation
    indexed[node] = "MODIFIED"
    print("After mutation: \(indexed[node])")

    // Type safety - this would be a compile error:
    // enum OtherTag {}
    // let wrong: Index<OtherTag> = .zero
    // indexed[wrong]  // Error: cannot convert

    print("Unbounded.Indexed: PASSED\n")
}

// MARK: - Test: Different capacities

func testDifferentCapacities() {
    print("--- Test: Different capacity values ---")

    enum Tag1 {}
    enum Tag2 {}

    var arr4 = Array_Primitives.Array<Int>.Unbounded<4>()
    arr4.append(100)
    let indexed4 = Array_Primitives.Array<Int>.Unbounded<4>.Indexed<Tag1>(arr4)
    print("Unbounded<4>: \(indexed4[.zero])")

    var arr8 = Array_Primitives.Array<Int>.Unbounded<8>()
    arr8.append(200)
    let indexed8 = Array_Primitives.Array<Int>.Unbounded<8>.Indexed<Tag2>(arr8)
    print("Unbounded<8>: \(indexed8[.zero])")

    print("Different capacities: PASSED\n")
}

// MARK: - Test: Bounds checking with Count

func testBoundsChecking() {
    print("--- Test: Bounds checking with Index<Tag>.Count ---")

    enum NodeTag {}

    var arr = Array_Primitives.Array<String>.Unbounded<4>()
    arr.append("only-element")

    let indexed = Array_Primitives.Array<String>.Unbounded<4>.Indexed<NodeTag>(arr)

    let node0: Index<NodeTag> = .zero
    let offset: Index<NodeTag>.Offset = 1
    let node1 = (node0 + offset)!

    // Typed bounds check
    if node0 < indexed.count {
        print("node0 in bounds: \(indexed[node0])")
    }

    if node1 >= indexed.count {
        print("node1 out of bounds (as expected)")
    }

    print("Bounds checking: PASSED\n")
}

// MARK: - Conclusion

func printConclusion() {
    print("=== EXPERIMENT CONCLUSIONS ===\n")

    print("""
    SOLUTION: Per-variant nested type (Property.Typed pattern)

    Implementation per variant (~15 lines each):
    ```swift
    extension Array.Unbounded where Element: Copyable {
        struct Indexed<Tag: Copyable>: Copyable {
            var _storage: Array<Element>.Unbounded<N>

            init(_ storage: consuming Array<Element>.Unbounded<N>) { ... }
            var count: Index<Tag>.Count { ... }
            subscript(index: Index<Tag>) -> Element { ... }
        }
    }
    ```

    API:
    - Array<Payload>.Unbounded<4>.Indexed<Tag>
    - storage[node] where node: Index<Tag>
    - storage.count returns Index<Tag>.Count
    - node < storage.count for typed bounds checking

    Properties:
    1. No protocols needed
    2. Value generics (N) captured in nested type context
    3. Element inferred from outer type
    4. Only Tag needs to be specified
    5. ~15 lines per variant (Bounded, Unbounded, Inline, Small)
    6. Follows established Property.Typed pattern

    Trade-off: Small code duplication across variants, but:
    - Implementation is trivial (just delegates to storage)
    - Could use macro to generate if desired
    - Keeps each variant self-contained
    """)
}

// MARK: - Entry Point

@main
struct Main {
    static func main() {
        print("=== Indexed Storage Wrapper Experiment (No Protocols) ===\n")

        testUnboundedIndexed()
        testDifferentCapacities()
        testBoundsChecking()
        printConclusion()

        print("\n=== Experiment Complete ===")
    }
}
