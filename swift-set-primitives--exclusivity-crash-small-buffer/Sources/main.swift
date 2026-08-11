// MARK: - DiagnoseStaticExclusivity Crash — Full Reproduction + Validated Workaround
// Purpose: Reproduce the DiagnoseStaticExclusivity SIL pass crash in Swift 6.2.3
//          when a ~Copyable generic struct with Hash.Protocol constraint composes
//          Buffer.Linear.Small and Hash.Table, and calls .remove.all(keepingCapacity:)
//          through the property accessor chain.
//
// Root Cause: `_heapHashTable?.remove.all(keepingCapacity: true)` and
//             `_heapHashTable!.remove.all(keepingCapacity: true)` crash the
//             DiagnoseStaticExclusivity pass. The `.remove` property uses
//             `mutating _read`/`mutating _modify` coroutine accessors. The
//             exclusivity checker cannot analyze this accessor chain on a stored
//             property of a generic ~Copyable struct.
//
// Workaround: Extract Hash.Table to a local variable, call .remove.all() on the
//             local, then write it back. This breaks the coroutine chain on `self`.
//
//   CRASHES:  _heapHashTable?.remove.all(keepingCapacity: true)
//   CRASHES:  _heapHashTable!.remove.all(keepingCapacity: true)
//   WORKS:    if var ht = _heapHashTable { ht.remove.all(keepingCapacity: true); _heapHashTable = ht }
//   WORKS:    _heapHashTable = nil
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — crash reproduced and workaround validated
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
// Date: 2026-02-09

import Buffer_Primitives
import Index_Primitives
import Ordinal_Primitives
import Cardinal_Primitives
import Hash_Table_Primitives
import Sequence_Primitives

// ============================================================================
// MARK: - Full reproduction: all methods with workaround applied
// ============================================================================

struct SmallSet<Element: Hash.`Protocol` & ~Copyable, let inlineCapacity: Int>: ~Copyable {
    @usableFromInline
    package var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>

    @usableFromInline
    package var _heapHashTable: Hash.Table<Element>?

    @usableFromInline
    package var _deinitWorkaround: AnyObject? = nil

    @inlinable
    init() {
        self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
        self._heapHashTable = nil
    }

    deinit {}

    @inlinable
    var isSpilled: Bool { _buffer.isSpilled }
}

// -- Properties --
extension SmallSet {
    @inlinable var count: Index<Element>.Count { _buffer.count }
    @inlinable var isEmpty: Bool { count == .zero }
    @inlinable var capacity: Index<Element>.Count { _buffer.capacity }
}

// -- Core Operations --
extension SmallSet where Element: Copyable {
    @inlinable
    mutating func index(_ element: Element) -> Index<Element>? {
        if isSpilled {
            return _heapHashTable!.position(
                forHash: element.hashValue,
                equals: { idx in _buffer[idx] == element }
            )
        } else {
            var idx: Index<Element> = .zero
            let end = _buffer.count.map(Ordinal.init)
            while idx < end {
                if _buffer[idx] == element { return idx }
                idx += .one
            }
            return nil
        }
    }

    @inlinable
    mutating func contains(_ element: Element) -> Bool {
        index(element) != nil
    }

    @inlinable
    @discardableResult
    mutating func insert(_ element: Element) -> (inserted: Bool, index: Index<Element>) {
        if let existing = index(element) {
            return (false, existing)
        }
        let wasSpilled = _buffer.isSpilled
        let index = _buffer.count.map(Ordinal.init)
        _buffer.append(element)
        if wasSpilled {
            _heapHashTable!.insert(__unchecked: (), position: index, hashValue: element.hashValue)
        } else if _buffer.isSpilled {
            _buildHashTable()
        }
        return (true, index)
    }

    // WORKAROUND: Extract hash table to local for .positions.decrement() call
    @inlinable
    @discardableResult
    mutating func remove(_ element: Element) -> Element? {
        if isSpilled {
            guard let removedPosition = _heapHashTable!.remove(
                hashValue: element.hashValue,
                equals: { idx in _buffer[idx] == element }
            ) else { return nil }

            let removed = _buffer.remove(at: removedPosition)

            // Cannot call _heapHashTable!.positions.decrement() directly —
            // crashes DiagnoseStaticExclusivity. Extract to local.
            var ht = _heapHashTable!
            ht.positions.decrement(after: removedPosition)
            _heapHashTable = ht

            return removed
        } else {
            guard let idx = index(element) else { return nil }
            return _buffer.remove(at: idx)
        }
    }

    // WORKAROUND: Extract hash table to local for .remove.all() call
    @inlinable
    mutating func clear(keepingCapacity: Bool = false) {
        _buffer.removeAll(keepingCapacity: keepingCapacity)
        if keepingCapacity {
            if var ht = _heapHashTable {
                ht.remove.all(keepingCapacity: true)
                _heapHashTable = ht
            }
        } else {
            _heapHashTable = nil
        }
    }
}

// -- Build Hash Table --
extension SmallSet where Element: Copyable {
    @usableFromInline
    mutating func _buildHashTable() {
        let count = _buffer.count
        _heapHashTable = Hash.Table<Element>(minimumCapacity: count)
        var idx: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while idx < end {
            _heapHashTable!.insert(__unchecked: (), position: idx, hashValue: _buffer[idx].hashValue)
            idx += .one
        }
    }
}

// -- Element Access --
extension SmallSet where Element: Copyable {
    @inlinable
    func element(at index: Index<Element>) -> Element? {
        guard index < count else { return nil }
        return _buffer[index]
    }

    @inlinable
    subscript(index: Index<Element>) -> Element {
        precondition(index < count, "Index out of bounds")
        return _buffer[index]
    }

    @inlinable var first: Element? {
        guard count > .zero else { return nil }
        return _buffer[.zero]
    }

    @inlinable var last: Element? {
        guard count > .zero else { return nil }
        let lastIndex = count.subtract.saturating(.one).map(Ordinal.init)
        return _buffer[lastIndex]
    }
}

// -- Borrowed Access --
extension SmallSet {
    @inlinable
    func withElement<R>(at index: Index<Element>, _ body: (borrowing Element) -> R) -> R {
        precondition(index < count, "Index out of bounds")
        return body(_buffer[index])
    }

    @inlinable
    func forEach<E: Swift.Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        let count = count
        guard count > .zero else { return }
        var index: Index<Element> = .zero
        let end = count.map(Ordinal.init)
        while index < end {
            try body(_buffer[index])
            index += .one
        }
    }

    // WORKAROUND: Extract hash table to local for .remove.all() call
    @inlinable
    mutating func drain(_ body: (consuming Element) -> Void) {
        guard count > .zero else { return }
        while !_buffer.isEmpty {
            body(_buffer.consumeFront())
        }
        if var ht = _heapHashTable {
            ht.remove.all(keepingCapacity: true)
            _heapHashTable = ht
        }
    }
}

// -- Span Access --
extension SmallSet {
    @inlinable
    func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        try body(_buffer.span)
    }

    @inlinable
    mutating func withMutableSpan<R, E: Swift.Error>(
        _ body: (inout MutableSpan<Element>) throws(E) -> R
    ) throws(E) -> R {
        var span = _buffer.mutableSpan
        return try body(&span)
    }
}

// -- Unsafe Buffer Access --
extension SmallSet where Element: Copyable {
    @inlinable
    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeBufferPointer(body)
    }

    @inlinable
    mutating func withUnsafeMutableBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeMutableBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _buffer.withUnsafeMutableBufferPointer(body)
    }
}

// -- Consume --
extension SmallSet where Element: Copyable {
    @inlinable
    consuming func consume() -> Sequence.Consume.View<Element, Buffer<Element>.Linear.Small<inlineCapacity>.ConsumeState> {
        var mutableSelf = self
        mutableSelf._heapHashTable = nil
        return mutableSelf._buffer.consume()
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

do {
    var s = SmallSet<Int, 4>()

    // Inline mode
    s.insert(1); s.insert(2); s.insert(3)
    print("inline: count=\(s.count), contains(2)=\(s.contains(2)), first=\(s.first!), last=\(s.last!)")

    s.remove(2)
    print("after remove(2): count=\(s.count), contains(2)=\(s.contains(2))")

    var visited: [Int] = []
    s.forEach { visited.append($0) }
    print("forEach: \(visited)")

    let spanCount = s.withSpan { $0.count }
    print("spanCount: \(spanCount)")

    s.withMutableSpan { span in span[0] = 100 }
    print("after mutableSpan: first=\(s.first!)")

    // Spill to heap
    s.insert(4); s.insert(5); s.insert(6); s.insert(7)
    print("after spill: count=\(s.count), isSpilled=\(s.isSpilled), contains(5)=\(s.contains(5))")

    // withUnsafeBufferPointer
    let ubpFirst = s.withUnsafeBufferPointer { unsafe $0[0] }
    print("unsafeBufferPointer[0]: \(ubpFirst)")

    // clear keeping capacity
    s.clear(keepingCapacity: true)
    print("after clear(keepingCapacity): count=\(s.count)")

    // Refill and drain
    s.insert(10); s.insert(20)
    var drained: [Int] = []
    s.drain { drained.append($0) }
    print("drained: \(drained)")

    // Refill and consume
    s.insert(30); s.insert(40)
    var consumed: [Int] = []
    s.consume().forEach { consumed.append($0) }
    print("consumed: \(consumed)")
}

print("All operations validated with workaround")
