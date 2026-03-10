// MARK: - Storage Variant Patterns
// Purpose: Storage variant patterns (Inline/Bounded/Unbounded/Small)
// Status: CONFIRMED
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Four storage strategies used across swift-primitives:
// 1. Inline   — fixed capacity, stored in the struct (InlineArray)
// 2. Bounded  — fixed capacity, heap allocated (ManagedBuffer)
// 3. Unbounded — dynamic capacity, heap allocated (growable)
// 4. Small    — inline + heap spill (starts inline, grows to heap)

// Variant 1: Inline storage using InlineArray
struct InlineStack<let capacity: Int>: ~Copyable {
    var _storage: InlineArray<capacity, Int>
    var count: Int

    init() {
        _storage = .init(repeating: 0)
        count = 0
    }

    mutating func push(_ value: Int) {
        precondition(count < capacity)
        _storage[count] = value
        count += 1
    }

    mutating func pop() -> Int {
        precondition(count > 0)
        count -= 1
        return _storage[count]
    }
}

// Variant 2: Bounded (heap, fixed capacity)
final class BoundedStorage: @unchecked Sendable {
    let buffer: UnsafeMutableBufferPointer<Int>
    var count: Int = 0
    let capacity: Int

    init(capacity: Int) {
        self.capacity = capacity
        buffer = .allocate(capacity: capacity)
    }

    func push(_ value: Int) {
        precondition(count < capacity)
        buffer[count] = value
        count += 1
    }

    func pop() -> Int {
        precondition(count > 0)
        count -= 1
        return buffer[count]
    }

    deinit { buffer.deallocate() }
}

// Variant 3: Unbounded (heap, growable)
struct UnboundedStack {
    var storage: [Int] = []

    mutating func push(_ value: Int) {
        storage.append(value)
    }

    mutating func pop() -> Int {
        storage.removeLast()
    }

    var count: Int { storage.count }
}

// Variant 4: Small (inline with spill)
struct SmallStack<let inlineCapacity: Int>: ~Copyable {
    var _inline: InlineArray<inlineCapacity, Int>
    var _inlineCount: Int
    var _heap: [Int]?

    init() {
        _inline = .init(repeating: 0)
        _inlineCount = 0
        _heap = nil
    }

    var count: Int {
        if let heap = _heap { return heap.count }
        return _inlineCount
    }

    mutating func push(_ value: Int) {
        if _heap != nil {
            _heap!.append(value)
        } else if _inlineCount < inlineCapacity {
            _inline[_inlineCount] = value
            _inlineCount += 1
        } else {
            // Spill to heap
            var heap = [Int]()
            for i in 0..<_inlineCount {
                heap.append(_inline[i])
            }
            heap.append(value)
            _heap = heap
        }
    }
}

// Test all variants
var inline = InlineStack<8>()
inline.push(1); inline.push(2); inline.push(3)
assert(inline.pop() == 3)
print("Inline: count=\(inline.count)")

let bounded = BoundedStorage(capacity: 16)
bounded.push(10); bounded.push(20)
assert(bounded.pop() == 20)
print("Bounded: count=\(bounded.count)")

var unbounded = UnboundedStack()
unbounded.push(100); unbounded.push(200); unbounded.push(300)
assert(unbounded.pop() == 300)
print("Unbounded: count=\(unbounded.count)")

var small = SmallStack<4>()
for i in 0..<6 { small.push(i) }  // Spills at 5th element
print("Small: count=\(small.count)")
assert(small.count == 6)

print("storage-variant-patterns: CONFIRMED")
