// MARK: - ~Copyable Sequence Protocol Test
// Purpose: Verify that same-file Sequence conformance poisons ~Copyable usage
// Status: CONFIRMED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — same-file conformance still fails (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Origin: noncopyable-sequence-protocol-test

enum V01_SequenceProtocol {

    // All in one file — does putting conformance in same file prevent poisoning?

    struct Buffer<Element: ~Copyable>: ~Copyable {
        private var ptr: UnsafeMutablePointer<Element>
        private(set) var count: Int

        init(capacity: Int) {
            ptr = .allocate(capacity: capacity)
            count = 0
        }

        // This method should work for all Element types
        mutating func append(_ element: consuming Element) {
            (ptr + count).initialize(to: element)
            count += 1
        }

        deinit {
            ptr.deinitialize(count: count)
            ptr.deallocate()
        }
    }

    struct Token: ~Copyable { var id: Int }

    static func run() {
        // Conditional conformance in SAME file
        // COMPILE ERROR (expected): Sequence conformance poisons Buffer's stored
        // properties — UnsafeMutablePointer<Element> requires Element: Copyable
        // once Sequence is involved, even with `where Element: Copyable` guard.
        // The conformance and test code below are commented out because they
        // reproduce the poisoning bug and would prevent the package from building.

        // extension Buffer: Sequence where Element: Copyable {
        //     func makeIterator() -> UnsafeMutableBufferPointer<Element>.Iterator {
        //         UnsafeMutableBufferPointer(start: ptr, count: count).makeIterator()
        //     }
        // }

        // Test with Copyable element (should work)
        var intBuf = Buffer<Int>(capacity: 4)
        intBuf.append(42)
        print("Int buffer count: \(intBuf.count)")

        // Test with ~Copyable element (fails due to poisoning when conformance is present)
        var tokenBuf = Buffer<Token>(capacity: 4)
        tokenBuf.append(Token(id: 1))
        print("Token buffer count: \(tokenBuf.count)")
        print("Same-file conformance test complete")
    }
}
