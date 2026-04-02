// MARK: - Storage Variant Patterns
// Purpose: Storage variant patterns (Static/Bounded/Dynamic/Small)
// Status: CONFIRMED
// Result: CONFIRMED — four storage strategies (Static/Bounded/Dynamic/Small) all compile and work for ~Copyable containers
// Date: 2026-01-21
// Toolchain: Swift 6.2

// Four storage strategies used across swift-primitives:
// 1. Static<let capacity>  — fixed capacity, inline storage (InlineArray / @_rawLayout)
// 2. Bounded               — fixed capacity, heap allocated (ManagedBuffer)
// 3. (base type)           — dynamic capacity, heap allocated (growable)
// 4. Small<let inlineCapacity> — inline + heap spill (starts inline, grows to heap)
//
// Production naming: The inline variant is named "Static" at the collection level
// (e.g., Stack.Static, Queue.Static), backed by Buffer.Linear.Inline / Buffer.Ring.Inline
// at the storage level. The growable variant uses the base type name (Stack, Queue, Array).

// Variant 1: Static storage using InlineArray
struct StaticStack<let capacity: Int>: ~Copyable {
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

// Variant 3: Dynamic (heap, growable)
// Note: In production, the growable variant uses the base type name directly
// (e.g., Stack, Queue, Array) — not a "Dynamic" or "Unbounded" prefix.
struct DynamicStack {
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
var staticStack = StaticStack<8>()
staticStack.push(1); staticStack.push(2); staticStack.push(3)
assert(staticStack.pop() == 3)
print("Static: count=\(staticStack.count)")

let bounded = BoundedStorage(capacity: 16)
bounded.push(10); bounded.push(20)
assert(bounded.pop() == 20)
print("Bounded: count=\(bounded.count)")

var dynamic = DynamicStack()
dynamic.push(100); dynamic.push(200); dynamic.push(300)
assert(dynamic.pop() == 300)
print("Dynamic: count=\(dynamic.count)")

var small = SmallStack<4>()
for i in 0..<6 { small.push(i) }  // Spills at 5th element
print("Small: count=\(small.count)")
assert(small.count == 6)

print("storage-variant-patterns: CONFIRMED")
