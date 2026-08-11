// MARK: - @testable Import Iterator Tests
// Purpose: Determine if @testable import changes iterator behavior.
//          The standalone executable (same code, regular import) PASSES.
//          The package test target (same code, @testable import) FAILS.
//          This test target isolates the @testable variable.

import Testing
@testable import Dictionary_Primitives

@Suite("Testable Import Iterator")
struct TestableImportIteratorTests {

    // MARK: - V1: @testable import, for-in

    @Test
    func `for-in with @testable import`() {
        var dict = Dictionary<String, Int>()
        dict.set("a", 1)
        dict.set("b", 2)
        dict.set("c", 3)

        var keys: [String] = []
        for (key, _) in dict {
            keys.append(key)
        }
        #expect(keys.sorted() == ["a", "b", "c"])
    }

    // MARK: - V2: @testable import, manual iterator

    @Test
    func `manual iterator with @testable import`() {
        var dict = Dictionary<String, Int>()
        dict.set("x", 10)
        dict.set("y", 20)

        var iter = dict.makeIterator()
        var count = 0
        while let pair = iter.next() {
            _ = pair
            count += 1
        }
        #expect(count == 2)
    }

    // MARK: - V3: @testable import, 50 elements (matches failing test)

    @Test
    func `for-in after growth with @testable import`() {
        var dict = Dictionary<String, Int>()
        for i in 0..<50 {
            dict.set("k\(i)", i)
        }

        var count = 0
        for (key, value) in dict {
            #expect(key.hasPrefix("k"))
            #expect(value >= 0 && value < 50)
            count += 1
        }
        #expect(count == 50)
    }
}
