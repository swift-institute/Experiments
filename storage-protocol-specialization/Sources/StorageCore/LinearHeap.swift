// Concrete Layer-3 leaf — owns a concrete `HeapStorage`, delegates to the generic core.
// `total(count:)` is deliberately NOT @inlinable: this is the realistic public-API default.
// It tests whether within-module release optimization specializes the generic call so that
// the cross-module consumer just makes a plain call into already-specialized code (no witness
// dispatch leaking to the call site).
public struct LinearHeap: ~Copyable {
    @usableFromInline var storage: HeapStorage

    public init(capacity: Int) {
        storage = HeapStorage(capacity: capacity)
        Operations.fill(storage, count: capacity, value: 1)
    }

    public func total(count: Int) -> Int {
        Operations.sum(storage, count: count)
    }
}
