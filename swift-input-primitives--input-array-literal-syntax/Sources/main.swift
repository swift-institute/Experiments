// MARK: - Input.Slice ExpressibleByArrayLiteral Experiment
// Purpose: Test if Input.Slice can conform to ExpressibleByArrayLiteral
//          generically via `where Base: ExpressibleByArrayLiteral`
//
// Toolchain: Xcode 26 beta / Swift 6.2
// Platform: macOS 26.0 (arm64)
//
// Result: REFUTED — generic conformance impossible due to variadic forwarding
//         limitation. Concrete conformances work. See variants below.
//
// Compiler exploration: Checked swiftlang/swift source.
//   - No _ExpressibleByBuiltinArrayLiteral (unlike integer/float literals)
//   - No splat operator (array → variadic) exists or is planned
//   - _allocateUninitializedArray is compiler-internal, not user-accessible
//   - init(arrayLiteral:) receives a compiler-constructed [Element] from the
//     literal site; that [Element] cannot be forwarded to another variadic
//
// Date: 2026-02-13

import Input_Primitives
import Collection_Primitives
import Index_Primitives
import Equation_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Helper: Minimal Collection.Protocol + ExpressibleByArrayLiteral
// ============================================================================

struct Bytes: Collection.`Protocol`, ExpressibleByArrayLiteral, Sendable {
    let storage: ContiguousArray<UInt8>

    typealias Index = Index_Primitives.Index<UInt8>

    init(_ storage: ContiguousArray<UInt8>) { self.storage = storage }
    init(_ elements: [UInt8]) { self.storage = ContiguousArray(elements) }
    init(arrayLiteral elements: UInt8...) { self.storage = ContiguousArray(elements) }

    var startIndex: Index { .zero }
    var endIndex: Index { try! Index.Count(storage.count).map(Ordinal.init) }

    subscript(position: Index) -> UInt8 { storage[Int(bitPattern: position)] }
    func index(after i: Index) -> Index { try! i.successor.exact() }

    struct Iterator: Sequence.Iterator.`Protocol`, IteratorProtocol {
        var base: ContiguousArray<UInt8>.Iterator
        mutating func next() -> UInt8? { base.next() }
    }
    func makeIterator() -> Iterator { Iterator(base: storage.makeIterator()) }
}

// ============================================================================
// MARK: - Variant A: Generic `where Base: ExpressibleByArrayLiteral`
// Hypothesis: We can forward [Element] to Base.init(arrayLiteral:)
// Result: REFUTED
//   error: cannot pass array of type 'Base.ArrayLiteralElement...'
//          as variadic arguments of type 'Base.ArrayLiteralElement'
// ============================================================================

// UNCOMMENT TO VERIFY:
// extension Input.Slice: @retroactive ExpressibleByArrayLiteral
// where Base: ExpressibleByArrayLiteral & Collection.`Protocol`,
//       Base.ArrayLiteralElement == Base.Element,
//       Base.Element: Copyable {
//     public init(arrayLiteral elements: Base.Element...) {
//         // `elements` is [Base.Element] in the body.
//         // Swift has NO mechanism to forward this to another variadic.
//         self.init(Base(arrayLiteral: elements))  // ERROR
//     }
// }

// ============================================================================
// MARK: - Variant B: Concrete conformance for specific Base
// Hypothesis: Input.Slice<Bytes> can directly conform
// Result: CONFIRMED — compiles and runs correctly
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// ============================================================================

extension Input.Slice: @retroactive ExpressibleByArrayLiteral
where Base == Bytes {
    init(arrayLiteral elements: UInt8...) {
        self.init(Bytes(elements))
    }
}

// ============================================================================
// MARK: - Test
// ============================================================================

let input: Input.Slice<Bytes> = [0x01, 0x02, 0x03]
print("count = \(input.count)")
print("first = \(input.first ?? 0)")

let other: Input.Slice<Bytes> = [0x01, 0x02, 0x03]
print("equal = \(input == other)")

let different: Input.Slice<Bytes> = [0x04, 0x05]
print("not equal = \(input == different)")
