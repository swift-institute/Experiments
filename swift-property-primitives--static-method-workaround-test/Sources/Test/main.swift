// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: Static Method Workaround for Pointer Acquisition
// ===----------------------------------------------------------------------===//
//
// PAPER CLAIM: "Provide static methods that take borrowing parameters"
//              "Breaks path-like composition"
//              (Section 6.2 of Non-Mutating-Accessor-Problem.md)
//
// HYPOTHESIS: Static methods accepting `borrowing` parameter work in
//             non-mutating contexts, but change the API shape.
//
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// EXPECTED RESULT: Static method works but API is asymmetric
// ===----------------------------------------------------------------------===//

// MARK: - Test Setup: SmallArray with Inline Storage

struct SmallArray<Element>: ~Copyable {
    // Simulated inline storage (8 elements max)
    var _inlineStorage: (Element?, Element?, Element?, Element?,
                         Element?, Element?, Element?, Element?)
    var _count: Int
    var _useHeap: Bool

    init() {
        _inlineStorage = (nil, nil, nil, nil, nil, nil, nil, nil)
        _count = 0
        _useHeap = false
    }

    // MARK: - The Inline Accessor (Mutating)

    struct Inline: ~Copyable {
        let _base: UnsafeMutablePointer<SmallArray<Element>>

        init(_ base: UnsafeMutablePointer<SmallArray<Element>>) {
            self._base = base
        }

        // Instance method for WRITE access
        func write(at index: Int, value: Element) {
            // Would write to inline storage
        }

        // Instance method for READ access (requires mutating context to create Inline)
        func read(at index: Int) -> Element? {
            // Would read from inline storage via pointer
            nil
        }
    }

    // Mutating accessor - works for write operations
    var inline: Inline {
        mutating _read {
            yield Inline(&self)
        }
    }
}

// MARK: - Test 1: Static Method Workaround

extension SmallArray.Inline {
    // Static method that takes borrowing parameter
    // This CAN be called from non-mutating context
    static func read(
        at index: Int,
        in storage: borrowing SmallArray<Element>
    ) -> Element? {
        // Access inline storage through borrowing reference
        // In real implementation: use withUnsafePointer on storage properties
        switch index {
        case 0: return storage._inlineStorage.0
        case 1: return storage._inlineStorage.1
        case 2: return storage._inlineStorage.2
        case 3: return storage._inlineStorage.3
        case 4: return storage._inlineStorage.4
        case 5: return storage._inlineStorage.5
        case 6: return storage._inlineStorage.6
        case 7: return storage._inlineStorage.7
        default: return nil
        }
    }
}

// MARK: - Test 2: Iterator Using Static Method

extension SmallArray where Element: Copyable {
    struct Iterator: IteratorProtocol {
        var index: Int = 0
        let count: Int
        // Store a copy of inline elements (since we can't store pointer)
        let elements: [Element?]

        mutating func next() -> Element? {
            guard index < count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // makeIterator can now be borrowing!
    borrowing func makeIterator() -> Iterator {
        // Use static method to read elements
        var elements: [Element?] = []
        for i in 0..<_count {
            elements.append(Inline.read(at: i, in: self))
        }
        return Iterator(index: 0, count: _count, elements: elements)
    }
}

// MARK: - Test 3: API Comparison

extension SmallArray {
    // Compare the two patterns:

    // WRITE (instance accessor - path-like):
    //   array.inline.write(at: 0, value: x)

    // READ (static method - not path-like):
    //   Inline.read(at: 0, in: array)

    // The asymmetry is clear:
    //   - Write: instance.accessor.method()
    //   - Read:  Type.staticMethod(in: instance)
}

// MARK: - Test 4: Alternative - Namespace Preservation

extension SmallArray.Inline {
    // We can use the Inline type as a namespace for static methods
    // This preserves SOME path-like quality:
    //   SmallArray.Inline.read(at:in:)
    //
    // But it's still different from:
    //   array.inline.read(at:)
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== Static Method Workaround Test ===\n")

    var array = SmallArray<Int>()

    // Simulate adding elements
    array._inlineStorage.0 = 10
    array._inlineStorage.1 = 20
    array._inlineStorage.2 = 30
    array._count = 3

    print("Test 1 - Static method read (borrowing context):")
    let val0 = SmallArray<Int>.Inline.read(at: 0, in: array)
    let val1 = SmallArray<Int>.Inline.read(at: 1, in: array)
    let val2 = SmallArray<Int>.Inline.read(at: 2, in: array)
    print("  Inline.read(at: 0, in: array) = \(val0 ?? -1)")
    print("  Inline.read(at: 1, in: array) = \(val1 ?? -1)")
    print("  Inline.read(at: 2, in: array) = \(val2 ?? -1)")
    print("  RESULT: COMPILES (static method works in borrowing context)")

    print("\nTest 2 - Iterator using static method:")
    let iter = array.makeIterator()
    print("  Iterator created successfully")
    print("  Elements via iterator: ", terminator: "")
    var iterCopy = iter
    while let elem = iterCopy.next() {
        print("\(elem) ", terminator: "")
    }
    print("\n  RESULT: COMPILES (borrowing makeIterator works)")

    print("\n=== API COMPARISON ===")
    print("")
    print("WRITE (mutating context):")
    print("  array.inline.write(at: 0, value: x)")
    print("  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    print("  Path-like: instance.accessor.method()")
    print("")
    print("READ (borrowing context):")
    print("  Inline.read(at: 0, in: array)")
    print("  ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^")
    print("  Static: Type.method(in: instance)")
    print("")
    print("ASYMMETRY:")
    print("  - Write uses instance accessor pattern")
    print("  - Read uses static method pattern")
    print("  - Different syntax for conceptually symmetric operations")

    print("\n=== FINDINGS ===")
    print("")
    print("CONFIRMED: Static method workaround works")
    print("  - Static methods can take `borrowing` parameters")
    print("  - Can be called from non-mutating/borrowing contexts")
    print("  - Iterator creation becomes possible")
    print("")
    print("TRADE-OFFS:")
    print("  + Avoids code duplication (logic in one place)")
    print("  + Type-safe")
    print("  - Breaks path-like composition")
    print("  - API asymmetry between read and write")
    print("  - Less discoverable (static vs instance)")
}

main()

// ===----------------------------------------------------------------------===//
// RESULT: CONFIRMED
//
// The paper's claim is validated:
// - Static methods with borrowing parameters work in non-mutating contexts
// - This provides a viable workaround for the pointer acquisition problem
// - BUT: It breaks the path-like composition pattern (instance.accessor.method)
// - Creates API asymmetry between read (static) and write (instance) operations
// ===----------------------------------------------------------------------===//
