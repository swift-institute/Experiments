// ===----------------------------------------------------------------------===//
//
// Tests for Conditional Copyable Array.Bounded Experiment
//
// ===----------------------------------------------------------------------===//

import Testing
@testable import ConditionalCopyableExperiment

// MARK: - Test Suite

@Suite
struct ConditionalCopyableTests {

    // MARK: - Copyable Element Tests

    @Test
    func `Bounded with Copyable elements is Copyable`() throws {
        let original = try ExperimentalArray<Int>.Bounded(count: 5) { $0 * 2 }

        // This should compile - proves Bounded is Copyable when Element is Copyable
        let copy = original

        // Both should have same elements
        #expect(original.count == 5)
        #expect(copy.count == 5)

        for i in 0..<5 {
            #expect(original[i] == i * 2)
            #expect(copy[i] == i * 2)
        }
    }

    @Test
    func `Sequence conformance works for Copyable elements`() throws {
        let array = try ExperimentalArray<Int>.Bounded(count: 4) { $0 + 10 }

        // This should compile - proves Sequence conformance
        var elements: [Int] = []
        for element in array {
            elements.append(element)
        }

        #expect(elements == [10, 11, 12, 13])
    }

    @Test
    func `Copy-on-Write semantics work`() throws {
        var original = try ExperimentalArray<Int>.Bounded(count: 3) { $0 }
        let copy = original

        // Mutate original
        original[0] = 100

        // Copy should be unchanged (CoW triggered)
        #expect(original[0] == 100)
        #expect(copy[0] == 0)
    }

    @Test
    func `Multiple copies are independent`() throws {
        var a = try ExperimentalArray<Int>.Bounded(count: 3) { $0 }
        var b = a
        var c = a

        a[0] = 100
        b[1] = 200
        c[2] = 300

        #expect(a[0] == 100)
        #expect(a[1] == 1)
        #expect(a[2] == 2)

        #expect(b[0] == 0)
        #expect(b[1] == 200)
        #expect(b[2] == 2)

        #expect(c[0] == 0)
        #expect(c[1] == 1)
        #expect(c[2] == 300)
    }

    // MARK: - Non-Copyable Element Tests

    @Test
    func `Bounded with ~Copyable elements works`() throws {
        struct MoveOnly: ~Copyable {
            let value: Int
        }

        var array = try ExperimentalArray<MoveOnly>.Bounded(count: 3) { MoveOnly(value: $0) }

        #expect(array.count == 3)
        #expect(array.isEmpty == false)

        // Use forEach for iteration (no Sequence conformance)
        var values: [Int] = []
        array.forEach { element in
            values.append(element.value)
        }
        #expect(values == [0, 1, 2])

        // Use withElement for single access
        array.withElement(at: 1) { element in
            #expect(element.value == 1)
        }
    }

    // MARK: - Edge Cases

    @Test
    func `Empty array works`() throws {
        let array = try ExperimentalArray<Int>.Bounded(count: 0) { $0 }

        #expect(array.count == 0)
        #expect(array.isEmpty == true)

        var iterCount = 0
        for _ in array { iterCount += 1 }
        #expect(iterCount == 0)
    }

    @Test
    func `Single element array works`() throws {
        let array = try ExperimentalArray<Int>.Bounded(count: 1) { _ in 42 }

        #expect(array.count == 1)
        #expect(array[0] == 42)

        var elements: [Int] = []
        for e in array { elements.append(e) }
        #expect(elements == [42])
    }

    @Test
    func `Large array maintains invariants`() throws {
        let size = 10_000
        let array = try ExperimentalArray<Int>.Bounded(count: size) { $0 }

        #expect(array.count == size)

        // Verify some elements
        #expect(array[0] == 0)
        #expect(array[size / 2] == size / 2)
        #expect(array[size - 1] == size - 1)

        // Iterator count matches
        var iterCount = 0
        for _ in array { iterCount += 1 }
        #expect(iterCount == size)
    }

    @Test
    func `Negative count throws error`() {
        #expect(throws: ExperimentalArray<Int>.Bounded.Error.self) {
            try ExperimentalArray<Int>.Bounded(count: -1) { $0 }
        }
    }

    // MARK: - Span Tests

    @Test
    func `Span provides correct access`() throws {
        let array = try ExperimentalArray<Int>.Bounded(count: 5) { $0 * 3 }
        let span = array.span

        #expect(span.count == 5)
        for i in 0..<5 {
            #expect(span[i] == i * 3)
        }
    }

    @Test
    func `forEach and Sequence yield same elements`() throws {
        let array = try ExperimentalArray<Int>.Bounded(count: 5) { $0 * 2 }

        var forEachElements: [Int] = []
        array.forEach { forEachElements.append($0) }

        var sequenceElements: [Int] = []
        for e in array { sequenceElements.append(e) }

        #expect(forEachElements == sequenceElements)
    }
}
