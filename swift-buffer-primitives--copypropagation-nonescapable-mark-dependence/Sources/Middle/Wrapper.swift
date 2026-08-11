// Middle module: adds @inlinable depth and the control flow pattern
// that triggers CopyPropagation false positive.

public import Core

// ─── Wrapper type (mirrors Stack/Queue with _buffer stored property) ───

public struct Wrapper<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    internal var _buffer: Container<Element>

    @inlinable
    public init(capacity: Int) {
        _buffer = Container(capacity: capacity)
    }

    // ─── V1: Simple accessor chain + conditional reassignment ───
    // Mirrors: Stack.clear(keepingCapacity:)
    // Pattern: _buffer.remove.all() + conditional _buffer = ...

    @inlinable
    public mutating func clear(keepingCapacity: Bool = true) {
        _buffer.remove.all()

        if !keepingCapacity {
            _buffer = Container<Element>(capacity: 0)
        }
    }

    // ─── V2: Multiple accessor chains in branches ───
    // Mirrors: Heap.MinMax.removeMin() with multiple _buffer.swap + _buffer.remove

    @inlinable
    public mutating func clearAndCheck() -> Int {
        let count = _buffer.access.count
        _buffer.remove.all()

        if count > 0 {
            _buffer = Container<Element>(capacity: count)
        }
        return count
    }

    // ─── V3: Accessor in try/catch ───
    // Mirrors: Parser.parse() with input.restore.to() across try/catch

    @inlinable
    public mutating func clearOrThrow(shouldThrow: Bool) throws(ClearError) {
        if shouldThrow {
            throw .failed
        }
        _buffer.remove.all()
        _buffer = Container<Element>(capacity: 0)
    }

    @inlinable
    public mutating func tryClear() {
        do {
            try clearOrThrow(shouldThrow: false)
        } catch {
            _buffer.remove.all()
        }
    }
}

public enum ClearError: Error {
    case failed
}
