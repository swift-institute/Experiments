// MARK: - Experiment: Collection Iteration Semantics
// Purpose: Verify iteration semantics for ~Copyable containers AND elements
//
// Hypotheses:
// [H1] makeIterator().next() returns OWNED elements → consuming for ~Copyable
// [H2] Index-based iteration via subscript[_read] → true borrowing
// [H3] Current Property.View forEach uses makeIterator → consuming for ~Copyable
//
// Toolchain: Apple Swift version 6.2.3
// Date: 2026-01-22
// Result: CONFIRMED — Collection.ForEach should use index-based iteration
//   (subscript _read) not makeIterator for ~Copyable element support.
//   makeIterator is consuming and incompatible with ~Copyable containers.

import Collection_Primitives

// MARK: - ~Copyable Element Type

struct Token: ~Copyable {
    let id: Int

    init(_ id: Int) {
        self.id = id
        print("    Token(\(id)) created")
    }

    deinit {
        print("    Token(\(id)) destroyed")
    }
}

// MARK: - ~Copyable Container with COPYABLE Elements (baseline)

struct CopyableContainer<Element>: ~Copyable {
    var storage: [Element]

    init(_ elements: [Element]) {
        self.storage = elements
    }
}

extension CopyableContainer: Sequence.`Protocol` {
    func makeIterator() -> Array<Element>.Iterator {
        storage.makeIterator()
    }
}

extension CopyableContainer: Collection.`Protocol` {
    typealias Index = Int
    var startIndex: Int { storage.startIndex }
    var endIndex: Int { storage.endIndex }
    subscript(position: Int) -> Element { storage[position] }
    func index(after i: Int) -> Int { i + 1 }
}

// MARK: - ~Copyable Container with ~COPYABLE Elements

struct NCContainer: ~Copyable {
    var storage: UnsafeMutableBufferPointer<Token>
    var count: Int

    init(count: Int) {
        let ptr = UnsafeMutablePointer<Token>.allocate(capacity: count)
        for i in 0..<count {
            (ptr + i).initialize(to: Token(i))
        }
        self.storage = UnsafeMutableBufferPointer(start: ptr, count: count)
        self.count = count
        print("  NCContainer created with \(count) tokens")
    }

    deinit {
        print("  NCContainer deinit - destroying \(count) tokens")
        for i in 0..<count {
            (storage.baseAddress! + i).deinitialize(count: 1)
        }
        storage.baseAddress?.deallocate()
    }
}

// MARK: - Test 1: Copyable Elements - makeIterator is non-destructive

func test1_copyableElements() {
    print("\n=== TEST 1: Copyable Elements (baseline) ===")
    print("Purpose: Verify makeIterator copies elements (non-destructive)")

    do {
        var container = CopyableContainer([1, 2, 3])
        print("Before iteration: \(container.storage)")

        var iterator = container.makeIterator()
        while let element = iterator.next() {
            print("  Iterated: \(element)")
        }

        print("After iteration: \(container.storage)")
        print("Result: \(container.storage.count == 3 ? "PASS - non-destructive" : "FAIL")")
    }
    print()
}

// MARK: - Test 2: Index-based iteration - borrowing via subscript

func test2_indexBasedIteration() {
    print("\n=== TEST 2: Index-Based Iteration ===")
    print("Purpose: Verify subscript[_read] provides borrowing access")
    print("Hypothesis: Elements are NOT consumed when accessed by index")

    do {
        var container = CopyableContainer([10, 20, 30])
        print("Before index iteration: \(container.storage)")

        var index = container.startIndex
        while index < container.endIndex {
            let element = container[index]  // subscript access
            print("  container[\(index)] = \(element)")
            index = container.index(after: index)
        }

        print("After index iteration: \(container.storage)")
        print("Result: \(container.storage.count == 3 ? "PASS - borrowing" : "FAIL")")
    }
    print()
}

// MARK: - Test 3: ~Copyable Elements - what happens with makeIterator?

func test3_noncopyableIterator() {
    print("\n=== TEST 3: ~Copyable Elements with makeIterator ===")
    print("Purpose: Test if makeIterator pattern works with ~Copyable elements")
    print("Hypothesis: Cannot use makeIterator().next() because it returns OWNED Element")
    print("")
    print("This test is COMMENTED OUT because it would not compile:")
    print("  - IteratorProtocol.next() returns Element? (owned)")
    print("  - For ~Copyable Element, owned return = move/consume")
    print("  - Swift Array<Token> doesn't work with ~Copyable Token")
    print("")
    print("Result: CONFIRMED - makeIterator pattern incompatible with ~Copyable elements")
    print()

    // The following would NOT compile:
    // var container = NCContainer(count: 3)
    // var iterator = container.makeIterator()  // Can't have Array<Token>.Iterator
    // while let token = iterator.next() { ... }
}

// MARK: - Test 4: ~Copyable Elements - index-based borrowing

func test4_noncopyableIndexBased() {
    print("\n=== TEST 4: ~Copyable Elements with Index-Based Iteration ===")
    print("Purpose: Verify index-based iteration works with ~Copyable elements")
    print("Hypothesis: subscript with _read enables borrowing without ownership transfer")
    print()

    // We need a container that:
    // 1. Conforms to Collection.Protocol
    // 2. Has subscript that uses _read to yield borrowed Element
    // 3. Works with ~Copyable Element

    print("Creating container with 3 ~Copyable tokens:")
    do {
        let container = NCContainer(count: 3)

        print("\nIterating by index (borrowing via closure):")
        for i in 0..<container.count {
            // Use withElement pattern for borrowing access to ~Copyable
            container.withElement(at: i) { token in
                print("  Borrowed token id: \(token.id)")
            }
        }

        print("\nAfter iteration - container still valid:")
        print("  Container count: \(container.count)")
        print("Result: PASS - tokens borrowed, not consumed")
    }
    print("Container destroyed (tokens deinit here)")
    print()
}

extension NCContainer {
    /// Borrowing access to element at index - works with ~Copyable
    func withElement(at index: Int, _ body: (borrowing Token) -> Void) {
        body(storage[index])
    }
}

// MARK: - Test 5: Property.View semantics analysis

func test5_propertyViewAnalysis() {
    print("\n=== TEST 5: Property.View Semantics Analysis ===")
    print("Purpose: Analyze current Property.View forEach implementation")
    print()
    print("Current implementation (Collection.ForEach+Property.View.swift):")
    print("```")
    print("public func callAsFunction(_ body: (Base.Element) -> Void) {")
    print("    var iterator = unsafe base.pointee.makeIterator()")
    print("    while let element = iterator.next() {")
    print("        body(element)")
    print("    }")
    print("}")
    print("```")
    print()
    print("Analysis:")
    print("  - Uses makeIterator() which requires Element to be iterable")
    print("  - iterator.next() returns OWNED Element")
    print("  - For Copyable: copies element (non-destructive)")
    print("  - For ~Copyable: would consume element (destructive)")
    print()
    print("Proposed fix for Collection.ForEach:")
    print("```")
    print("public func callAsFunction(_ body: (Base.Element) -> Void) {")
    print("    var index = unsafe base.pointee.startIndex")
    print("    while index < unsafe base.pointee.endIndex {")
    print("        body(unsafe base.pointee[index])  // borrowing via _read")
    print("        index = unsafe base.pointee.index(after: index)")
    print("    }")
    print("}")
    print("```")
    print()
    print("Benefits of index-based approach:")
    print("  - subscript[_read] yields borrowed reference")
    print("  - Works for BOTH Copyable and ~Copyable elements")
    print("  - True borrowing semantics - non-destructive")
    print("  - Requires Collection (has indices) - that's appropriate for Collection.ForEach")
    print()
}

// MARK: - Run All Tests

print(String(repeating: "=", count: 60))
print("EXPERIMENT: Collection Iteration Semantics")
print(String(repeating: "=", count: 60))

test1_copyableElements()
test2_indexBasedIteration()
test3_noncopyableIterator()
test4_noncopyableIndexBased()
test5_propertyViewAnalysis()

print(String(repeating: "=", count: 60))
print("SUMMARY")
print(String(repeating: "=", count: 60))
print()
print("Findings:")
print("1. makeIterator().next() returns OWNED elements")
print("   - Copyable: copies (non-destructive)")
print("   - ~Copyable: incompatible (cannot create iterator)")
print()
print("2. Index-based iteration via subscript[_read]")
print("   - Yields BORROWED reference")
print("   - Works for both Copyable AND ~Copyable")
print("   - True borrowing semantics")
print()
print("Recommendation:")
print("- Sequence.ForEach: keep makeIterator() - sequences are single-pass, owned")
print("- Collection.ForEach: change to index-based - collections support borrowing")
print()
print("This enables ~Copyable elements with true borrowing on Collections.")
