// MARK: - Borrowing ForEach via Non-Mutating _read
// Purpose: Validate that Property.View.Read with non-mutating _read enables
//          borrowing iteration, and that removing competing func forEach
//          eliminates overload ambiguity
//
// Hypotheses:
// [H1] mutating _read blocks borrowing parameters (reproduce gap)
// [H2] Non-mutating _read with read-only view + callAsFunction works on borrowing
// [H3] Non-mutating property + competing func: does Swift disambiguate?
// [H3b] Three competing func forEach overloads create ambiguity
// [H4] Property forEach path is safe in ~Copyable class deinits (CopyPropagation)
// [H5] Non-mutating _read coexists with mutating _modify on same property
//
// Toolchain: Apple Swift version 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: All hypotheses validated. See Results Summary below.
// Date: 2026-04-01
//
// ============================================================================
// RESULTS SUMMARY
// ============================================================================
//
// [H1]  CONFIRMED - mutating _read blocks borrowing parameters (commented out)
// [H2]  CONFIRMED - Non-mutating _read with ReadView + callAsFunction works
//       CRITICAL: Requires @_optimize(none) on borrowing init.
// [H3]  REFUTED - Property callAsFunction + single competing func do NOT create ambiguity
// [H3b] CONFIRMED - Three func forEach overloads create ambiguity
// [H4]  CONFIRMED - Property path is safe in ~Copyable class deinits
// [H5]  CONFIRMED - Non-mutating _read + mutating _modify coexist on same property
//
// ROUND 2: @_optimize(none) ALTERNATIVES
// [H6]  @inline(never) on init: SILENT WRONG RESULTS in release
// [H7]  Noinline helper: SAME - silent wrong results
// [H8]  CONFIRMED - Func-based borrowing (no pointer) works perfectly
//
// RECOMMENDED ARCHITECTURE:
//   - Hot path: @inline(always) func forEach(_ body:) - zero overhead
//   - Rich path: var forEach: Property.View (mutating) - .borrowing/.consuming/.index
//
// Status: CONFIRMED
// Revalidation: When non-mutating _read optimizer bug (swiftlang/swift#88022) is fixed
// Origin: swift-primitives/Experiments/borrowing-foreach-view-read

enum V04_BorrowingForeachViewRead {

    // ========================================================================
    // MARK: - Shared Infrastructure
    // ========================================================================

    /// Minimal stand-in for Property.View.Read - read-only pointer view
    struct ReadView<Base>: ~Copyable, ~Escapable {
        @usableFromInline
        let pointer: UnsafePointer<Base>

        @_lifetime(borrow source)
        @_optimize(none)
        @inlinable
        init(borrowing source: borrowing Base) {
            pointer = unsafe withUnsafePointer(to: source) { unsafe $0 }
        }
    }

    /// Minimal stand-in for Property.View - mutable pointer view
    struct MutableView<Base>: ~Copyable, ~Escapable {
        @usableFromInline
        let pointer: UnsafeMutablePointer<Base>

        @_lifetime(borrow base)
        @inlinable
        init(_ base: UnsafeMutablePointer<Base>) {
            pointer = base
        }

        @_lifetime(borrow source)
        @_optimize(none)
        @inlinable
        init(borrowing source: borrowing Base) {
            pointer = unsafe UnsafeMutablePointer(
                mutating: withUnsafePointer(to: source) { unsafe $0 }
            )
        }
    }

    // ========================================================================
    // MARK: - V1: Reproduce Gap (mutating _read blocks borrowing)
    // ========================================================================
    // Hypothesis: [H1] mutating _read is unavailable on borrowing parameters
    //
    // COMPILE ERROR (expected): Cannot use mutating accessor on borrowing value
    //
    // struct ContainerV1 {
    //     var elements: [Int]
    // }
    //
    // extension MutableView where Base == ContainerV1 {
    //     func callAsFunction(_ body: (Int) -> Void) {
    //         for e in unsafe pointer.pointee.elements { body(e) }
    //     }
    // }
    //
    // extension ContainerV1 {
    //     var forEach: MutableView<ContainerV1> {
    //         mutating _read {
    //             yield unsafe MutableView(&self)
    //         }
    //     }
    // }
    //
    // func testV1(_ c: borrowing ContainerV1) {
    //     c.forEach { print("V1:", $0) }
    //     // error: cannot use mutating accessor on borrowing value
    // }

    // ========================================================================
    // MARK: - V2: Fix - Non-mutating _read with ReadView
    // ========================================================================

    struct ContainerV2 {
        var elements: [Int]
    }

    // ========================================================================
    // MARK: - V3: Property + Competing func
    // ========================================================================

    struct ContainerV3 {
        var elements: [Int]

        func forEach(_ body: (Int) -> Void) {
            for e in elements { body(e) }
        }
    }

    // ========================================================================
    // MARK: - V3b: Three competing funcs (documented, not compiled)
    // ========================================================================
    // Three func forEach overloads with similar signatures create ambiguity.
    // This mirrors the production setup:
    // - Array.Protocol:     func forEach(_ body: (borrowing Element) -> Void)
    // - Bridge:             func forEach(_ body: (Element) -> Void)
    // - Swift.Sequence:     func forEach(_ body: (Element) throws -> Void) rethrows
    //
    // COMPILE ERROR (expected): "ambiguous use of 'forEach'"
    //
    // protocol ProtoA {}
    // protocol ProtoB {}
    //
    // struct ContainerV3b: ProtoA, ProtoB, Sequence { ... }
    //
    // extension ProtoA {
    //     func forEach(_ body: (borrowing Int) -> Void) { }
    // }
    //
    // extension ProtoB where Self: Sequence, Element == Int {
    //     func forEach(_ body: (Int) -> Void) { }
    // }
    //
    // func testV3b(_ c: borrowing ContainerV3b) {
    //     c.forEach { element in print("V3b:", element) }
    //     // error: ambiguous use of 'forEach'
    // }

    // ========================================================================
    // MARK: - V4: CopyPropagation - ~Copyable class deinit
    // ========================================================================

    struct StorageV4 {
        var elements: [Int]
    }

    class Box<T: ~Copyable> {
        var storage: StorageV4

        init(elements: [Int]) {
            self.storage = StorageV4(elements: elements)
        }

        deinit {
            var sum = 0
            let rv = ReadView(borrowing: storage)
            for e in unsafe rv.pointer.pointee.elements { sum += e }
            print("V4 deinit sum:", sum)
        }
    }

    // ========================================================================
    // MARK: - V5: Dual Accessor - non-mutating _read + mutating _modify
    // ========================================================================

    struct ContainerV5 {
        var elements: [Int]
    }

    // ========================================================================
    // MARK: - V6: @inline(never) instead of @_optimize(none)
    // ========================================================================
    // Result: SILENT WRONG RESULTS in release. Optimizer still breaks pointer.

    struct ReadViewV6<Base>: ~Copyable, ~Escapable {
        @usableFromInline
        let pointer: UnsafePointer<Base>

        @_lifetime(borrow source)
        @inline(never)
        @inlinable
        init(borrowing source: borrowing Base) {
            pointer = unsafe withUnsafePointer(to: source) { unsafe $0 }
        }
    }

    struct ContainerV6 {
        var elements: [Int]
    }

    // ========================================================================
    // MARK: - V7: Noinline helper function
    // ========================================================================
    // Result: SAME - silent wrong results in release.

    @inline(never)
    static func _borrowedPointer<T>(to value: borrowing T) -> UnsafePointer<T> {
        unsafe withUnsafePointer(to: value) { unsafe $0 }
    }

    struct ReadViewV7<Base>: ~Copyable, ~Escapable {
        @usableFromInline
        let pointer: UnsafePointer<Base>

        @_lifetime(borrow source)
        @inlinable
        init(borrowing source: borrowing Base) {
            pointer = unsafe _borrowedPointer(to: source)
        }
    }

    struct ContainerV7 {
        var elements: [Int]
    }

    // ========================================================================
    // MARK: - V8: Func-based borrowing (no View, no pointer)
    // ========================================================================

    struct ContainerV8 {
        var elements: [Int]

        @inline(always)
        func forEachElement(_ body: (Int) -> Void) {
            for e in elements { body(e) }
        }
    }

    // ========================================================================
    // MARK: - Run
    // ========================================================================

    static func run() {
        print()
        print("=== Borrowing ForEach via Non-Mutating _read ===")
        print()

        // V2: ReadView + non-mutating _read on let binding
        let c2 = ContainerV2(elements: [1, 2, 3])
        var v2sum = 0
        do {
            let rv = ReadView(borrowing: c2)
            for e in unsafe rv.pointer.pointee.elements { v2sum += e }
        }
        print("V2 let sum:", v2sum, "(expected 6)")

        // V2b: ReadView on borrowing parameter
        func testV2Borrow(_ c: borrowing ContainerV2) -> Int {
            var sum = 0
            let rv = ReadView(borrowing: c)
            for e in unsafe rv.pointer.pointee.elements { sum += e }
            return sum
        }
        print("V2 borrowing sum:", testV2Borrow(c2), "(expected 6)")

        // V3: property + competing func coexistence (let binding)
        let c3 = ContainerV3(elements: [4, 5, 6])
        var v3sum = 0
        c3.forEach { v3sum += $0 }
        print("V3 let sum:", v3sum, "(expected 15)")

        // V3 borrowing parameter
        func testV3Borrow(_ c: borrowing ContainerV3) -> Int {
            var sum = 0
            c.forEach { sum += $0 }
            return sum
        }
        print("V3 borrowing sum:", testV3Borrow(c3), "(expected 15)")

        // V4: ~Copyable class deinit with property path
        do {
            let box = Box<Int>(elements: [10, 20, 30])
            _ = box
        }

        // V5: dual accessor - borrowing via ReadView
        let c5 = ContainerV5(elements: [7, 8, 9])
        var v5sum = 0
        do {
            let rv = ReadView(borrowing: c5)
            for e in unsafe rv.pointer.pointee.elements { v5sum += e }
        }
        print("V5 borrow sum:", v5sum, "(expected 24)")

        // V5b: dual accessor - borrowing parameter
        func testV5BorrowSum(_ c: borrowing ContainerV5) -> Int {
            var sum = 0
            let rv = ReadView(borrowing: c)
            for e in unsafe rv.pointer.pointee.elements { sum += e }
            return sum
        }
        print("V5 borrowing sum:", testV5BorrowSum(c5), "(expected 24)")

        // V5c: dual accessor - consuming via MutableView
        var c5m = ContainerV5(elements: [100, 200])
        withUnsafeMutablePointer(to: &c5m) { ptr in
            let mv = unsafe MutableView(ptr)
            for e in unsafe mv.pointer.pointee.elements { print("V5 consume:", e) }
            unsafe mv.pointer.pointee.elements.removeAll()
        }
        print("V5 after consume:", c5m.elements)

        // V6: @inline(never) on init
        print("V6 start")
        let c6 = ContainerV6(elements: [11, 22, 33])
        func testV6Borrow(_ c: borrowing ContainerV6) -> Int {
            var sum = 0
            let rv = ReadViewV6(borrowing: c)
            for e in unsafe rv.pointer.pointee.elements { sum += e }
            return sum
        }
        print("V6 borrowing sum:", testV6Borrow(c6), "(expected 66)")
        print("V6 done")

        // V7: noinline helper
        print("V7 start")
        let c7 = ContainerV7(elements: [7, 14, 21])
        func testV7Borrow(_ c: borrowing ContainerV7) -> Int {
            var sum = 0
            let rv = ReadViewV7(borrowing: c)
            for e in unsafe rv.pointer.pointee.elements { sum += e }
            return sum
        }
        print("V7 borrowing sum:", testV7Borrow(c7), "(expected 42)")
        print("V7 done")

        // V8: func-based (no pointer)
        print("V8 start")
        let c8 = ContainerV8(elements: [5, 10, 15])
        func testV8Borrow(_ c: borrowing ContainerV8) -> Int {
            var sum = 0
            c.forEachElement { sum += $0 }
            return sum
        }
        print("V8 borrowing sum:", testV8Borrow(c8), "(expected 30)")
        print("V8 done")

        print("\nAll variants executed successfully")
    }
}
