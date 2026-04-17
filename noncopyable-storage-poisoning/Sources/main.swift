// SUPERSEDED: See noncopyable-constraint-behavior
// MARK: - ~Copyable Storage Poisoning
// Purpose: Conditional conformance poisons stored property access
// Status: BUG REPRODUCED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT

struct Storage<Element: ~Copyable>: ~Copyable {
    var buffer: UnsafeMutableBufferPointer<Element>

    init(capacity: Int) {
        let p = UnsafeMutablePointer<Element>.allocate(capacity: capacity)
        buffer = UnsafeMutableBufferPointer(start: p, count: capacity)
    }

    deinit {
        buffer.baseAddress?.deallocate()
    }
}

// Poisoning conformance
extension Storage: Sequence where Element: Copyable {
    func makeIterator() -> UnsafeMutableBufferPointer<Element>.Iterator {
        buffer.makeIterator()
    }
}

struct NonCopyableValue: ~Copyable { var x: Int }
var s = Storage<NonCopyableValue>(capacity: 8)
print("Storage created: count = \(s.buffer.count)")
