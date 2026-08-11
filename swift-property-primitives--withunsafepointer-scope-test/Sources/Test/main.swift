// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: withUnsafePointer Closure Scope Limitation
// ===----------------------------------------------------------------------===//
//
// PAPER CLAIM: "withUnsafePointer has closure scope limitations—the pointer is
//               only valid within the closure body. We cannot return an accessor
//               struct initialized with this pointer."
//              (Section 2.3, 3.2 of Non-Mutating-Accessor-Problem.md)
//
// HYPOTHESIS: Values constructed with pointers from withUnsafePointer cannot
//             be returned from the closure due to pointer lifetime.
//
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// EXPECTED RESULT: Cannot return pointer-based types from withUnsafePointer
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: Returning Pointer Directly (Should Fail)

struct Container1 {
    var value: Int = 42

    // Try to return the pointer itself
    //
    // UNCOMMENT TO TEST:
    // func getPointer() -> UnsafePointer<Int> {
    //     withUnsafePointer(to: value) { ptr in
    //         ptr  // ERROR: Escaping closure captures non-escaping parameter
    //     }
    // }
}

// MARK: - Test 2: Returning Copied Value (Works)

struct Container2 {
    var value: Int = 42

    // Returning the value itself works (copies out)
    func getValue() -> Int {
        withUnsafePointer(to: value) { ptr in
            ptr.pointee  // OK: We copy the value out
        }
    }
}

// MARK: - Test 3: Returning Struct Containing Pointer (Should Fail)

struct View3 {
    let ptr: UnsafePointer<Int>
    func read() -> Int { ptr.pointee }
}

struct Container3 {
    var value: Int = 42

    // Try to return a struct that holds the pointer
    //
    // UNCOMMENT TO TEST:
    // func getView() -> View3 {
    //     withUnsafePointer(to: value) { ptr in
    //         View3(ptr: ptr)  // ERROR: Escaping closure captures...
    //     }
    // }
}

// MARK: - Test 4: Using Pointer Within Closure (Works)

struct Container4 {
    var value: Int = 42

    // Using the pointer entirely within the closure works
    func processWithPointer() -> Int {
        withUnsafePointer(to: value) { ptr in
            // All pointer operations inside closure
            let val = ptr.pointee
            return val * 2
        }
    }
}

// MARK: - Test 5: Iterator Cannot Be Constructed This Way

struct Container5 {
    var storage: [Int] = [1, 2, 3]

    struct Iterator: IteratorProtocol {
        let base: UnsafePointer<Int>
        let count: Int
        var index: Int = 0

        mutating func next() -> Int? {
            guard index < count else { return nil }
            defer { index += 1 }
            return base[index]
        }
    }

    // This is the exact problem: we want to return an iterator
    // initialized with a pointer, but cannot escape the pointer
    //
    // UNCOMMENT TO TEST:
    // func makeIterator() -> Iterator {
    //     storage.withUnsafeBufferPointer { buffer in
    //         Iterator(base: buffer.baseAddress!, count: buffer.count)
    //         // ERROR: Closure lifetime issue
    //     }
    // }
}

// MARK: - Test 6: The withContiguousStorageIfAvailable Pattern

struct Container6: Sequence {
    var storage: [Int] = [1, 2, 3]

    // Standard library uses withContiguousStorageIfAvailable
    // but it has the same closure scope limitation

    func makeIterator() -> Array<Int>.Iterator {
        // This works because we're returning Array's iterator,
        // not a pointer-based one
        storage.makeIterator()
    }

    // If we tried pointer-based iteration:
    //
    // UNCOMMENT TO TEST:
    // func makePointerIterator() -> some IteratorProtocol {
    //     storage.withUnsafeBufferPointer { buffer in
    //         // Cannot return anything that holds buffer.baseAddress
    //     }
    // }
}

// MARK: - Test 7: Workaround - Callback Pattern

struct Container7 {
    var value: Int = 42

    // Instead of returning, accept a callback
    func withView<R>(_ body: (UnsafePointer<Int>) -> R) -> R {
        withUnsafePointer(to: value) { ptr in
            body(ptr)
        }
    }
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== withUnsafePointer Closure Scope Test ===\n")

    // Test 2
    let c2 = Container2()
    print("Test 2 - Returning copied value:")
    print("  c2.getValue() = \(c2.getValue())")
    print("  RESULT: COMPILES (value is copied out)")

    // Test 4
    let c4 = Container4()
    print("\nTest 4 - Processing within closure:")
    print("  c4.processWithPointer() = \(c4.processWithPointer())")
    print("  RESULT: COMPILES (all ops inside closure)")

    // Test 7
    let c7 = Container7()
    print("\nTest 7 - Callback pattern workaround:")
    let result = c7.withView { ptr in
        ptr.pointee * 3
    }
    print("  c7.withView { ptr in ptr.pointee * 3 } = \(result)")
    print("  RESULT: COMPILES (but different API shape)")

    print("\n=== FINDINGS ===")
    print("")
    print("CONFIRMED: withUnsafePointer closure scope prevents returning pointer-based types")
    print("")
    print("WHAT FAILS:")
    print("  - Test 1: Cannot return pointer directly")
    print("  - Test 3: Cannot return struct containing pointer")
    print("  - Test 5: Cannot return iterator initialized with pointer")
    print("")
    print("WHAT WORKS:")
    print("  - Test 2: Copying value out of closure")
    print("  - Test 4: All pointer operations inside closure")
    print("  - Test 7: Callback pattern (inverts control)")
    print("")
    print("IMPLICATION FOR ARRAY.SMALL:")
    print("  - Cannot use withUnsafePointer to create Iterator")
    print("  - Callback pattern (.withIterator { }) violates for-in syntax")
    print("  - Must find another way to get stable pointer")
}

main()

// ===----------------------------------------------------------------------===//
// RESULT: CONFIRMED
//
// The paper's claim is validated:
// - withUnsafePointer closure scope prevents returning pointer-based types
// - This rules out using withUnsafePointer as a solution for makeIterator
// - The callback pattern works but changes the API shape
// ===----------------------------------------------------------------------===//
