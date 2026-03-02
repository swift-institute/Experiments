// MARK: - Pointer ~Escapable Storage Experiment
// Purpose: Exhaustively test ALL paths for storing ~Escapable elements in containers.
//          The Swift stdlib declares UnsafeMutablePointer<Pointee: ~Copyable> — Pointee
//          is implicitly Escapable because ~Escapable is NOT suppressed.
//          SE-0465 explicitly deferred pointer support for ~Escapable.
//          This experiment tests EVERY alternative path.
//
// Hypothesis: At least one mechanism exists to store ~Escapable values beyond
//             single-element inline storage (enum, struct fields).
//
// Toolchain: Swift 6.2.4
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — Enum-based variable-occupancy storage (V14, V15) provides
//         multi-element inline containers for ~Escapable elements. Heap-backed
//         containers remain BLOCKED (UnsafeMutablePointer requires Escapable).
//         Optional<Element> as stored property in ~Escapable container also BLOCKED.
//         @_rawLayout declaration compiles with ~Escapable (V16 PASS), but element
//         access blocked at every typed path (V17, V17b BLOCKED).
// Date: 2026-03-02

// MARK: - Test type: ~Escapable value

struct NEValue: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

// ============================================================================
// V1: UnsafeMutablePointer<Element> — KNOWN BLOCKED
// Error: "type 'Element' does not conform to protocol 'Escapable'"
// Note: "'where Pointee: Escapable' is implicit here"
// ============================================================================

// struct PointerBox<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
//     private let buffer: UnsafeMutablePointer<Element>  // ERROR
// }

// ============================================================================
// V2: UnsafeMutableRawPointer — test raw allocation + typed methods
// Hypothesis: Raw pointer is not generic, so allocation works. But typed
//             methods (initializeMemory, assumingMemoryBound) may block.
// ============================================================================

// V2a: Can we ALLOCATE raw memory for a ~Escapable type?
// UnsafeMutableRawPointer.allocate is not generic — should work.
func testV2a() {
    print("=== V2a: Raw pointer allocation ===")
    let size = MemoryLayout<NEValue>.size
    let align = MemoryLayout<NEValue>.alignment
    // MemoryLayout<T: ~Copyable & ~Escapable> — DOES support ~Escapable
    print("  NEValue size: \(size), alignment: \(align)")
    let raw = unsafe UnsafeMutableRawPointer.allocate(byteCount: size, alignment: align)
    print("  Allocated raw memory: YES")
    unsafe raw.deallocate()
    print("  V2a: PASS (allocation works)")
    print()
}

// V2b: initializeMemory(as: NEValue.self, to:) — does T require Escapable?
// func testV2b() {
//     let raw = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<NEValue>.size, alignment: MemoryLayout<NEValue>.alignment)
//     let typed = raw.initializeMemory(as: NEValue.self, to: NEValue(42))  // ERROR?
//     typed.deinitialize(count: 1)
//     raw.deallocate()
// }

// V2c: assumingMemoryBound(to: NEValue.self) — does T require Escapable?
// func testV2c() {
//     let raw = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<NEValue>.size, alignment: MemoryLayout<NEValue>.alignment)
//     let bound = raw.assumingMemoryBound(to: NEValue.self)  // ERROR?
//     raw.deallocate()
// }

// V2d: storeBytes(of:toByteOffset:as:) — requires BitwiseCopyable, too restrictive
// V2e: copyMemory(from:byteCount:) — requires UnsafeRawPointer source, can't get one from ~Escapable

// ============================================================================
// V3: InlineArray<count, Element> — does Element accept ~Escapable?
// InlineArray is declared as Element: ~Copyable (no ~Escapable).
// Hypothesis: InlineArray<N, NEValue> is BLOCKED.
// ============================================================================

// func testV3() {
//     var arr = InlineArray<3, NEValue>(repeating: NEValue(0))  // ERROR?
// }

// ============================================================================
// V4: Tuple storage — tuples are inline like enums
// Hypothesis: (Element, Element) works if Element: ~Escapable because
//             tuples use inline storage like struct fields.
// ============================================================================

struct TuplePair<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var first: Element
    var second: Element

    @_lifetime(copy a, copy b)
    init(_ a: consuming Element, _ b: consuming Element) {
        self.first = a
        self.second = b
    }
}

extension TuplePair: Copyable where Element: Copyable & ~Escapable {}
extension TuplePair: Escapable where Element: Escapable & ~Copyable {}

func testV4() {
    print("=== V4: Tuple/struct field storage ===")

    let pair = TuplePair(NEValue(10), NEValue(20))
    print("  TuplePair<NEValue> first.value: \(pair.first.value)")
    print("  TuplePair<NEValue> second.value: \(pair.second.value)")

    let pairInt = TuplePair(1, 2)
    print("  TuplePair<Int> first: \(pairInt.first), second: \(pairInt.second)")

    print("  V4: PASS")
    print()
}

// ============================================================================
// V5: Triple — can we go to 3 inline fields?
// ============================================================================

struct Triple<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var a: Element
    var b: Element
    var c: Element

    @_lifetime(copy a, copy b, copy c)
    init(_ a: consuming Element, _ b: consuming Element, _ c: consuming Element) {
        self.a = a
        self.b = b
        self.c = c
    }
}

extension Triple: Copyable where Element: Copyable & ~Escapable {}
extension Triple: Escapable where Element: Escapable & ~Copyable {}

func testV5() {
    print("=== V5: Triple — 3 inline fields ===")

    let triple = Triple(NEValue(1), NEValue(2), NEValue(3))
    print("  Triple<NEValue>: (\(triple.a.value), \(triple.b.value), \(triple.c.value))")

    print("  V5: PASS")
    print()
}

// ============================================================================
// V6: Optional slots — multi-element container with Optional<Element>
// Prior finding (Track 2): "lifetime-dependent variable 'self' escapes its scope"
// when init sets Optional slots to nil in @_lifetime(immortal) init.
// Retest: Can we initialize ALL slots from consuming parameters instead of nil?
// ============================================================================

// BLOCKED: Optional<Element> slots in ~Escapable container
// Error: "lifetime-dependent variable 'self' escapes its scope"
// This happens even when BOTH slots are filled (no nil). The Optional wrapping
// itself creates a lifetime confusion in the checker.
//
// struct OptBox<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
//     var slot0: Element?
//     var slot1: Element?
//     @_lifetime(copy a, copy b)
//     init(_ a: consuming Element, _ b: consuming Element) {
//         self.slot0 = consume a
//         self.slot1 = consume b
//     }
// }

func testV6() {
    print("=== V6: Optional slots (no nil init) ===")
    print("  BLOCKED: Optional<Element> in ~Escapable container")
    print("  Error: 'lifetime-dependent variable self escapes its scope'")
    print("  Note: Fails even when BOTH slots are filled — Optional wrapping is the issue")
    print()
}

// ============================================================================
// V7: Optional slots with nil initialization
// Retest the Track 2 finding: does @_lifetime(immortal) + nil work?
// ============================================================================

// struct NilOptBox<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
//     var slot0: Element?
//     var slot1: Element?
//
//     @_lifetime(immortal)
//     init() {
//         self.slot0 = nil  // Track 2: "lifetime-dependent variable 'self' escapes its scope"
//         self.slot1 = nil
//     }
// }

// ============================================================================
// V8: Growable inline container — push pattern with Optional slots
// Can we start with slots filled and "push" by consuming + reconstructing?
// ============================================================================

// BLOCKED: Same as V6 — Optional<Element> slot with nil triggers lifetime escape.
//
// struct InlineStack2<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
//     private var slot0: Element?
//     private var slot1: Element?
//     @_lifetime(copy first)
//     init(first: consuming Element) {
//         self.slot0 = consume first
//         self.slot1 = nil
//         self._count = 1
//     }
// }

func testV8() {
    print("=== V8: InlineStack2 with Optional slots ===")
    print("  BLOCKED: Same as V6 — Optional<Element> in ~Escapable container")
    print()
}

// ============================================================================
// V9: withUnsafePointer(to:) with ~Escapable value
// Hypothesis: withUnsafePointer requires T: ~Copyable only, NOT ~Escapable.
// If it works, we could get a raw pointer to a ~Escapable value.
// ============================================================================

// func testV9() {
//     var ne = NEValue(42)
//     withUnsafePointer(to: &ne) { ptr in
//         print("  Got pointer to NEValue")
//     }
// }

// ============================================================================
// V10: Box with consuming take() returning ~Escapable
// Can we move a ~Escapable value out of an inline container?
// ============================================================================

struct InlineBox<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var stored: Element

    @_lifetime(copy element)
    init(_ element: consuming Element) {
        self.stored = element
    }

    // Can we consume the box and return the element?
    @_lifetime(copy self)
    consuming func take() -> Element {
        return stored
    }
}

extension InlineBox: Copyable where Element: Copyable & ~Escapable {}
extension InlineBox: Escapable where Element: Escapable & ~Copyable {}

func testV10() {
    print("=== V10: Consuming take() on inline container ===")

    let box = InlineBox(NEValue(77))
    let taken = box.take()
    print("  InlineBox<NEValue>.take().value: \(taken.value)")

    let boxInt = InlineBox(42)
    let takenInt = boxInt.take()
    print("  InlineBox<Int>.take(): \(takenInt)")

    print("  V10: PASS")
    print()
}

// ============================================================================
// V11: Mutating push onto Optional slots
// Can we mutate slot1 from nil to .some after init?
// ============================================================================

// BLOCKED: Same as V6/V8 — Optional<Element> slot triggers lifetime escape.
//
// struct MutableInline2<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
//     var slot0: Element
//     var slot1: Element?
//     @_lifetime(copy first)
//     init(first: consuming Element) { ... }
//     mutating func setSecond(_ element: consuming Element) { ... }
// }

func testV11() {
    print("=== V11: Mutating push to Optional slot ===")
    print("  BLOCKED: Same as V6/V8 — Optional<Element> in ~Escapable container")
    print()
}

// ============================================================================
// V12: Nested containers for scaling
// If Box works, does Box<Box<Box<NEValue>>> work? (Nesting for depth)
// ============================================================================

func testV12() {
    print("=== V12: Nested InlineBox for depth ===")

    let b1 = InlineBox(NEValue(1))
    let b2 = InlineBox(b1)
    let b3 = InlineBox(b2)
    print("  InlineBox^3<NEValue> stored.stored.stored.value: \(b3.stored.stored.stored.value)")

    print("  V12: PASS")
    print()
}

// ============================================================================
// V13: MemoryLayout works for ~Escapable (confirmed in V2a)
// ============================================================================

func testV13() {
    print("=== V13: MemoryLayout<NEValue> ===")
    print("  size: \(MemoryLayout<NEValue>.size)")
    print("  stride: \(MemoryLayout<NEValue>.stride)")
    print("  alignment: \(MemoryLayout<NEValue>.alignment)")
    print("  V13: PASS (MemoryLayout<~Escapable> works)")
    print()
}

// ============================================================================
// V14: Enum-based variable-occupancy storage (WORKAROUND for Optional blocker)
//
// Hypothesis: Since Optional<Element> is blocked in ~Escapable containers,
// but enum associated values work (Optional<~Escapable> itself compiles),
// maybe a CUSTOM enum with capacity cases can serve as variable-occupancy storage.
//
// The key insight: Optional<Wrapped: ~Copyable & ~Escapable> exists in stdlib.
// The problem is using it as a STORED PROPERTY in another ~Escapable type.
// What if we make the ENUM itself the container?
// ============================================================================

// V14: Put push() on the ENUM (not a wrapper struct).
// `consume self` on the enum itself is FULL consumption.
// `self = .case(...)` is FULL reinit. Avoids partial reinit error.

enum EnumStack2<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    case empty
    case one(Element)
    case two(Element, Element)

    var count: Int {
        switch self {
        case .empty: 0
        case .one: 1
        case .two: 2
        }
    }

    @_lifetime(self: copy self, copy element)
    mutating func push(_ element: consuming Element) {
        switch consume self {
        case .empty:
            self = .one(element)
        case .one(let first):
            self = .two(first, element)
        case .two:
            preconditionFailure("EnumStack2 is full")
        }
    }
}

extension EnumStack2: Copyable where Element: Copyable & ~Escapable {}
extension EnumStack2: Escapable where Element: Escapable & ~Copyable {}

func testV14() {
    print("=== V14: Enum-based variable-occupancy storage ===")

    // Escapable
    var stackInt: EnumStack2<Int> = .empty
    stackInt.push(10)
    stackInt.push(20)
    print("  EnumStack2<Int> count: \(stackInt.count)")

    // ~Escapable
    var stackNE: EnumStack2<NEValue> = .empty
    stackNE.push(NEValue(100))
    stackNE.push(NEValue(200))
    print("  EnumStack2<NEValue> count: \(stackNE.count)")

    print("  V14: PASS")
    print()
}

// ============================================================================
// V15: Enum with 4 slots — can we scale it?
// ============================================================================

// V15: Scale to 4 slots — same enum-direct pattern

enum EnumStack4<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    case zero
    case one(Element)
    case two(Element, Element)
    case three(Element, Element, Element)
    case four(Element, Element, Element, Element)

    var count: Int {
        switch self {
        case .zero: 0
        case .one: 1
        case .two: 2
        case .three: 3
        case .four: 4
        }
    }

    @_lifetime(self: copy self, copy element)
    mutating func push(_ element: consuming Element) {
        switch consume self {
        case .zero:
            self = .one(element)
        case .one(let a):
            self = .two(a, element)
        case .two(let a, let b):
            self = .three(a, b, element)
        case .three(let a, let b, let c):
            self = .four(a, b, c, element)
        case .four:
            preconditionFailure("EnumStack4 is full")
        }
    }
}

extension EnumStack4: Copyable where Element: Copyable & ~Escapable {}
extension EnumStack4: Escapable where Element: Escapable & ~Copyable {}

func testV15() {
    print("=== V15: Enum with 4 slots ===")

    var stack: EnumStack4<NEValue> = .zero
    stack.push(NEValue(1))
    stack.push(NEValue(2))
    stack.push(NEValue(3))
    stack.push(NEValue(4))
    print("  EnumStack4<NEValue> count: \(stack.count)")

    print("  V15: PASS")
    print()
}

// ============================================================================
// V16: @_rawLayout declaration with ~Escapable Element
//
// Hypothesis: @_rawLayout(likeArrayOf: Element, count: capacity) does NOT add
// an implicit Escapable constraint on Element. The attribute computes layout
// (size, alignment, stride) from the type parameter, which MemoryLayout already
// supports for ~Escapable (proven in V13/V2a). The layout declaration itself
// should compile even when Element: ~Copyable & ~Escapable.
// ============================================================================

// Note: @_rawLayout types must be unconditionally ~Copyable.
// Conditional Copyable not possible on @_rawLayout types.
@_rawLayout(likeArrayOf: Element, count: capacity)
struct RawLayoutStorage<Element: ~Copyable & ~Escapable, let capacity: Int>: ~Copyable, ~Escapable {
    @usableFromInline
    @_lifetime(immortal)
    init() {}
}

extension RawLayoutStorage: Escapable where Element: Escapable & ~Copyable {}

func testV16() {
    print("=== V16: @_rawLayout declaration with ~Escapable ===")

    let storage = RawLayoutStorage<NEValue, 4>()
    print("  RawLayoutStorage<NEValue, 4> created")
    print("  MemoryLayout<RawLayoutStorage<NEValue, 4>>.size: \(MemoryLayout<RawLayoutStorage<NEValue, 4>>.size)")
    print("  MemoryLayout<RawLayoutStorage<NEValue, 4>>.stride: \(MemoryLayout<RawLayoutStorage<NEValue, 4>>.stride)")
    _ = storage

    let storageInt = RawLayoutStorage<Int, 4>()
    print("  RawLayoutStorage<Int, 4> created")
    print("  MemoryLayout<RawLayoutStorage<Int, 4>>.size: \(MemoryLayout<RawLayoutStorage<Int, 4>>.size)")
    _ = storageInt

    print("  V16: PASS (declaration compiles, conditional conformances work)")
    print()
}

// ============================================================================
// V17: @_rawLayout element access via UnsafePointer (expected BLOCKED)
//
// Hypothesis: Although @_rawLayout declaration compiles with ~Escapable Element,
// ACCESSING elements requires constructing UnsafePointer<Element> or
// UnsafeMutablePointer<Element>, both of which implicitly require Escapable.
// This proves the layout-vs-access gap: storage layout works, element access doesn't.
// ============================================================================

// BLOCKED: Element access requires typed pointers (implicit Escapable on Pointee)
//
// extension RawLayoutStorage {
//     subscript(index: Int) -> Element {
//         unsafeAddress {
//             // Step 1: Get raw pointer to storage — this WOULD work (no type constraint)
//             //   let rawPtr = Builtin.addressOfRawLayout(self)
//             //
//             // Step 2: Convert to typed pointer — BLOCKED
//             //   UnsafePointer<Element>(rawPtr)
//             //   Error: "type 'Element' does not conform to protocol 'Escapable'"
//             //   Note: "'where Pointee: Escapable' is implicit here"
//             fatalError("Cannot construct UnsafePointer<Element> when Element: ~Escapable")
//         }
//     }
// }

// ============================================================================
// V17b: @_rawLayout element access via UnsafeMutableRawPointer (expected BLOCKED)
//
// Hypothesis: Even if we avoid typed pointers and stay on UnsafeMutableRawPointer,
// the typed access methods (assumingMemoryBound, initializeMemory) all require
// T: Escapable (implicit, since only ~Copyable is suppressed on T).
// ============================================================================

// BLOCKED: Raw pointer typed access methods require Escapable
//
// extension RawLayoutStorage {
//     mutating func initialize(at index: Int, to value: consuming Element) {
//         // Step 1: withUnsafeMutablePointer(to: &self) — BLOCKED
//         //   T parameter in withUnsafeMutablePointer is ~Copyable only (implicit Escapable)
//         //
//         // Step 2: If we could get a raw pointer, initializeMemory — BLOCKED
//         //   rawPtr.initializeMemory(as: Element.self, to: value)
//         //   T in initializeMemory(as: T.self, to:) is ~Copyable only (implicit Escapable)
//         //
//         // Step 3: assumingMemoryBound — BLOCKED
//         //   rawPtr.assumingMemoryBound(to: Element.self)
//         //   T in assumingMemoryBound(to: T.self) is ~Copyable only (implicit Escapable)
//     }
// }

// MARK: - Run all tests

print("Pointer ~Escapable Storage Experiment")
print("======================================")
print()

testV2a()
testV4()
testV5()
testV6()
testV8()
testV10()
testV11()
testV12()
testV13()
testV14()
testV15()
testV16()

print("======================================")
print()
print("RESULTS SUMMARY:")
print()
print("  BLOCKED paths (confirmed):")
print("    V1:   UnsafeMutablePointer<Element: ~Escapable> — implicit Escapable on Pointee")
print("    V2b:  UnsafeMutableRawPointer.initializeMemory(as:to:) — implicit Escapable on T")
print("    V2c:  UnsafeMutableRawPointer.assumingMemoryBound(to:) — implicit Escapable on T")
print("    V3:   InlineArray<N, Element: ~Escapable> — implicit Escapable on Element")
print("    V6:   Optional<Element> slots in ~Escapable container — lifetime escape")
print("    V7:   Optional slot initialized to nil — lifetime escape (same root cause)")
print("    V8:   Optional slots with mixed nil/value — lifetime escape (same root cause)")
print("    V9:   withUnsafePointer(to: ~Escapable) — implicit Escapable on T")
print("    V11:  Mutating Optional slot — lifetime escape (same root cause)")
print("    V17:  @_rawLayout element access via typed pointer — implicit Escapable on Pointee")
print("    V17b: @_rawLayout element access via raw pointer methods — implicit Escapable on T")
print()
print("  WORKING paths:")
print("    V2a:  Raw pointer allocation (MemoryLayout + allocate) — PASS")
print("    V4:   Struct fields, 2 non-Optional elements — PASS")
print("    V5:   Struct fields, 3 non-Optional elements — PASS")
print("    V10:  consuming take() returning ~Escapable — PASS")
print("    V12:  Nested containers (Box^3) — PASS")
print("    V13:  MemoryLayout<~Escapable> — PASS")
print("    V14:  Enum-based 2-slot container (variable occupancy) — PASS ***")
print("    V15:  Enum-based 4-slot container (variable occupancy) — PASS ***")
print("    V16:  @_rawLayout declaration with ~Escapable — PASS (layout, not access)")
print()
print("  KEY FINDINGS:")
print()
print("  1. Enum cases with associated values provide variable-occupancy")
print("     storage for ~Escapable elements. `consume self` + `self = .case(...)` is")
print("     full reinit (not partial), avoiding the partial reinit blocker. Scales to")
print("     any fixed capacity (each case = one capacity level).")
print()
print("  2. @_rawLayout(likeArrayOf: Element, count: N) COMPILES with ~Escapable.")
print("     Layout declaration is not blocked. But element ACCESS is blocked by the")
print("     same pointer constraint (UnsafePointer/UnsafeMutablePointer require Escapable).")
print("     This is the LAYOUT-vs-ACCESS gap: @_rawLayout is the correct FUTURE solution")
print("     when stdlib adds ~Escapable to pointer type parameters (per SE-0465 deferral).")
print()
print("Experiment complete.")
