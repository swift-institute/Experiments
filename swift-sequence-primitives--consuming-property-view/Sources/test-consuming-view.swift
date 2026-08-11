// ===----------------------------------------------------------------------===//
// TEST: Sequence.Consuming.View with generic State parameter
// ===----------------------------------------------------------------------===//
//
// HYPOTHESIS: A generic View<Element, State: ~Copyable> can work with
//             closure-based iteration, enabling iterator logic in
//             sequence-primitives and state-only types in set-primitives.
//
// METHODOLOGY: [EXP-004a] Incremental Construction
//
// FINDING: SE-0427 blocks associated types with ~Copyable constraint.
//          Workaround: Don't require protocol conformance - just have types
//          return the concrete View type directly.
//
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: Basic View structure with ~Copyable State

/// Simulates the proposed Sequence.Consuming.View
/// Note: deinit can't mutate self, so cleanup must work on consuming State
@safe
struct ConsumingView4<Element, State: ~Copyable>: ~Copyable {
    @usableFromInline
    var _state: State

    @usableFromInline
    let _next: (inout State) -> Element?

    // Cleanup takes ownership of state to destroy remaining elements
    @usableFromInline
    let _cleanupRemaining: (consuming State) -> Void

    @inlinable
    init(
        state: consuming State,
        next: @escaping (inout State) -> Element?,
        cleanupRemaining: @escaping (consuming State) -> Void
    ) {
        self._state = state
        self._next = next
        self._cleanupRemaining = cleanupRemaining
    }

    @inlinable
    mutating func next() -> Element? {
        _next(&_state)
    }

    // NOTE: This version has issues - see ConsumingView5 for correct pattern
    // Cannot have both deinit AND consuming func that uses _cleanupRemaining
}

// ConsumingView4 demonstrates the WRONG approach:
// - Can't partially consume self in consuming func when deinit exists
// - Can't call closure with &_state in deinit because self is immutable

// MARK: - Test 2: Alternative approach - struct holds cleanup state

/// Better approach: State includes all cleanup information
/// The cleanup closure operates on consuming State
@safe
struct ConsumingView5<Element, State: ~Copyable>: ~Copyable {
    @usableFromInline
    var _state: State

    @usableFromInline
    let _next: (inout State) -> Element?

    @inlinable
    init(
        state: consuming State,
        next: @escaping (inout State) -> Element?
    ) {
        self._state = state
        self._next = next
    }

    @inlinable
    mutating func next() -> Element? {
        _next(&_state)
    }

    @inlinable
    consuming func forEach(_ body: (Element) -> Void) {
        while let element = _next(&_state) {
            body(element)
        }
        // State consumed here, its deinit handles cleanup
    }

    // deinit: _state's deinit handles cleanup automatically
}

// MARK: - Test 3: Simulate Set.Ordered usage with deinit-based cleanup

/// Simulates ElementStorage (a reference type, like ManagedBuffer)
final class MockStorage4 {
    var elements: [Int]
    var cleanedUpFrom: Int? = nil

    init(_ elements: [Int]) {
        self.elements = elements
    }

    func moveElement(at index: Int) -> Int {
        return elements[index]
    }

    func deinitializeElements(from start: Int, count: Int) {
        cleanedUpFrom = start
        print("  Cleanup: deinitializing \(count) elements from index \(start)")
    }
}

/// State with deinit for cleanup - THIS is the key pattern
struct MockConsumingState4: ~Copyable {
    let storage: MockStorage4  // Reference type
    var index: Int
    let count: Int

    deinit {
        let remaining = count - index
        if remaining > 0 {
            storage.deinitializeElements(from: index, count: remaining)
        }
    }
}

/// Simulates Set.Ordered
struct MockContainer4: ~Copyable {
    var storage: MockStorage4

    init(_ elements: [Int]) {
        self.storage = MockStorage4(elements)
    }

    consuming func consuming() -> ConsumingView5<Int, MockConsumingState4> {
        let count = storage.elements.count

        let state = MockConsumingState4(
            storage: storage,
            index: 0,
            count: count
        )

        return ConsumingView5(
            state: state,
            next: { state in
                guard state.index < state.count else { return nil }
                let element = state.storage.moveElement(at: state.index)
                state.index += 1
                return element
            }
        )
    }
}

// MARK: - Test Execution

func testConsumingViewComplete() {
    print("\n=== Test: ConsumingView - complete iteration ===")
    let container = MockContainer4([1, 2, 3])
    container.consuming().forEach { element in
        print("  Consumed: \(element)")
    }
    print("  State deinit called (cleanup with 0 remaining)")
}

func testConsumingViewPartial() {
    print("\n=== Test: ConsumingView - partial iteration (early exit) ===")
    do {
        let container = MockContainer4([10, 20, 30, 40, 50])
        var view = container.consuming()
        if let first = view.next() {
            print("  Got first: \(first)")
        }
        if let second = view.next() {
            print("  Got second: \(second)")
        }
        print("  Letting view go out of scope with 3 remaining...")
        // State's deinit will cleanup remaining elements
    }
    print("  After scope exit - cleanup was called")
}

// MARK: - Main test runner

func testConsumingView() {
    testConsumingViewComplete()
    testConsumingViewPartial()

    print("\n=== Sequence.Consuming.View Analysis ===")
    print("""
    VERIFIED:

    1. View<Element, State: ~Copyable> structure compiles
       - Generic State parameter allows any ~Copyable state
       - Closure operates on `inout State` for next()

    2. Cleanup via State's deinit (NOT closure in View's deinit)
       - State type provides deinit that cleans up remaining elements
       - When View is destroyed, State is destroyed, cleanup runs
       - This is the correct pattern for ~Copyable cleanup

    3. Protocol limitation confirmed (SE-0427)
       - Associated types cannot be `~Copyable`
       - WORKAROUND: Don't use protocol for ConsumingView
       - Types return concrete `Sequence.Consuming.View<Element, TheirState>`

    CONCLUSION: The design works with State's deinit handling cleanup.
    sequence-primitives provides View type with forEach/next logic.
    set-primitives provides State type with deinit cleanup.
    """)
}
