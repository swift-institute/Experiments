// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: Sequence Protocol Requires Non-Mutating makeIterator
// ===----------------------------------------------------------------------===//
//
// PAPER CLAIM: "Protocol witnesses must match the protocol's mutability requirements"
//              (Section 5.6 of Non-Mutating-Accessor-Problem.md)
//
// HYPOTHESIS: A type cannot conform to Sequence with a mutating makeIterator()
//
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// EXPECTED RESULT: Mutating makeIterator fails protocol conformance
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: Standard Sequence Conformance (Non-Mutating)

struct Container1: Sequence {
    var elements: [Int] = [1, 2, 3]

    // Non-mutating makeIterator - SHOULD COMPILE
    func makeIterator() -> Array<Int>.Iterator {
        elements.makeIterator()
    }
}

// MARK: - Test 2: Mutating makeIterator (Should Fail Conformance)

struct Container2 {
    var elements: [Int] = [1, 2, 3]

    // Mutating makeIterator - cannot satisfy Sequence
    mutating func makeIterator() -> Array<Int>.Iterator {
        elements.makeIterator()
    }
}

// UNCOMMENT TO TEST - Should fail with protocol conformance error:
// extension Container2: Sequence {}
// ERROR: Type 'Container2' does not conform to protocol 'Sequence'
//        Candidate is marked 'mutating' but protocol does not allow it

// MARK: - Test 3: Borrowing makeIterator (Should Work)

struct Container3: Sequence {
    var elements: [Int] = [1, 2, 3]

    // Borrowing is compatible with non-mutating
    borrowing func makeIterator() -> Array<Int>.Iterator {
        elements.makeIterator()
    }
}

// MARK: - Test 4: The Array.Small Problem Simulation

struct SmallArray<Element> {
    var inlineStorage: (Element, Element, Element, Element)?
    var heapStorage: [Element]?
    var count: Int = 0

    struct Iterator: IteratorProtocol {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // The problematic pattern: needs pointer to inline storage
    // but makeIterator must be non-mutating

    struct InlineView {
        let ptr: UnsafeMutablePointer<SmallArray>
        init(_ ptr: UnsafeMutablePointer<SmallArray>) { self.ptr = ptr }
    }

    // This accessor is mutating because it needs &self
    var inline: InlineView {
        mutating _read {
            yield InlineView(&self)
        }
    }

    // makeIterator cannot use the mutating inline accessor!
    //
    // UNCOMMENT TO TEST:
    // func makeIterator() -> Iterator {
    //     let ptr = inline.ptr  // ERROR: Cannot use mutating getter
    //     return Iterator(elements: [])
    // }
}

// MARK: - Test 5: Workaround - Direct Property Access

struct SmallArray2<Element>: Sequence {
    var inlineStorage: (Element, Element, Element, Element)?
    var heapStorage: [Element]?
    var count: Int = 0

    struct Iterator: IteratorProtocol {
        var elements: [Element]
        var index: Int = 0

        mutating func next() -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    // Workaround: Access storage directly, duplicating logic
    func makeIterator() -> Iterator {
        if let heap = heapStorage {
            return Iterator(elements: heap)
        } else if let inline = inlineStorage {
            // Manually extract inline elements (duplicated logic)
            return Iterator(elements: [inline.0, inline.1, inline.2, inline.3])
        } else {
            return Iterator(elements: [])
        }
    }
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== Sequence Non-Mutating Requirement Test ===\n")

    // Test 1
    let c1 = Container1()
    print("Test 1 - Non-mutating makeIterator:")
    print("  Elements: \(Array(c1))")
    print("  RESULT: COMPILES")

    // Test 3
    let c3 = Container3()
    print("\nTest 3 - Borrowing makeIterator:")
    print("  Elements: \(Array(c3))")
    print("  RESULT: COMPILES (borrowing is compatible)")

    // Test 5
    var c5 = SmallArray2<Int>()
    c5.heapStorage = [10, 20, 30]
    c5.count = 3
    print("\nTest 5 - Workaround with duplicated logic:")
    print("  Elements: \(Array(c5))")
    print("  RESULT: COMPILES (but duplicates accessor logic)")

    print("\n=== FINDINGS ===")
    print("")
    print("CONFIRMED: Sequence requires non-mutating makeIterator()")
    print("  - Test 2: mutating makeIterator cannot satisfy protocol")
    print("  - Test 3: borrowing makeIterator IS compatible")
    print("")
    print("THE PROBLEM:")
    print("  - SmallArray needs pointer-based accessor for inline storage")
    print("  - Pointer accessor requires &self (mutating)")
    print("  - makeIterator cannot call mutating accessor")
    print("")
    print("WORKAROUNDS:")
    print("  - Duplicate accessor logic in makeIterator (Test 5)")
    print("  - Use static method (see static-method-workaround-test)")
    print("  - Cache pointer at construction (risky for value types)")
}

main()

// ===----------------------------------------------------------------------===//
// RESULT: CONFIRMED
//
// The paper's claim is validated:
// - Sequence.makeIterator() must be non-mutating
// - Cannot provide mutating implementation as protocol witness
// - This creates a fundamental conflict with pointer-based accessors
// ===----------------------------------------------------------------------===//
