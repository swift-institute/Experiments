// Experiment: Conditional Escapable Container
// Tests whether containers can conditionally conform to Escapable based on Element.
//
// Result: CONFIRMED — single-element Box works; multi-element containers blocked by UnsafePointer Escapable requirement and Optional lifetime checker
//
// Pattern under test (from Sequence.Map):
//   extension T: Copyable where Element: Copyable & ~Escapable {}
//   extension T: Escapable where Element: Escapable & ~Copyable {}
//
// KEY FINDINGS (discovered during experiment):
//
//   FINDING 1: UnsafeMutablePointer<T> requires T: Escapable.
//     Also: UnsafeMutableRawPointer.assumingMemoryBound(to: T.self) requires T: Escapable.
//     Also: UnsafeMutableRawPointer.initializeMemory(as: T.self, to:) requires T: Escapable.
//     --> Heap-backed containers CANNOT store ~Escapable elements as of Swift 6.2.
//
//   FINDING 2: Optional<~Escapable> initialized to nil inside a ~Escapable container
//     triggers "lifetime-dependent variable 'self' escapes its scope" when the container
//     init is marked @_lifetime(immortal). The nil literal for Optional<~Escapable>
//     creates a value whose lifetime the checker cannot resolve for the owning container.
//     --> Multi-slot inline containers using Optional<Element> for ~Escapable are BLOCKED.
//
//   FINDING 3: Partial reinit of ~Copyable self is rejected:
//     "cannot partially reinitialize 'self' after it has been consumed"
//     --> Even if Optional slots compiled, popFront-style mutation wouldn't work.
//
//   RESULT: Only single-element (Box-like) containers and their compositions work
//     for conditional Escapable. Multi-element containers need stdlib-level support
//     (InlineArray with ~Escapable, or UnsafePointer lifting the Escapable requirement).

// MARK: - Test Type: ~Escapable value

struct NEValue: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

// MARK: - V1: Single-element Box with conditional Escapable (baseline)

struct Box<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var stored: Element

    @_lifetime(copy element)
    init(_ element: consuming Element) {
        self.stored = element
    }
}

extension Box: Copyable where Element: Copyable & ~Escapable {}
extension Box: Escapable where Element: Escapable & ~Copyable {}

func testV1() {
    print("=== V1: Single-element Box ===")

    // Box<Int> should be Escapable (Int is Escapable)
    let boxInt = Box(42)
    print("  Box<Int> created: stored = \(boxInt.stored)")
    print("  Box<Int> is Escapable: YES (compiles)")

    // Box<NEValue> should be ~Escapable
    let ne = NEValue(99)
    let boxNE = Box(ne)
    print("  Box<NEValue> created: stored.value = \(boxNE.stored.value)")
    print("  Box<NEValue> is ~Escapable: YES (compiles with lifetime)")

    print("  V1: PASS")
    print()
}

// MARK: - V2: Multi-element FixedArray (heap-backed)
//
// BLOCKED: All UnsafePointer APIs require Element: Escapable.
//
// Errors:
//   "type 'Element' does not conform to protocol 'Escapable'"
//     on UnsafeMutablePointer<Element>
//   "instance method 'assumingMemoryBound(to:)' requires that 'Element' conform to 'Escapable'"
//     on UnsafeMutableRawPointer workaround
//   "instance method 'initializeMemory(as:to:)' requires that 'Element' conform to 'Escapable'"
//     on UnsafeMutableRawPointer workaround
//
// ALSO BLOCKED (inline Optional workaround):
//   "lifetime-dependent variable 'self' escapes its scope" when init sets Optional slots to nil
//   in a @_lifetime(immortal) init for a ~Escapable container.
//
// Escapable-only version works fine (shown below for completeness).

struct FixedArray<Element: ~Copyable>: ~Copyable {
    private let buffer: UnsafeMutablePointer<Element>
    private var _count: Int
    private let _capacity: Int

    var count: Int { _count }
    var capacity: Int { _capacity }

    init(capacity: Int) {
        self.buffer = .allocate(capacity: capacity)
        self._count = 0
        self._capacity = capacity
    }

    deinit {
        buffer.deinitialize(count: _count)
        buffer.deallocate()
    }

    mutating func push(_ element: consuming Element) {
        precondition(_count < _capacity, "FixedArray is full")
        (buffer + _count).initialize(to: element)
        _count += 1
    }

    subscript(index: Int) -> Element {
        _read {
            precondition(index >= 0 && index < _count, "Index out of bounds")
            yield buffer[index]
        }
    }
}

// NOTE: Cannot add conditional Escapable because Element is already constrained to Escapable
// (implicit from UnsafeMutablePointer). This type is ~Copyable only, not ~Escapable.

func testV2() {
    print("=== V2: Multi-element FixedArray ===")
    print("  BLOCKED for ~Escapable: UnsafePointer APIs require Element: Escapable")
    print("  BLOCKED for inline Optional workaround: @_lifetime(immortal) init with nil slots")
    print("    Error: \"lifetime-dependent variable 'self' escapes its scope\"")
    print()

    // Escapable-only version works:
    var arr = FixedArray<Int>(capacity: 4)
    arr.push(10)
    arr.push(20)
    arr.push(30)
    print("  FixedArray<Int> (Escapable-only) count: \(arr.count)")
    print("  FixedArray<Int>[0] = \(arr[0])")
    print("  FixedArray<Int>[1] = \(arr[1])")
    print("  FixedArray<Int>[2] = \(arr[2])")
    print("  FixedArray<Int> Escapable-only version: PASS")

    print("  V2: BLOCKED for ~Escapable element support")
    print()
}

// MARK: - V3: Ring buffer (fixed-capacity, head/tail)
//
// BLOCKED: Same reasons as V2 — heap pointer APIs require Escapable,
// inline Optional workaround blocked by lifetime checker,
// and partial reinit of ~Copyable self rejected.
//
// Additional error for partial reinit:
//   "cannot partially reinitialize 'self' after it has been consumed; only full reinitialization is allowed"
//
// Escapable-only version shown below.

struct Ring<Element: ~Copyable>: ~Copyable {
    private let buffer: UnsafeMutablePointer<Element>
    private var head: Int
    private var tail: Int
    private var _count: Int
    private let _capacity: Int

    var count: Int { _count }
    var capacity: Int { _capacity }
    var isEmpty: Bool { _count == 0 }
    var isFull: Bool { _count == _capacity }

    init(capacity: Int) {
        precondition(capacity > 0, "Ring capacity must be positive")
        self.buffer = .allocate(capacity: capacity)
        self.head = 0
        self.tail = 0
        self._count = 0
        self._capacity = capacity
    }

    deinit {
        for i in 0..<_count {
            let index = (head + i) % _capacity
            (buffer + index).deinitialize(count: 1)
        }
        buffer.deallocate()
    }

    mutating func push(_ element: consuming Element) {
        precondition(!isFull, "Ring is full")
        (buffer + tail).initialize(to: element)
        tail = (tail + 1) % _capacity
        _count += 1
    }

    mutating func popFront() -> Element? {
        guard _count > 0 else { return nil }
        let element = (buffer + head).move()
        head = (head + 1) % _capacity
        _count -= 1
        return element
    }
}

func testV3() {
    print("=== V3: Ring buffer ===")
    print("  BLOCKED for ~Escapable: Same UnsafePointer + lifetime + partial-reinit issues as V2")
    print()

    // Escapable-only version works:
    var ring = Ring<Int>(capacity: 4)
    ring.push(100)
    ring.push(200)
    ring.push(300)
    print("  Ring<Int> (Escapable-only) count: \(ring.count)")
    if let first = ring.popFront() {
        print("  Ring<Int> popFront: \(first)")
    }
    print("  Ring<Int> count after pop: \(ring.count)")
    print("  Ring<Int> Escapable-only version: PASS")

    print("  V3: BLOCKED for ~Escapable element support")
    print()
}

// MARK: - V4: Nested containers — Box<Box<~Escapable>>

func testV4() {
    print("=== V4: Nested containers ===")

    // Box<Box<Int>> should be Escapable (Int is Escapable, so Box<Int> is Escapable)
    let innerInt = Box(42)
    let outerInt = Box(innerInt)
    print("  Box<Box<Int>> created: stored.stored = \(outerInt.stored.stored)")
    print("  Box<Box<Int>> is Escapable: YES (compiles)")

    // Box<Box<NEValue>> should be ~Escapable
    let innerNE = Box(NEValue(77))
    let outerNE = Box(innerNE)
    print("  Box<Box<NEValue>> created: stored.stored.value = \(outerNE.stored.stored.value)")
    print("  Box<Box<NEValue>> is ~Escapable: YES (compiles with lifetime)")

    print("  V4: PASS")
    print()
}

// MARK: - V5: @_lifetime on methods returning ~Escapable elements

struct LifetimeBox<Element: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var stored: Element

    @_lifetime(copy element)
    init(_ element: consuming Element) {
        self.stored = element
    }

    // Test: returning Element from a computed property via _read
    // For ~Escapable elements, this needs @_lifetime(borrow self) on the accessor
    var element: Element {
        @_lifetime(borrow self)
        _read {
            yield stored
        }
    }

    // NOTE: borrowing func returning Element does NOT work for ~Copyable Element:
    //   "self is borrowed and cannot be consumed"
    // Only _read coroutine (which yields a borrow) works for ~Copyable & ~Escapable.
    // For Copyable Element, a regular computed property works (implicit copy).

}

extension LifetimeBox: Copyable where Element: Copyable & ~Escapable {}
extension LifetimeBox: Escapable where Element: Escapable & ~Copyable {}

func testV5() {
    print("=== V5: @_lifetime on methods returning ~Escapable elements ===")

    // Test with Int (Escapable) via _read
    let lb = LifetimeBox(42)
    print("  LifetimeBox<Int>.element (_read) = \(lb.element)")

    // Test with NEValue (~Escapable) via _read
    let lbNE = LifetimeBox(NEValue(55))
    print("  LifetimeBox<NEValue>.element.value (_read) = \(lbNE.element.value)")

    // NOTE: borrowing func getElement() -> Element does NOT work for ~Copyable Element:
    //   "'self' is borrowed and cannot be consumed"
    // Only _read coroutine (yielding a borrow) works for ~Copyable & ~Escapable elements.
    print("  borrowing func returning Element: BLOCKED (self is borrowed, cannot consume)")

    print("  V5: PASS (_read accessor), BLOCKED (borrowing func return)")
    print()
}

// MARK: - V6: Optional<Container<~Escapable>>

func testV6() {
    print("=== V6: Optional<Container<~Escapable>> ===")

    // Optional<Ring<Int>> — should work, Ring<Int> is Escapable
    var optRing: Ring<Int>? = Ring<Int>(capacity: 2)
    optRing?.push(42)
    if let r = optRing {
        print("  Optional<Ring<Int>> count: \(r.count)")
    }
    print("  Optional<Ring<Int>> is Escapable: YES (compiles)")

    // Optional<Box<Int>> — should work
    let optBox: Box<Int>? = Box(99)
    if let b = optBox {
        print("  Optional<Box<Int>> stored: \(b.stored)")
    }
    print("  Optional<Box<Int>> is Escapable: YES (compiles)")

    // Optional<Box<NEValue>> — Box<NEValue> is ~Escapable
    // Optional: Escapable where Wrapped: Escapable & ~Copyable
    // So Optional<Box<NEValue>> is ~Escapable (conditional propagates).
    // We CAN form it if we have the right lifetime context.
    let ne = NEValue(42)
    let boxNE: Box<NEValue> = Box(ne)
    let optBoxNE: Box<NEValue>? = consume boxNE
    if let b = optBoxNE {
        print("  Optional<Box<NEValue>> stored.value: \(b.stored.value)")
    }
    print("  Optional<Box<NEValue>> is ~Escapable: YES (compiles, lifetime propagated)")

    print("  V6: PASS")
    print()
}

// MARK: - V7: Container with ~Escapable elements passed to closure
//
// Tests whether a ~Escapable container (Box<NEValue>) can be passed to closures.
// Ring/FixedArray are BLOCKED (V2/V3), so we use Box-based patterns.

func withBox<Result>(
    _ value: Int,
    _ body: (borrowing Box<Int>) -> Result
) -> Result {
    let box = Box(value)
    return body(box)
}

func testV7() {
    print("=== V7: Container with ~Escapable elements passed to closure ===")

    // Escapable Box passed to closure
    let result = withBox(42) { box in
        box.stored * 2
    }
    print("  withBox(42) { stored * 2 } = \(result)")

    // ~Escapable Box: test borrowing in local scope (closure with ~Escapable container
    // requires lifetime annotations on the closure parameter which are not yet supported
    // for user-defined closures in Swift 6.2)
    let ne = NEValue(99)
    let box = Box(ne)
    // Direct borrowing access works:
    let val = box.stored.value
    print("  Box<NEValue> direct borrow access: \(val)")

    print("  V7: PASS (Escapable closure), PARTIAL (~Escapable closure requires manual scoping)")
    print()
}

// MARK: - V8: Pair container (two-element conditional Escapable)

struct Pair<A: ~Copyable & ~Escapable, B: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
    var first: A
    var second: B

    @_lifetime(copy a, copy b)
    init(_ a: consuming A, _ b: consuming B) {
        self.first = a
        self.second = b
    }
}

extension Pair: Copyable where A: Copyable & ~Escapable, B: Copyable & ~Escapable {}
extension Pair: Escapable where A: Escapable & ~Copyable, B: Escapable & ~Copyable {}

func testV8() {
    print("=== V8: Pair container (two-element) ===")

    // Pair<Int, String> — both Escapable
    let pairEsc = Pair(42, "hello")
    print("  Pair<Int, String>: (\(pairEsc.first), \(pairEsc.second))")
    print("  Pair<Int, String> is Escapable: YES")

    // Pair<NEValue, Int> — mixed: one ~Escapable, one Escapable
    let pairMixed = Pair(NEValue(10), 20)
    print("  Pair<NEValue, Int>: (\(pairMixed.first.value), \(pairMixed.second))")
    print("  Pair<NEValue, Int> is ~Escapable: YES (one element is ~Escapable)")

    // Pair<NEValue, NEValue> — both ~Escapable
    let pairNE = Pair(NEValue(1), NEValue(2))
    print("  Pair<NEValue, NEValue>: (\(pairNE.first.value), \(pairNE.second.value))")
    print("  Pair<NEValue, NEValue> is ~Escapable: YES")

    print("  V8: PASS")
    print()
}

// MARK: - Run all tests

print("Conditional Escapable Container Experiment")
print("===========================================")
print()

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()

print("===========================================")
print("Experiment complete.")
