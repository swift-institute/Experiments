// SUPERSEDED: See noncopyable-constraint-behavior
// MARK: - ~Copyable Sequence Protocol Test
// Purpose: Verify that same-file Sequence conformance poisons ~Copyable usage
// Status: CONFIRMED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — same-file conformance still fails (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT

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

// Conditional conformance in SAME file
extension Buffer: Sequence where Element: Copyable {
    func makeIterator() -> UnsafeMutableBufferPointer<Element>.Iterator {
        UnsafeMutableBufferPointer(start: ptr, count: count).makeIterator()
    }
}

// Test with Copyable element (should work)
var intBuf = Buffer<Int>(capacity: 4)
intBuf.append(42)
print("Int buffer count: \(intBuf.count)")

// Test with ~Copyable element (may fail due to poisoning)
struct Token: ~Copyable { var id: Int }
var tokenBuf = Buffer<Token>(capacity: 4)
tokenBuf.append(Token(id: 1))
print("Token buffer count: \(tokenBuf.count)")
print("Same-file conformance test complete")
