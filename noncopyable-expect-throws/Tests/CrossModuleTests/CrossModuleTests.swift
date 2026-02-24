// MARK: - Phase 8: Cross-module #expect(throws:) with ~Copyable
// Purpose: Test whether importing ~Copyable types from another module
//          causes #expect(throws:) to hang.
// Hypothesis: Cross-module boundary is the differentiating factor.
//
// Date: 2026-02-10

import Testing
@testable import Lib

@Suite("Phase 8: Cross-module")
struct CrossModuleTests {

    // MARK: - 8a: Simple ~Copyable (no deinit)
    @Test func `Cross-module simple noncopyable`() {
        var box = SimpleBox()
        try! box.fill()
        try! box.fill()
        #expect(throws: SimpleBox.Err.self) { try box.fill() }
    }

    // MARK: - 8b: ~Copyable with deinit
    @Test func `Cross-module with deinit`() {
        var box = DeinitBox()
        try! box.fill()
        try! box.fill()
        #expect(throws: DeinitBox.Err.self) { try box.fill() }
    }

    // MARK: - 8c: Value generic + deinit + AnyObject?
    @Test func `Cross-module value generic`() {
        var box = GenericBox<2>()
        try! box.fill()
        try! box.fill()
        #expect(throws: GenericBox<2>.Err.self) { try box.fill() }
    }

    // MARK: - 8d: Full composition (mirrors Dictionary.Ordered.Static)
    @Test func `Cross-module composite`() {
        var box = CompositeBox<2>()
        try! box.set(1, 10)
        try! box.set(2, 20)
        #expect(throws: CompositeBox<2>.Err.self) { try box.set(3, 30) }
    }

    // MARK: - 8e: Deep nesting (Dictionary<K,V>.Ordered.Static<N> pattern)
    @Test func `Cross-module deeply nested`() {
        var dict = Outer<String, Int>.Inner.Static<2>()
        try! dict.set(1)
        try! dict.set(2)
        #expect(throws: Outer<String, Int>.Inner.Static<2>.Err.self) { try dict.set(3) }
    }

    // MARK: - 8f: Control — do/catch with same types
    @Test func `Cross-module do-catch control`() {
        var box = CompositeBox<2>()
        try! box.set(1, 10)
        try! box.set(2, 20)
        do {
            try box.set(3, 30)
            Issue.record("Expected error")
        } catch is CompositeBox<2>.Err {
            // Expected
        } catch {
            Issue.record("Unexpected: \(error)")
        }
    }
}
