import Property_Primitives

// The ~Copyable buffer leaf, owning a concrete HeapStorage.
public struct LinearBuffer: ~Copyable {
    @usableFromInline var storage: HeapStorage

    public init(capacity: Int) {
        storage = HeapStorage(capacity: capacity)
        Operations.fill(storage, count: capacity, value: 1)
    }

    // Direct (non-property) read path, for correctness verification.
    public borrowing func checksum(count: Int) -> Int {
        Operations.sum(storage, count: count)
    }
}

// MARK: - Variant A — CONCRETE-Base property accessor (the documented Property.Inout pattern)
// `buffer.bump.all(by:count:)` — phantom-tagged accessor namespace, operation declared on
// Property.Inout at module scope, bound to the concrete Base. Reuse (if any) is via the
// generic `Operations.bump` it forwards to.
extension LinearBuffer {
    public typealias Property<Tag> = Property_Primitives.Property<Tag, LinearBuffer>

    public enum BumpTag {}

    public var bump: Property<BumpTag>.Inout {
        mutating _read { yield .init(&self) }
        mutating _modify {
            var accessor = Property<BumpTag>.Inout(&self)
            yield &accessor
        }
    }
}

extension Property.Inout where Tag == LinearBuffer.BumpTag, Base == LinearBuffer {
    public mutating func all(by delta: Int, count: Int) {
        Operations.bump(base.value.storage, count: count, by: delta)
    }
}
