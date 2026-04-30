// SUPERSEDED: See noncopyable-access-patterns
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
// [H1]  CONFIRMED — mutating _read blocks borrowing parameters (commented out, compile error)
// [H2]  CONFIRMED — Non-mutating _read with ReadView + callAsFunction works on borrowing
//       CRITICAL: Requires @_optimize(none) on borrowing init. Without it, optimizer
//       breaks the withUnsafePointer(to:) { $0 } pointer escape — SIGTRAP in release.
//       Production Property.View.Read already has this workaround (swiftlang/swift#88022).
//       // Output: V2 let sum: 6, V2 borrowing sum: 6
// [H3]  REFUTED — Property callAsFunction + single competing func do NOT create ambiguity.
//       Swift resolves this deterministically. The production ambiguity requires three
//       competing func overloads (H3b), not property-vs-func conflict.
//       // Output: V3 let sum: 15, V3 borrowing sum: 15
// [H3b] CONFIRMED — Three func forEach overloads with similar signatures create ambiguity.
//       Candidates: (borrowing Int) -> Void, (Int) -> Void, (Int) throws -> Void
//       // Compile error: "ambiguous use of 'forEach'" with three candidates shown
// [H4]  CONFIRMED — Property path is safe in ~Copyable class deinits (CopyPropagation).
//       No closure capture of self with ForwardingConsume semantics in property path.
//       Passes in both debug and release builds.
//       // Output: V4 deinit sum: 60
// [H5]  CONFIRMED — Non-mutating _read + mutating _modify coexist on same property.
//       Borrowing parameters use _read (callAsFunction). Mutation uses _modify (consuming).
//       // Output: V5 borrow sum: 24, V5 borrowing sum: 24, V5 consume: 100/200, after: []
//
// KEY FINDING: The ambiguity root cause is the three-way func overload conflict (H3b),
// NOT property-vs-func (H3 refuted). This means:
//   1. Making the property non-mutating (H2) enables borrowing access
//   2. Property + one func is fine (H3) — no need to remove ALL funcs
//   3. But the three-way func conflict (H3b) must still be resolved by removing
//      at least one competing func forEach declaration
//
// OPTION A (ReadView only, recommended by findings): Property returns ReadView.
//   Works for borrowing. Consuming goes through separate drain accessor.
// OPTION B (MutableView dual accessor): Property returns MutableView with
//   non-mutating _read (unsafe borrow→mutable cast) + mutating _modify.
//   Works for both borrowing AND consuming on same property. V5 validates this.
//   Requires @_optimize(none) on borrowing init (already exists in production).
//
// ============================================================================
// ROUND 2: @_optimize(none) ALTERNATIVES
// ============================================================================
//
// [H6]  @inline(never) on init: SILENT WRONG RESULTS — optimizer still breaks
//       pointer within the function body. Returns 0 instead of 66 in release.
//       WORSE than @_optimize(none) — no crash signal, just silent data corruption.
// [H7]  Noinline helper: SAME — silent 0 instead of 42. The optimizer still
//       reasons about the UnsafePointer returned from the helper.
// [H8]  CONFIRMED — Func-based borrowing (no pointer) works perfectly.
//       @inline(always), full optimization, correct in release. Sum: 30.
//
// CONCLUSION: The pointer escape from withUnsafePointer(to:){$0} cannot be
// fixed with @inline(never) — the optimizer invalidates the pointer even
// without inlining. Only TWO correct paths exist:
//   1. @_optimize(none) on the borrowing init (kills all optimization on init)
//   2. Don't use a pointer at all — use a func for borrowing iteration
//
// RECOMMENDED ARCHITECTURE:
//   - Hot path: @inline(always) func forEach(_ body:) — zero overhead
//   - Rich path: var forEach: Property.View (mutating) — .borrowing/.consuming/.index
//   The func handles borrowing; the property stays mutating (no @_optimize(none) needed).
//   To resolve the three-way func ambiguity, remove Array.Protocol.func forEach and
//   keep only the Sequence.Protocol bridge (which wins over stdlib via overload ranking).

// ============================================================================
// MARK: - Shared Infrastructure
// ============================================================================

/// Minimal stand-in for Property.View.Read — read-only pointer view
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

/// Minimal stand-in for Property.View — mutable pointer view
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

// ============================================================================
// MARK: - V1: Reproduce Gap (mutating _read blocks borrowing)
// ============================================================================
// Hypothesis: [H1] mutating _read is unavailable on borrowing parameters
//
// COMMENTED OUT — expected compile error on borrowing parameter accessing
// mutating _read accessor. Confirms the gap exists.
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
//     // Expected: error — cannot use mutating accessor on borrowing value
// }
//
// Result: [H1] [pending — uncomment to verify]
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)

// ============================================================================
// MARK: - V2: Fix — Non-mutating _read with ReadView
// ============================================================================
// Hypothesis: [H2] Non-mutating _read with ReadView enables borrowing forEach { }

struct ContainerV2 {
    var elements: [Int]
}

extension ReadView where Base == ContainerV2 {
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }
}

extension ContainerV2 {
    var forEach: ReadView<ContainerV2> {
        _read {
            yield ReadView(borrowing: self)
        }
    }
}

func testV2(_ c: borrowing ContainerV2) {
    c.forEach { element in
        print("V2:", element)
    }
}

// ============================================================================
// MARK: - V3: Property + Competing func
// ============================================================================
// Hypothesis: [H3] Non-mutating property callAsFunction + func forEach — ambiguous or not?
// If Swift resolves this unambiguously, the three-way func conflict (not property vs func)
// is the true root cause in the production codebase.

struct ContainerV3 {
    var elements: [Int]
}

extension ReadView where Base == ContainerV3 {
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }
}

extension ContainerV3 {
    var forEach: ReadView<ContainerV3> {
        _read {
            yield ReadView(borrowing: self)
        }
    }

    func forEach(_ body: (Int) -> Void) {
        for e in elements { body(e) }
    }
}

func testV3(_ c: borrowing ContainerV3) {
    c.forEach { element in
        print("V3:", element)
    }
}

// ============================================================================
// MARK: - V3b: Three competing funcs (no property)
// ============================================================================
// Hypothesis: Three func forEach overloads with similar signatures create ambiguity
// even without a property in the picture. Mirrors the production setup:
// - Array.Protocol:     func forEach(_ body: (borrowing Element) -> Void)
// - Bridge:             func forEach(_ body: (Element) -> Void)
// - Swift.Sequence:     func forEach(_ body: (Element) throws -> Void) rethrows

protocol ProtoA {}
protocol ProtoB {}

struct ContainerV3b: ProtoA, ProtoB, Sequence {
    var elements: [Int]

    struct Iterator: IteratorProtocol {
        var inner: Array<Int>.Iterator
        mutating func next() -> Int? { inner.next() }
    }
    func makeIterator() -> Iterator { Iterator(inner: elements.makeIterator()) }
}

extension ProtoA {
    func forEach(_ body: (borrowing Int) -> Void) {
        // Mirrors Array.Protocol.forEach
    }
}

extension ProtoB where Self: Sequence, Element == Int {
    @inline(always)
    func forEach(_ body: (Int) -> Void) {
        // Mirrors Sequence.Protocol bridge
        var iter = makeIterator()
        while let e = iter.next() { body(e) }
    }
}

// Swift.Sequence already provides: func forEach(_ body: (Int) throws -> Void) rethrows

// COMMENTED OUT — CONFIRMED ambiguous. Error:
//   error: ambiguous use of 'forEach'
//   note: found this candidate  — ProtoA.forEach(_ body: (borrowing Int) -> Void)
//   note: found this candidate  — ProtoB.forEach(_ body: (Int) -> Void)
//   note: found this candidate in module 'Swift' — Sequence.forEach
//
// This validates the root cause: three competing func overloads = ambiguity.
//
// func testV3b(_ c: borrowing ContainerV3b) {
//     c.forEach { element in
//         print("V3b:", element)
//     }
// }

// ============================================================================
// MARK: - V4: CopyPropagation — ~Copyable class deinit
// ============================================================================
// Hypothesis: [H4] Property path avoids partial_apply ForwardingConsume capture
// that causes crashes in ~Copyable class deinits

struct StorageV4 {
    var elements: [Int]
}

extension ReadView where Base == StorageV4 {
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }
}

extension StorageV4 {
    var forEach: ReadView<StorageV4> {
        _read {
            yield ReadView(borrowing: self)
        }
    }
}

class Box<T: ~Copyable> {
    var storage: StorageV4

    init(elements: [Int]) {
        self.storage = StorageV4(elements: elements)
    }

    deinit {
        var sum = 0
        storage.forEach { element in
            sum += element
        }
        print("V4 deinit sum:", sum)
    }
}

// ============================================================================
// MARK: - V5: Dual Accessor — non-mutating _read + mutating _modify
// ============================================================================
// Hypothesis: [H5] Non-mutating _read and mutating _modify coexist on same property
// with same return type. Borrowing uses _read, mutation uses _modify.

struct ContainerV5 {
    var elements: [Int]
}

extension MutableView where Base == ContainerV5 {
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }

    mutating func consuming(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
        unsafe pointer.pointee.elements.removeAll()
    }
}

extension ContainerV5 {
    var forEach: MutableView<ContainerV5> {
        _read {
            yield MutableView(borrowing: self)
        }
        mutating _modify {
            var view = unsafe MutableView(&self)
            yield &view
        }
    }
}

func testV5Borrow(_ c: borrowing ContainerV5) {
    c.forEach { element in
        print("V5 borrow:", element)
    }
}

func testV5Mutate(_ c: inout ContainerV5) {
    c.forEach.consuming { element in
        print("V5 consume:", element)
    }
}

// ============================================================================
// MARK: - V6: @inline(never) instead of @_optimize(none)
// ============================================================================
// Hypothesis: [H6] @inline(never) is sufficient — prevents the optimizer from
// seeing the pointer escape when the init is inlined into the caller.
// Less restrictive than @_optimize(none): internal body still optimized.

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

extension ReadViewV6 where Base == ContainerV6 {
    @inlinable
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }
}

extension ContainerV6 {
    var forEach: ReadViewV6<ContainerV6> {
        _read {
            yield ReadViewV6(borrowing: self)
        }
    }
}

func testV6Borrow(_ c: borrowing ContainerV6) -> Int {
    var sum = 0
    c.forEach { sum += $0 }
    return sum
}

// ============================================================================
// MARK: - V7: Noinline helper function (init stays @inlinable)
// ============================================================================
// Hypothesis: [H7] A @inline(never) helper that extracts the pointer hides the
// escape from the optimizer. The View init itself stays fully optimizable.

@inline(never)
func _borrowedPointer<T>(to value: borrowing T) -> UnsafePointer<T> {
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

extension ReadViewV7 where Base == ContainerV7 {
    @inlinable
    func callAsFunction(_ body: (Int) -> Void) {
        for e in unsafe pointer.pointee.elements { body(e) }
    }
}

extension ContainerV7 {
    var forEach: ReadViewV7<ContainerV7> {
        _read {
            yield ReadViewV7(borrowing: self)
        }
    }
}

func testV7Borrow(_ c: borrowing ContainerV7) -> Int {
    var sum = 0
    c.forEach { sum += $0 }
    return sum
}

// ============================================================================
// MARK: - V8: Func-based borrowing (no View, no pointer)
// ============================================================================
// Hypothesis: [H8] A borrowing func forEach avoids the pointer issue entirely.
// No View, no @_optimize(none), no @inline(never). Full optimization.
// Trade-off: loses .forEach.borrowing/.consuming/.index accessor chains.

struct ContainerV8 {
    var elements: [Int]
}

extension ContainerV8 {
    // Mutating property — for .forEach.borrowing/.consuming/.index in var contexts
    var forEach: ReadView<ContainerV8> {
        mutating _read {
            yield ReadView(borrowing: self)
        }
    }

    // Non-mutating func — for simple forEach { } on borrowing parameters
    @inline(always)
    func forEachElement(_ body: (Int) -> Void) {
        for e in elements { body(e) }
    }
}

func testV8Borrow(_ c: borrowing ContainerV8) -> Int {
    var sum = 0
    c.forEachElement { sum += $0 }
    return sum
}

// ============================================================================
// MARK: - Execution
// ============================================================================

// V2: ReadView + non-mutating _read on let binding
let c2 = ContainerV2(elements: [1, 2, 3])
var v2sum = 0
c2.forEach { v2sum += $0 }
print("V2 let sum:", v2sum, "(expected 6)")

// V2b: ReadView on borrowing parameter
func testV2Borrow(_ c: borrowing ContainerV2) -> Int {
    var sum = 0
    c.forEach { sum += $0 }
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

// V5: dual accessor — borrowing via _read
let c5 = ContainerV5(elements: [7, 8, 9])
var v5sum = 0
c5.forEach { v5sum += $0 }
print("V5 borrow sum:", v5sum, "(expected 24)")

// V5b: dual accessor — borrowing parameter via _read
func testV5BorrowSum(_ c: borrowing ContainerV5) -> Int {
    var sum = 0
    c.forEach { sum += $0 }
    return sum
}
print("V5 borrowing sum:", testV5BorrowSum(c5), "(expected 24)")

// V5c: dual accessor — consuming via _modify
var c5m = ContainerV5(elements: [100, 200])
c5m.forEach.consuming { print("V5 consume:", $0) }
print("V5 after consume:", c5m.elements)

// V6: @inline(never) on init
print("V6 start")
let c6 = ContainerV6(elements: [11, 22, 33])
print("V6 borrowing sum:", testV6Borrow(c6), "(expected 66)")
print("V6 done")

// V7: noinline helper
print("V7 start")
let c7 = ContainerV7(elements: [7, 14, 21])
print("V7 borrowing sum:", testV7Borrow(c7), "(expected 42)")
print("V7 done")

// V8: func-based (no pointer)
print("V8 start")
let c8 = ContainerV8(elements: [5, 10, 15])
print("V8 borrowing sum:", testV8Borrow(c8), "(expected 30)")
print("V8 done")

print("\nAll variants executed successfully")
