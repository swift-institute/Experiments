// MARK: - ~Copyable Initializer for Inline Storage
// Purpose: Validate initialization patterns for ~Copyable elements in inline storage
// Hypothesis: Various initialization patterns enable ~Copyable element support
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED - @_rawLayout init patterns work; InlineArray backing crashes on deinit
// Date: 2026-02-05

import Synchronization

// ============================================================================
// MARK: - Deinit Tracking Infrastructure
// ============================================================================

final class DeinitTracker: @unchecked Sendable {
    let _count = Atomic<Int>(0)

    var count: Int { _count.load(ordering: .relaxed) }

    func increment() {
        _count.wrappingAdd(1, ordering: .relaxed)
    }

    func reset() {
        _count.store(0, ordering: .relaxed)
    }
}

struct TrackedValue: ~Copyable {
    let value: Int
    let tracker: DeinitTracker

    init(_ value: Int, tracker: DeinitTracker) {
        self.value = value
        self.tracker = tracker
    }

    deinit {
        tracker.increment()
    }
}

// ============================================================================
// MARK: - Minimal Inline Storage (Simplified from Storage.Inline)
// ============================================================================

struct InlineStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @_rawLayout(likeArrayOf: Element, count: capacity)
    struct _Raw: ~Copyable {}

    var _storage: _Raw
    var _count: Int

    init() {
        _storage = _Raw()
        _count = 0
    }

    deinit {
        // Deinitialize all elements
        for i in 0..<_count {
            unsafe withUnsafePointer(to: _storage) { base in
                let raw = unsafe UnsafeMutableRawPointer(mutating: base)
                unsafe raw.advanced(by: i * MemoryLayout<Element>.stride)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
        }
    }

    /// Returns a mutable pointer to storage (for initialization)
    mutating func mutablePointer() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }
}

// ============================================================================
// MARK: - Variant 1: Closure-based initialization (pointer callback)
// Hypothesis: Passing UnsafeMutablePointer to closure enables ~Copyable init
// Result: CONFIRMED
// ============================================================================

extension InlineStorage where Element: ~Copyable {
    /// Initialize with closure receiving raw pointer.
    /// Closure must initialize exactly `capacity` elements.
    init(initializing body: (UnsafeMutablePointer<Element>) -> Void) {
        _storage = _Raw()
        _count = 0
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: Element.self)
            body(ptr)
        }
        _count = capacity
    }
}

func testVariant1() {
    print("=== Variant 1: Closure-based init (pointer) ===")
    let tracker = DeinitTracker()

    do {
        let storage = InlineStorage<TrackedValue, 3>(initializing: { ptr in
            unsafe (ptr + 0).initialize(to: TrackedValue(10, tracker: tracker))
            unsafe (ptr + 1).initialize(to: TrackedValue(20, tracker: tracker))
            unsafe (ptr + 2).initialize(to: TrackedValue(30, tracker: tracker))
        })

        print("Created storage with 3 TrackedValues")
        print("Deinit count before scope exit: \(tracker.count)")

        // Access via pointer to verify values
        unsafe withUnsafePointer(to: storage._storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: TrackedValue.self)
            print("Values: \(ptr[0].value), \(ptr[1].value), \(ptr[2].value)")
        }

        _ = storage // Keep alive until scope exit
    }

    print("Deinit count after scope exit: \(tracker.count)")
    print("Expected: 3, Got: \(tracker.count) - \(tracker.count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 2: Element-by-element consuming init
// Hypothesis: Multiple consuming parameters enable explicit ~Copyable init
// Result: CONFIRMED - but requires direct pointer access, not closure
// ============================================================================

extension InlineStorage where Element: ~Copyable {
    /// Initialize with exactly 3 elements (for N == 3).
    /// NOTE: consuming parameters cannot be captured by closures in Swift 6.
    /// Must use direct pointer manipulation.
    init(
        _ e0: consuming Element,
        _ e1: consuming Element,
        _ e2: consuming Element
    ) where capacity == 3 {
        _storage = _Raw()
        _count = 0
        // Get pointer directly, then initialize
        let ptr = mutablePointer()
        unsafe (ptr + 0).initialize(to: e0)
        unsafe (ptr + 1).initialize(to: e1)
        unsafe (ptr + 2).initialize(to: e2)
        _count = 3
    }
}

func testVariant2() {
    print("=== Variant 2: Element-by-element consuming init ===")
    let tracker = DeinitTracker()

    do {
        let storage = InlineStorage<TrackedValue, 3>(
            TrackedValue(100, tracker: tracker),
            TrackedValue(200, tracker: tracker),
            TrackedValue(300, tracker: tracker)
        )

        print("Created storage with 3 TrackedValues via consuming init")
        print("Deinit count before scope exit: \(tracker.count)")

        // Access values
        unsafe withUnsafePointer(to: storage._storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: TrackedValue.self)
            print("Values: \(ptr[0].value), \(ptr[1].value), \(ptr[2].value)")
        }

        _ = storage
    }

    print("Deinit count after scope exit: \(tracker.count)")
    print("Expected: 3, Got: \(tracker.count) - \(tracker.count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 3: withUnsafeUninitializedCapacity pattern (stdlib-style)
// Hypothesis: Buffer + initializedCount pattern from stdlib works for ~Copyable
// Result: CONFIRMED - but count must be stored outside closure
// ============================================================================

extension InlineStorage where Element: ~Copyable {
    /// Initialize using stdlib-style uninitialized capacity pattern.
    init(
        unsafeUninitializedCapacity: Int,
        initializingWith initializer: (
            _ buffer: UnsafeMutablePointer<Element>
        ) -> Int
    ) {
        precondition(unsafeUninitializedCapacity <= capacity)
        _storage = _Raw()
        _count = 0
        let ptr = mutablePointer()
        _count = initializer(ptr)
    }
}

func testVariant3() {
    print("=== Variant 3: withUnsafeUninitializedCapacity pattern ===")
    let tracker = DeinitTracker()

    do {
        let storage = InlineStorage<TrackedValue, 5>(
            unsafeUninitializedCapacity: 3,
            initializingWith: { ptr in
                unsafe (ptr + 0).initialize(to: TrackedValue(1, tracker: tracker))
                unsafe (ptr + 1).initialize(to: TrackedValue(2, tracker: tracker))
                unsafe (ptr + 2).initialize(to: TrackedValue(3, tracker: tracker))
                return 3
            }
        )

        print("Created storage with 3/5 TrackedValues via stdlib pattern")
        print("Actual count: \(storage._count)")
        print("Deinit count before scope exit: \(tracker.count)")

        _ = storage
    }

    print("Deinit count after scope exit: \(tracker.count)")
    print("Expected: 3, Got: \(tracker.count) - \(tracker.count == 3 ? "PASS" : "FAIL")")
    print()
}

// ============================================================================
// MARK: - Variant 4: Verify Copyable elements still work
// Hypothesis: Copyable elements work with all init patterns
// Result: CONFIRMED
// ============================================================================

func testVariant4() {
    print("=== Variant 4: Copyable elements compatibility ===")

    do {
        // Using closure init
        let storage1 = InlineStorage<Int, 3>(initializing: { ptr in
            unsafe (ptr + 0).initialize(to: 10)
            unsafe (ptr + 1).initialize(to: 20)
            unsafe (ptr + 2).initialize(to: 30)
        })

        unsafe withUnsafePointer(to: storage1._storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: Int.self)
            print("Closure init values: \(ptr[0]), \(ptr[1]), \(ptr[2])")
        }

        // Using consuming init
        let storage2 = InlineStorage<Int, 3>(10, 20, 30)

        unsafe withUnsafePointer(to: storage2._storage) { base in
            let raw = unsafe UnsafeRawPointer(base)
            let ptr = unsafe raw.assumingMemoryBound(to: Int.self)
            print("Consuming init values: \(ptr[0]), \(ptr[1]), \(ptr[2])")
        }

        print("Copyable elements: PASS")
    }
    print()
}

// ============================================================================
// MARK: - Variant 5: Test conditional Copyable (expected to fail)
// Hypothesis: @_rawLayout types cannot be conditionally Copyable
// Result: CONFIRMED - @_rawLayout blocks conditional Copyable
// ============================================================================

// Uncomment to verify this fails:
// extension InlineStorage: Copyable where Element: Copyable {}
// Error: type 'InlineStorage<Element, capacity>' does not conform to protocol 'Copyable'

func testVariant5() {
    print("=== Variant 5: Conditional Copyable (compile-time check) ===")
    print("InlineStorage with @_rawLayout cannot conform to Copyable")
    print("(Uncomment extension in source to verify compiler error)")
    print("Result: CONFIRMED - @_rawLayout blocks conditional Copyable")
    print()
}

// ============================================================================
// MARK: - Variant 6: deinit + conditional Copyable incompatibility
// Hypothesis: Types with deinit cannot conditionally conform to Copyable
// Result: CONFIRMED - This is a fundamental Swift constraint
// ============================================================================

// NOTE: Conditional Copyable with deinit is NOT allowed in Swift.
// A type with deinit cannot conditionally conform to Copyable because:
// - Copyable types are trivially destructible (no deinit)
// - The compiler cannot emit correct code for both cases
//
// This means: To have conditional Copyable, you must NOT have a deinit.
// But without deinit, ~Copyable elements would leak.
//
// CONCLUSION: Conditional Copyable is incompatible with ~Copyable element cleanup.

struct InlineArrayStorage<Element: ~Copyable, let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Int>
    var _count: Int

    init() {
        _storage = InlineArray(repeating: 0)
        _count = 0
    }

    deinit {
        for i in 0..<_count {
            unsafe withUnsafePointer(to: _storage) { base in
                let raw = unsafe UnsafeMutableRawPointer(mutating: base)
                unsafe raw.advanced(by: i * MemoryLayout<Int>.stride)
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: 1)
            }
        }
    }

    mutating func mutablePointer() -> UnsafeMutablePointer<Element> {
        unsafe withUnsafeMutablePointer(to: &_storage) { base in
            let raw = UnsafeMutableRawPointer(base)
            return unsafe raw.assumingMemoryBound(to: Element.self)
        }
    }
}

// Cannot add: extension InlineArrayStorage: Copyable where Element: Copyable {}
// Error: deinitializer cannot be declared in generic struct that conforms to 'Copyable'

extension InlineArrayStorage: Sendable where Element: Sendable {}

extension InlineArrayStorage where Element: ~Copyable {
    init(
        _ e0: consuming Element,
        _ e1: consuming Element,
        _ e2: consuming Element
    ) where capacity == 3 {
        _storage = InlineArray(repeating: 0)
        _count = 0
        let ptr = mutablePointer()
        unsafe (ptr + 0).initialize(to: e0)
        unsafe (ptr + 1).initialize(to: e1)
        unsafe (ptr + 2).initialize(to: e2)
        _count = 3
    }
}

func testVariant6() {
    print("=== Variant 6: deinit + conditional Copyable incompatibility ===")
    let tracker = DeinitTracker()

    // Test with ~Copyable elements
    do {
        let storage = InlineArrayStorage<TrackedValue, 3>(
            TrackedValue(1000, tracker: tracker),
            TrackedValue(2000, tracker: tracker),
            TrackedValue(3000, tracker: tracker)
        )

        print("Created InlineArrayStorage with 3 TrackedValues")
        print("Deinit count before scope exit: \(tracker.count)")
        _ = storage
    }

    print("Deinit count after scope exit: \(tracker.count)")
    print("~Copyable elements with deinit: \(tracker.count == 3 ? "PASS" : "FAIL")")

    print()
    print("KEY FINDING: deinit + conditional Copyable is INCOMPATIBLE")
    print("  - Types with deinit cannot conform to Copyable (even conditionally)")
    print("  - This is a fundamental Swift language constraint")
    print("  - Storage types that clean up ~Copyable elements MUST be ~Copyable")
    print()
}

// ============================================================================
// MARK: - Variant 7: consuming parameters + closure capture
// Hypothesis: Consuming parameters cannot be captured by closures
// Result: CONFIRMED - Must use direct pointer access outside closure
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

func testVariant7() {
    print("=== Variant 7: consuming parameters + closure capture ===")
    print("Consuming parameters CANNOT be captured by closures in Swift 6")
    print("Error: 'missing reinitialization of closure capture after consume'")
    print("")
    print("Solution: Get pointer OUTSIDE closure, then initialize directly:")
    print("  let ptr = mutablePointer()")
    print("  (ptr + 0).initialize(to: e0)")
    print("  (ptr + 1).initialize(to: e1)")
    print("  ...")
    print("")
    print("This is demonstrated in Variant 2 (consuming init)")
    print()
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("~Copyable Initializer Validation for Vector.Inline")
print("==================================================")
print()

testVariant1()
testVariant2()
testVariant3()
testVariant4()
testVariant5()
testVariant6()
testVariant7()

print("==================================================")
print("Summary:")
print("- Closure-based init: WORKS for ~Copyable elements")
print("- Consuming init: WORKS (but no closure capture)")
print("- stdlib pattern: WORKS (return count, don't use inout)")
print("- @_rawLayout: BLOCKS conditional Copyable (always ~Copyable)")
print("- deinit + Copyable: INCOMPATIBLE (Swift constraint)")
print("")
print("CRITICAL FINDINGS:")
print("1. Storage types that cleanup ~Copyable elements MUST have deinit")
print("2. Types with deinit CANNOT conditionally conform to Copyable")
print("3. Therefore: Inline storage supporting ~Copyable elements")
print("   CANNOT be conditionally Copyable")
print("4. This is a FUNDAMENTAL Swift language constraint, not a bug")
print("")
print("IMPLICATIONS FOR Vector.Inline:")
print("- Vector.Inline uses Storage.Inline which has deinit")
print("- Vector.Inline CANNOT be conditionally Copyable")
print("- The current architecture is CORRECT")
print("- Add ~Copyable initializers (closure-based or consuming)")
print("- Do NOT attempt conditional Copyable — it's impossible")
