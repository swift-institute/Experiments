// MARK: - DiagnoseStaticExclusivity Direct Chain Test
// Purpose: Verify that direct accessor chains on stored properties of ~Copyable
//          generic structs no longer crash the DiagnoseStaticExclusivity SIL pass.
// Hypothesis: Swift 6.2.4 fixes the crash — direct calls work without extract-to-local.
//
// Previously crashed (Swift 6.2.3):
//   _heapHashTable!.positions.decrement(after:)
//   _heapHashTable?.remove.all(keepingCapacity:)
//
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED STILL PRESENT — DiagnoseStaticExclusivity SIL pass crash persists in 6.2.4
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL CRASHES
// Date: 2026-03-10

import Buffer_Primitives
import Index_Primitives
import Ordinal_Primitives
import Cardinal_Primitives
import Hash_Table_Primitives
import Sequence_Primitives

// Minimal reproduction using the DIRECT patterns (no extract-to-local workaround)

struct SmallSet<Element: Hash.`Protocol` & ~Copyable, let inlineCapacity: Int>: ~Copyable {
    var _buffer: Buffer<Element>.Linear.Small<inlineCapacity>
    var _heapHashTable: Hash.Table<Element>?

    init() {
        self._buffer = Buffer<Element>.Linear.Small<inlineCapacity>()
        self._heapHashTable = nil
    }

    deinit {}

    var isSpilled: Bool { _buffer.isSpilled }
}

extension SmallSet where Element: Copyable {
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

    // DIRECT CALL — previously crashed DiagnoseStaticExclusivity
    @discardableResult
    mutating func remove(_ element: Element) -> Element? {
        if isSpilled {
            guard let removedPosition = _heapHashTable!.remove(
                hashValue: element.hashValue,
                equals: { idx in _buffer[idx] == element }
            ) else { return nil }

            let removed = _buffer.remove(at: removedPosition)

            // DIRECT: No extract-to-local workaround
            _heapHashTable!.positions.decrement(after: removedPosition)

            return removed
        } else {
            guard let idx = index(element) else { return nil }
            return _buffer.remove(at: idx)
        }
    }

    // DIRECT CALL — previously crashed DiagnoseStaticExclusivity
    mutating func clear(keepingCapacity: Bool = false) {
        _buffer.remove.all(keepingCapacity: keepingCapacity)
        if keepingCapacity {
            // DIRECT: No extract-to-local workaround
            _heapHashTable?.remove.all(keepingCapacity: true)
        } else {
            _heapHashTable = nil
        }
    }
}

extension SmallSet {
    // DIRECT CALL — previously crashed DiagnoseStaticExclusivity
    mutating func drain(_ body: (consuming Element) -> Void) {
        guard _buffer.count > .zero else { return }
        while !_buffer.isEmpty {
            body(_buffer.remove.first())
        }
        // DIRECT: No extract-to-local workaround
        _heapHashTable?.remove.all(keepingCapacity: true)
    }
}

// ============================================================================
// MARK: - Test
// ============================================================================

do {
    var s = SmallSet<Int, 4>()

    // Inline mode
    s.insert(1); s.insert(2); s.insert(3)
    print("inline: count=\(s._buffer.count)")

    s.remove(2)
    print("after remove(2): count=\(s._buffer.count)")

    // Spill to heap
    s.insert(4); s.insert(5); s.insert(6); s.insert(7)
    print("after spill: count=\(s._buffer.count), isSpilled=\(s.isSpilled)")

    // Remove in heap mode — tests direct _heapHashTable!.positions.decrement()
    s.remove(5)
    print("after heap remove(5): count=\(s._buffer.count)")

    // Clear keeping capacity — tests direct _heapHashTable?.remove.all()
    s.clear(keepingCapacity: true)
    print("after clear(keepingCapacity): count=\(s._buffer.count)")

    // Refill and drain — tests direct _heapHashTable?.remove.all()
    s.insert(10); s.insert(20); s.insert(30); s.insert(40); s.insert(50)
    var drained: [Int] = []
    s.drain { drained.append($0) }
    print("drained: \(drained)")

    print("PASS: All direct accessor chains work without workaround")
}
