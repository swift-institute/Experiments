// Status: SUPERSEDED -- Span/InlineArray patterns documented in swift-property-primitives Property.View. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Experiment: Why does InlineArray.span work but our pattern doesn't?
//
// Hypothesis: The issue is our use of `withUnsafePointer(to: elements)`
// which creates a closure scope that Span cannot escape from.
// InlineArray likely uses a different mechanism.

import Foundation

// MARK: - Test 1: InlineArray works (baseline)

func test1_inlineArrayWorks() {
    print("Test 1: InlineArray.span works")
    var arr: InlineArray<4, Int> = [1, 2, 3, 4]
    let s = arr.span
    print("  span[0] = \(s[0])")
    print("  ✅ InlineArray.span works as property")
}

// MARK: - Test 2: Our pattern - using withUnsafePointer

// This should fail to compile - let's see the exact error

struct MyInlineSet<Element: Equatable>: ~Copyable {
    var storage: InlineArray<8, Int> // Raw storage
    var count: Int

    init() {
        self.storage = InlineArray(repeating: 0)
        self.count = 0
    }

    // Pattern A: Using withUnsafePointer (OUR CURRENT PATTERN)
    // This should fail because Span can't escape the closure
//    public var spanViaWithUnsafePointer: Span<Int> {
//        @_lifetime(borrow self)
//        get {
//            withUnsafePointer(to: storage) { ptr in
//                let elementPtr = UnsafeRawPointer(ptr).assumingMemoryBound(to: Int.self)
//                return Span(_unsafeStart: elementPtr, count: count)
//            }
//        }
//    }

    // Pattern B: Get pointer via helper that returns UnsafePointer
    @unsafe
    func getStoragePointer() -> UnsafePointer<Int> {
        unsafe withUnsafePointer(to: storage) { ptr in
            let elementPtr = unsafe UnsafeRawPointer(ptr).assumingMemoryBound(to: Int.self)
            return unsafe elementPtr
        }
    }

    // Try using the helper - does this work?
//    public var spanViaHelper: Span<Int> {
//        @_lifetime(borrow self)
//        get {
//            let ptr = unsafe getStoragePointer()
//            return unsafe Span(_unsafeStart: ptr, count: count)
//        }
//    }
}

// MARK: - Test 3: What if we wrap InlineArray directly?

struct WrapperAroundInlineArray<Element>: ~Copyable {
    var underlying: InlineArray<8, Element>
    var usedCount: Int

    init(repeating element: Element) {
        self.underlying = InlineArray(repeating: element)
        self.usedCount = 0
    }
}

extension WrapperAroundInlineArray {
    // Can we just forward to underlying.span?
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            // Does this work? underlying.span should already have correct lifetime
            underlying.span
        }
    }
}

func test3_wrapperForwarding() {
    print("\nTest 3: Wrapper forwarding to InlineArray.span")
    var wrapper = WrapperAroundInlineArray(repeating: 42)
    let s = wrapper.span
    print("  span.count = \(s.count)")
    print("  ✅ Wrapper forwarding works!")
}

// MARK: - Test 4: Raw tuple storage (like Set.Ordered.Inline)
// COMMENTED OUT - this pattern fails because ptr is a local variable

//struct RawTupleStorage: ~Copyable {
//    var elements: (Int, Int, Int, Int, Int, Int, Int, Int)
//    var storedCount: Int
//    init() { ... }
//    func pointerToElements() -> UnsafePointer<Int> { ... }
//}
//extension RawTupleStorage {
//    public var span: Span<Int> {
//        @_lifetime(borrow self)
//        borrowing get {
//            let ptr = unsafe pointerToElements() // <-- ptr is local, Span depends on it
//            return unsafe Span(_unsafeStart: ptr, count: storedCount) // ERROR!
//        }
//    }
//}

func test4_rawTupleStorage() {
    print("\nTest 4: Raw tuple storage - SKIPPED (pattern doesn't work)")
    print("  ❌ Pattern fails: Span depends on local variable 'ptr'")
}

// MARK: - Test 5: Type-safe InlineArray storage (THE SOLUTION?)

struct TypeSafeInlineSet<Element, let capacity: Int>: ~Copyable {
    // Use InlineArray with correct Element type
    var storage: InlineArray<capacity, Element>
    var usedCount: Int

    init(repeating element: Element) {
        self.storage = InlineArray(repeating: element)
        self.usedCount = 0
    }
}

extension TypeSafeInlineSet {
    // Forward to storage.span - this should work!
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            storage.span
        }
    }

    // For mutableSpan we need the partial span
    public var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            storage.mutableSpan
        }
    }
}

func test5_typeSafeStorage() {
    print("\nTest 5: Type-safe InlineArray storage")
    var set = TypeSafeInlineSet<Int, 8>(repeating: 0)

    // Test span (read-only borrow)
    do {
        let s = set.span
        print("  span.count = \(s.count)")
    }

    // Test mutableSpan (exclusive mutable borrow)
    do {
        var ms = set.mutableSpan
        ms[0] = 42
    }

    print("  After mutation: storage[0] = \(set.storage[0])")
    print("  ✅ Type-safe InlineArray forwarding works!")
}

// MARK: - Test 6: Can we slice the span to usedCount?

extension TypeSafeInlineSet {
    // Get only the "used" portion via prefix
    public var usedSpan: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            // InlineArray.span gives us full capacity, but we only want usedCount
            // Can we slice it?
            storage.span
            // Note: Span slicing might not work the same way
        }
    }
}

func test6_spanSlicing() {
    print("\nTest 6: Can we access span.count subset?")
    var set = TypeSafeInlineSet<Int, 8>(repeating: 0)
    set.usedCount = 3  // Pretend we have 3 elements

    let fullSpan = set.span
    print("  Full span count: \(fullSpan.count)")

    // Access only first usedCount elements
    for i in 0..<set.usedCount {
        print("  span[\(i)] = \(fullSpan[i])")
    }
    print("  ✅ Manual iteration over subset works")
}

// MARK: - Test 7: InlineArray initialization options

func test7_inlineArrayInit() {
    print("\nTest 7: InlineArray initialization options")

    // Option 1: repeating (requires Copyable)
    let arr1: InlineArray<4, Int> = InlineArray(repeating: 0)
    print("  InlineArray(repeating:) works for Copyable: \(arr1.count)")

    // Option 2: Array literal
    let arr2: InlineArray<4, Int> = [1, 2, 3, 4]
    print("  Array literal works: \(arr2[0]), \(arr2[1])")

    // Option 3: Check if there's an unsafe uninitialized init
    // InlineArray might have internal mechanisms we can use

    print("  ✅ InlineArray has multiple init options")
}

// MARK: - Test 8: Can we have partially-valid InlineArray?

struct PartialInlineSet<Element, let capacity: Int>: ~Copyable {
    // The question: can we use InlineArray<capacity, Element> where
    // only the first `count` elements are valid?

    var storage: InlineArray<capacity, Element>
    var count: Int

    // For Copyable elements, we can use a "tombstone" value
    // But this doesn't work for ~Copyable

    // Alternative: use Optional wrapper
    // var storage: InlineArray<capacity, Element?>
    // But Optional<~Copyable> might have issues too
}

// For Copyable elements, we can test the partial pattern
extension PartialInlineSet where Element: Copyable {
    init(defaultValue: Element) {
        // Initialize all slots with default, but count = 0
        self.storage = InlineArray(repeating: defaultValue)
        self.count = 0
    }

    mutating func append(_ element: Element) {
        precondition(count < capacity)
        storage[count] = element
        count += 1
    }

    // Span that only covers valid elements - BUT this requires slicing
    var validSpan: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            // Full storage span - we want only first `count` elements
            // but Span slicing would require creating a new Span
            storage.span
        }
    }
}

func test8_partialInlineSet() {
    print("\nTest 8: Partial InlineArray pattern")

    var set = PartialInlineSet<Int, 8>(defaultValue: -1)
    set.append(10)
    set.append(20)
    set.append(30)

    print("  count = \(set.count)")
    print("  storage.count = \(set.storage.count)")

    let s = set.validSpan
    print("  validSpan.count = \(s.count) (full capacity, not count)")

    // Manual access to valid portion
    for i in 0..<set.count {
        print("  validSpan[\(i)] = \(s[i])")
    }

    print("  ⚠️ Span covers full capacity, not just valid elements")
}

// MARK: - Test 9: Can we create a properly-counted span?

func test9_spanPrefix() {
    print("\nTest 9: Span slicing/prefix")

    var arr: InlineArray<8, Int> = InlineArray(repeating: 0)
    arr[0] = 10
    arr[1] = 20
    arr[2] = 30
    let validCount = 3

    let fullSpan = arr.span
    print("  Full span count: \(fullSpan.count)")

    // Try extracting prefix - does Span support this?
    let prefixSpan = fullSpan.extracting(0..<validCount)
    print("  Prefix span count: \(prefixSpan.count)")
    print("  Prefix span[0]: \(prefixSpan[0])")
    print("  Prefix span[1]: \(prefixSpan[1])")
    print("  Prefix span[2]: \(prefixSpan[2])")
    print("  ✅ Span.extracting(Range) works for slicing!")
}

// MARK: - Test 10: Full redesign pattern

struct RedesignedInlineSet<Element, let capacity: Int>: ~Copyable where Element: Copyable {
    var storage: InlineArray<capacity, Element>
    var storedCount: Int

    init(defaultValue: Element) {
        self.storage = InlineArray(repeating: defaultValue)
        self.storedCount = 0
    }

    mutating func insert(_ element: Element) {
        precondition(storedCount < capacity)
        storage[storedCount] = element
        storedCount += 1
    }
}

extension RedesignedInlineSet {
    // Property-based span that returns only valid elements!
    var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get {
            storage.span.extracting(0..<storedCount)
        }
    }

    // mutableSpan has lifetime escape issues with extracting()
    // For now, provide full-capacity mutableSpan
    var mutableSpan: MutableSpan<Element> {
        @_lifetime(&self)
        mutating get {
            storage.mutableSpan
        }
    }

    // Closure-based for properly-scoped mutable access to valid elements
    @safe
    mutating func withMutableSpan<R>(_ body: (inout MutableSpan<Element>) -> R) -> R {
        // Capture count before taking mutable borrow of storage
        let count = storedCount
        var fullMs = unsafe storage.mutableSpan
        var ms = unsafe fullMs._mutatingExtracting(0..<count)
        return body(&ms)
    }
}

func test10_redesignedPattern() {
    print("\nTest 10: Redesigned pattern with span.extracting")

    var set = RedesignedInlineSet<Int, 8>(defaultValue: 0)
    set.insert(100)
    set.insert(200)
    set.insert(300)

    print("  storedCount = \(set.storedCount)")

    do {
        let s = set.span
        print("  span.count = \(s.count) (matches storedCount!)")
        for i in 0..<s.count {
            print("  span[\(i)] = \(s[i])")
        }
    }

    // Test mutation
    do {
        var ms = set.mutableSpan
        ms[0] = 999
    }

    print("  After mutation: storage[0] = \(set.storage[0])")
    print("  ✅ REDESIGNED PATTERN WORKS!")
}

// MARK: - Main

print("=== Inline Span Investigation ===\n")

test1_inlineArrayWorks()
test3_wrapperForwarding()
test4_rawTupleStorage()
test5_typeSafeStorage()
test6_spanSlicing()
test7_inlineArrayInit()
test8_partialInlineSet()
test9_spanPrefix()
test10_redesignedPattern()
test11_noncopyableInlineArray()
test12_partialInitNC()

// MARK: - Test 11: InlineArray with ~Copyable elements

struct NCElement: ~Copyable {
    var value: Int
    init(_ v: Int) { value = v }
}

func test11_noncopyableInlineArray() {
    print("\nTest 11: InlineArray with ~Copyable elements")

    // Array literal works for ~Copyable
    var arr: InlineArray<4, NCElement> = [NCElement(1), NCElement(2), NCElement(3), NCElement(4)]

    print("  Array literal: arr[0].value = \(arr[0].value)")

    // Can we get span?
    let s = arr.span
    print("  span.count = \(s.count)")
    print("  span[0].value = \(s[0].value)")

    print("  ✅ InlineArray<N, ~Copyable> works with array literal!")
}

// MARK: - Test 12: Partial initialization for ~Copyable

// The key question: can we have a Set with ~Copyable elements that starts empty?
// We need: 1) uninitialized storage, 2) insert elements one by one

// One approach: "tombstone" pattern - use a sentinel value
// But ~Copyable can't have a default sentinel

// Another approach: Track initialized indices separately
// struct NoncopyableInlineSet<Element: ~Copyable, let capacity: Int>: ~Copyable {
//     var storage: InlineArray<capacity, Element>  // Problem: how to init?
//     var count: Int
// }

// The issue: InlineArray requires ALL elements initialized.
// For ~Copyable, there's no way to create "placeholder" values.

// WORKAROUND: Use UnsafeMutableBufferPointer for ~Copyable inline sets
// This is essentially what the current raw byte storage does.

func test12_partialInitNC() {
    print("\nTest 12: Partial initialization for ~Copyable")

    // Cannot create partially-initialized InlineArray<N, ~Copyable>
    // because:
    // 1. InlineArray(repeating:) requires Copyable
    // 2. Array literal requires full initialization
    // 3. No "nil" or placeholder value for ~Copyable

    print("  InlineArray requires FULL initialization")
    print("  No way to start empty with ~Copyable elements")
    print("  ⚠️ Raw byte storage is REQUIRED for ~Copyable partial init")
}

print("\n=== Investigation Complete ===")

print("""

╔════════════════════════════════════════════════════════════════════╗
║                      EXPERIMENT CONCLUSIONS                        ║
╠════════════════════════════════════════════════════════════════════╣
║                                                                    ║
║  WHAT WORKS:                                                       ║
║  ✅ InlineArray.span as property (Swift stdlib)                    ║
║  ✅ Forwarding to InlineArray.span (wrapper pattern)               ║
║  ✅ storage.span.extracting(0..<storedCount) for partial validity  ║
║  ✅ InlineArray<N, ~Copyable> with array literal (full init only)  ║
║                                                                    ║
║  WHAT DOESN'T WORK:                                                ║
║  ❌ Creating Span from local pointer variable                      ║
║     (lifetime-dependent value escapes its scope)                   ║
║  ❌ Using withUnsafePointer + return Span pattern                  ║
║  ❌ Partial initialization for ~Copyable elements                  ║
║                                                                    ║
║  KEY CONSTRAINT FROM Set.Ordered ARCHITECTURE:                     ║
║  • "Elements can be ~Copyable" (Set.Ordered.swift line 38)         ║
║  • This is a core design requirement, not optional                 ║
║                                                                    ║
║  WHY RAW BYTE STORAGE IS REQUIRED:                                 ║
║  • InlineArray(repeating:) requires Copyable                       ║
║  • Array literals require full initialization at declaration       ║
║  • No InlineArray.init() for uninitialized storage exists          ║
║  • ~Copyable elements cannot have "placeholder" values             ║
║                                                                    ║
║  ANSWER TO "Redesign to InlineArray<N, Element>?":                 ║
║                                                                    ║
║  ❌ NO - Would break ~Copyable support                             ║
║                                                                    ║
║  If we redesigned to InlineArray<capacity, Element>:               ║
║  + Would enable property-based span forwarding                     ║
║  + Would enable Memory.Contiguous.Protocol conformance             ║
║  - Would LOSE ~Copyable element support (core requirement)         ║
║  - Would require Element: Copyable constraint                      ║
║                                                                    ║
║  FINAL ARCHITECTURE:                                               ║
║                                                                    ║
║  Heap-backed types (Set.Ordered, Set.Ordered.Bounded):             ║
║    → Property-based span/mutableSpan                               ║
║    → Conform to Memory.Contiguous.Protocol                         ║
║    → Support ~Copyable via heap allocation                         ║
║                                                                    ║
║  Inline types (Set.Ordered.Inline, Set.Ordered.Small):             ║
║    → Closure-based withSpan/withMutableSpan                        ║
║    → NO Memory.Contiguous.Protocol conformance                     ║
║    → Support ~Copyable via raw byte storage                        ║
║                                                                    ║
║  This is the correct design. Closure-based access is the cost      ║
║  of supporting ~Copyable elements with inline storage.             ║
╚════════════════════════════════════════════════════════════════════╝
""")
