// MARK: - Noncopyable Optional Access Patterns
// Purpose: Find working patterns for accessing ~Copyable optionals in borrowing contexts
// Hypothesis: switch borrows by default for ~Copyable per SE-0432
//
// Toolchain: Xcode 26 beta / Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — switch pattern matching borrows ~Copyable optionals.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Force-unwrap (!), optional chaining (?.), and if-let all CONSUME.
//         Only `switch` with `.some(let x)` borrows correctly per SE-0432.
//
// Summary of patterns tested:
//   FAIL: _heapBuffer!.count           — force-unwrap consumes
//   FAIL: _heapBuffer?.count ?? 0      — optional chaining consumes
//   FAIL: if let heap = _heapBuffer    — if-let consumes
//   PASS: switch _heapBuffer { case .some(let heap): } — borrows correctly
//   PASS: Decomposed Copyable fields   — avoids the problem entirely
//   PASS: _modify { &_heapBuffer!... } — mutating context allows force-unwrap
//   PASS: _read { switch ... }         — switch inside coroutine works
//
// Date: 2026-02-09

struct Header: Copyable, Sendable {
    var count: Int
    let capacity: Int
}

struct Storage: ~Copyable {
    var data: [Int] = []
}

struct LinearBuffer: ~Copyable {
    var header: Header
    var storage: Storage

    init(capacity: Int) {
        self.header = Header(count: 0, capacity: capacity)
        self.storage = Storage()
    }

    var count: Int { header.count }
    var capacity: Int { header.capacity }
}

struct InlineBuffer: ~Copyable {
    var count: Int = 0
}

// =============================================================================
// MARK: - W2: switch with pattern matching (SE-0432)
// Hypothesis: switch borrows by default for ~Copyable
// =============================================================================

struct SmallW2: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: LinearBuffer?

    var count: Int {
        switch _heapBuffer {
        case .some(let heap):
            return heap.count
        case .none:
            return _inlineBuffer.count
        }
    }

    var capacity: Int {
        switch _heapBuffer {
        case .some(let heap):
            return heap.capacity
        case .none:
            return 4
        }
    }

    var isEmpty: Bool { count == 0 }
    var isSpilled: Bool { _heapBuffer != nil }
    var isFull: Bool {
        switch _heapBuffer {
        case .some(_):
            return false
        case .none:
            // Inline mode — check if count == capacity
            return false  // simplified
        }
    }
}

// =============================================================================
// MARK: - W4: Decomposed storage (Copyable header + Copyable class ref separate)
// =============================================================================

final class HeapStorageRef: @unchecked Sendable {
    var data: [Int] = []
}

struct SmallW4: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapHeader: Header?        // Copyable optional — always works
    var _heapStorage: HeapStorageRef?  // Class ref — always Copyable

    var isSpilled: Bool { _heapHeader != nil }

    var count: Int {
        _heapHeader?.count ?? _inlineBuffer.count
    }

    var capacity: Int {
        _heapHeader?.capacity ?? 4
    }
}

// =============================================================================
// MARK: - W5: _read coroutine with switch
// =============================================================================

struct SmallW5: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: LinearBuffer?

    subscript(index: Int) -> Int {
        _read {
            switch _heapBuffer {
            case .some(let heap):
                yield heap.header.count
            case .none:
                yield _inlineBuffer.count
            }
        }
        _modify {
            if _heapBuffer != nil {
                yield &_heapBuffer!.header.count
            } else {
                yield &_inlineBuffer.count
            }
        }
    }
}

// =============================================================================
// MARK: - W6: Mutating func with force-unwrap
// =============================================================================

struct SmallW6: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: LinearBuffer?

    var isSpilled: Bool { _heapBuffer != nil }

    mutating func consumeFront() -> Int {
        if isSpilled {
            _heapBuffer!.header.count -= 1
            return 42
        } else {
            _inlineBuffer.count -= 1
            return 0
        }
    }

    mutating func removeAll() {
        if isSpilled {
            _heapBuffer!.header.count = 0
            _heapBuffer = nil
        } else {
            _inlineBuffer.count = 0
        }
    }
}

// =============================================================================
// MARK: - W7: Span-like borrowing access with switch
// =============================================================================

struct SmallW7: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: LinearBuffer?

    var headerView: Header {
        switch _heapBuffer {
        case .some(let heap):
            return heap.header
        case .none:
            return Header(count: _inlineBuffer.count, capacity: 4)
        }
    }
}

// =============================================================================
// MARK: - W8: Full dual-mode with switch pattern everywhere
// Hypothesis: Complete Small buffer using switch for all borrowing access
// =============================================================================

struct SmallW8: ~Copyable {
    var _inlineBuffer: InlineBuffer
    var _heapBuffer: LinearBuffer?

    // Borrowing: switch pattern
    var count: Int {
        switch _heapBuffer {
        case .some(let heap): return heap.count
        case .none: return _inlineBuffer.count
        }
    }

    var capacity: Int {
        switch _heapBuffer {
        case .some(let heap): return heap.capacity
        case .none: return 4
        }
    }

    var isEmpty: Bool { count == 0 }

    var isSpilled: Bool {
        switch _heapBuffer {
        case .some(_): return true
        case .none: return false
        }
    }

    // Mutating: force-unwrap OK
    mutating func incrementCount() {
        if _heapBuffer != nil {
            _heapBuffer!.header.count += 1
        } else {
            _inlineBuffer.count += 1
        }
    }

    // Subscript: _read uses switch, _modify uses force-unwrap
    subscript(index: Int) -> Int {
        _read {
            switch _heapBuffer {
            case .some(let heap):
                yield heap.header.count
            case .none:
                yield _inlineBuffer.count
            }
        }
        _modify {
            if _heapBuffer != nil {
                yield &_heapBuffer!.header.count
            } else {
                yield &_inlineBuffer.count
            }
        }
    }
}

// =============================================================================
// MARK: - Run
// =============================================================================

var w2 = SmallW2(_inlineBuffer: InlineBuffer(count: 5), _heapBuffer: nil)
print("W2 count: \(w2.count), capacity: \(w2.capacity), isEmpty: \(w2.isEmpty)")

var w4 = SmallW4(_inlineBuffer: InlineBuffer(count: 9), _heapHeader: nil, _heapStorage: nil)
print("W4 count: \(w4.count), capacity: \(w4.capacity)")

var w5 = SmallW5(_inlineBuffer: InlineBuffer(count: 42), _heapBuffer: nil)
print("W5 subscript[0]: \(w5[0])")

var w6 = SmallW6(_inlineBuffer: InlineBuffer(count: 3), _heapBuffer: nil)
let v = w6.consumeFront()
print("W6 consumeFront: \(v), count after: \(w6._inlineBuffer.count)")

var w7 = SmallW7(_inlineBuffer: InlineBuffer(count: 11), _heapBuffer: nil)
print("W7 headerView: \(w7.headerView)")

var w8 = SmallW8(_inlineBuffer: InlineBuffer(count: 0), _heapBuffer: nil)
w8.incrementCount()
w8.incrementCount()
print("W8 count: \(w8.count), capacity: \(w8.capacity), isSpilled: \(w8.isSpilled)")
print("W8 subscript[0]: \(w8[0])")

// Test with heap mode
var w2h = SmallW2(_inlineBuffer: InlineBuffer(count: 0), _heapBuffer: LinearBuffer(capacity: 16))
w2h._heapBuffer!.header.count = 7
print("W2 heap count: \(w2h.count), capacity: \(w2h.capacity)")

print("All workarounds compiled and ran successfully.")
