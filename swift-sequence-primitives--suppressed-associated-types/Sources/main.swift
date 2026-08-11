// MARK: - Suppressed Associated Types for ~Copyable Elements
// Purpose: Test whether SuppressedAssociatedTypes enables protocols with
//          ~Copyable associated types, allowing ~Copyable containers with
//          ~Copyable elements to conform.
// Hypothesis: associatedtype Element: ~Copyable compiles and types
//             with ~Copyable elements can conform to the protocol.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21) / Xcode 26 beta
// Platform: macOS 26.0 (arm64)
//
// Note: Two feature flags exist:
//   - SuppressedAssociatedTypes (legacy) — available in 6.2.3
//   - SuppressedAssociatedTypesWithDefaults — NOT available in 6.2.3,
//     requires development snapshot from main branch (Dec 2025+).
//     Adds default inference for primary associated types.
//   When both are specified, WithDefaults takes precedence and legacy
//   is disabled (see CompilerInvocation.cpp).
//
// Result: CONFIRMED — all variants compile and run with SuppressedAssociatedTypes
// Output:
//   Copyable elements:
//     1
//     2
//     3
//   ~Copyable elements:
//     Resource(10)
//     Resource(20)
//     Resource(30)
// Date: 2026-02-12

// MARK: - Variant 1: Basic protocol with ~Copyable associated type
// Hypothesis: associatedtype Element: ~Copyable compiles with SuppressedAssociatedTypes
// Result: CONFIRMED — compiles with legacy SuppressedAssociatedTypes flag
// Finding: With legacy flag, Element is ALWAYS ~Copyable — no defaulting.
//          Cannot write `where T.Element: ~Copyable` in extensions (outer scope error).

protocol IterableProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    borrowing func makeIterator() -> Iterator

    // Note: stdlib IteratorProtocol requires Copyable Element.
    // We define our own iterator protocol.
    associatedtype Iterator: IterProto where Iterator.Element == Element
}

// Custom iterator protocol with ~Copyable Element support
protocol IterProto: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

// MARK: - Variant 2: Copyable container with Copyable elements conforms
// Hypothesis: Standard Copyable element types still work
// Result: CONFIRMED — Int satisfies Element: ~Copyable (Copyable ⊂ ~Copyable)

struct IntIterator: IterProto {
    var storage: [Int]
    var index: Int = 0

    mutating func next() -> Int? {
        guard index < storage.count else { return nil }
        let element = storage[index]
        index += 1
        return element
    }
}

struct CopyableContainer: IterableProtocol {
    var storage: [Int]

    func makeIterator() -> IntIterator {
        IntIterator(storage: storage)
    }
}

// MARK: - Variant 3: ~Copyable element type
// Hypothesis: A container with ~Copyable elements can conform
// Result: CONFIRMED — Resource: ~Copyable satisfies Element: ~Copyable

struct Resource: ~Copyable {
    let id: Int
}

struct ResourceIterator: IterProto {
    var index: Int
    let count: Int
    let elements: [Int]

    mutating func next() -> Resource? {
        guard index < count else { return nil }
        let element = Resource(id: elements[index])
        index += 1
        return element
    }
}

struct ResourceContainer: ~Copyable, IterableProtocol {
    var elements: [Int]
    let count: Int

    func makeIterator() -> ResourceIterator {
        ResourceIterator(index: 0, count: count, elements: elements)
    }
}

// MARK: - Variant 4: Protocol extension with default forEach
// Hypothesis: Protocol extensions can provide defaults using
//             pointer-based Property.View pattern for ~Copyable Element protocols
// Result: CONFIRMED — default forEach accessor works for both Copyable
//         and ~Copyable elements through the protocol extension.
// Finding: Closure parameter MUST use `borrowing` for ~Copyable Element.
//          Since Element is always ~Copyable with the legacy flag, this
//          means ALL closure parameters need `borrowing` — no implicit copy.

struct ForEachView<Base: ~Copyable>: ~Copyable {
    let base: UnsafeMutablePointer<Base>

    init(_ base: UnsafeMutablePointer<Base>) {
        self.base = base
    }
}

extension ForEachView where Base: IterableProtocol & ~Copyable {
    func callAsFunction(_ body: (borrowing Base.Element) -> Void) {
        var iterator = base.pointee.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

extension IterableProtocol where Self: ~Copyable {
    var forEach: ForEachView<Self> {
        mutating _read {
            yield ForEachView<Self>(&self)
        }
    }
}

// MARK: - Variant 5: Usage test
// Hypothesis: forEach accessor works end-to-end with both Copyable and ~Copyable elements
// Result: CONFIRMED — both paths produce correct output

// Test Copyable elements
var copyable = CopyableContainer(storage: [1, 2, 3])
print("Copyable elements:")
copyable.forEach { element in
    print("  \(element)")
}

// Test ~Copyable elements
var resources = ResourceContainer(elements: [10, 20, 30], count: 3)
print("~Copyable elements:")
resources.forEach { element in
    print("  Resource(\(element.id))")
}

// MARK: - Variant 6: Stdlib IteratorProtocol ~Copyable Element
// Hypothesis: stdlib IteratorProtocol.Element is also ~Copyable with this flag
// Result: REFUTED — SuppressedAssociatedTypes (legacy) only enables
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         user-defined protocols to declare ~Copyable associated types.
//         It does NOT retroactively change stdlib protocol signatures.
//         stdlib IteratorProtocol.Element remains implicitly Copyable.
// Workaround: Define custom IterProto with associatedtype Element: ~Copyable
//         (as done in Variant 1). SuppressedAssociatedTypesWithDefaults
//         (when available) would change stdlib behavior via inference defaults.

// MARK: - Key Findings
// 1. SuppressedAssociatedTypes (legacy) is available in Swift 6.2.3 / Xcode 26
// 2. It enables `associatedtype Element: ~Copyable` in user-defined protocols
// 3. Element is ALWAYS ~Copyable (no inference defaulting to Copyable)
// 4. Cannot write `where T.Element: ~Copyable` — it's outer scope, always true
// 5. Closure params need explicit `borrowing` for ~Copyable elements
// 6. stdlib protocols (IteratorProtocol, Sequence) are NOT affected — need
//    custom protocol equivalents (IterProto) for ~Copyable element iteration
// 7. SuppressedAssociatedTypesWithDefaults would add inference defaults
//    (primary associated types default to Copyable in extensions) but is
//    NOT available in 6.2.3

// MARK: - Implications for Sequence.Protocol
// To enable Sequence.Protocol to support ~Copyable elements:
// 1. Enable SuppressedAssociatedTypes feature flag
// 2. Change `associatedtype Element` to `associatedtype Element: ~Copyable`
// 3. Define custom Iterator protocol (can't use stdlib IteratorProtocol)
// 4. All closure parameters receiving Element need `borrowing` annotation
// 5. Extension constraints like `where Element: ~Copyable` are unnecessary
//    (and actually error) — Element is always ~Copyable
// Caveat: With legacy flag, ALL conformers see Element as ~Copyable,
//    which means the closure parameters always need `borrowing`.
//    WithDefaults would let extensions default Element to Copyable,
//    avoiding the borrowing requirement for Copyable-element conformers.

// MARK: - Results Summary
// V1: CONFIRMED — associatedtype Element: ~Copyable compiles
// V2: CONFIRMED — Copyable elements still satisfy ~Copyable constraint
// V3: CONFIRMED — ~Copyable element container conforms
// V4: CONFIRMED — protocol extension default forEach works
// V5: CONFIRMED — end-to-end iteration works for both element kinds
// V6: REFUTED — stdlib protocols not affected, need custom equivalents
