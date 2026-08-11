import Property_Primitives

// MARK: - Variant B — PROTOCOL-Base property accessor (maximum reuse)
// The accessor + operation are declared ONCE over `Base: LinearBufferProtocol`, shared across
// every conforming leaf — no per-leaf accessor duplication. Question: does it still specialize
// per concrete leaf, or does the protocol-Base defeat it (reverting to witness dispatch)?

public protocol LinearBufferProtocol: ~Copyable {
    associatedtype Store: StorageProtocol & ~Copyable where Store.Element == Int
    var store: Store { get }
    var elementCount: Int { get }
}

public enum SharedBumpTag {}

extension LinearBufferProtocol where Self: ~Copyable {
    public typealias SharedProperty = Property_Primitives.Property<SharedBumpTag, Self>

    public var bumpShared: SharedProperty.Inout {
        mutating _read { yield .init(&self) }
        mutating _modify {
            var accessor = SharedProperty.Inout(&self)
            yield &accessor
        }
    }
}

extension Property.Inout where Tag == SharedBumpTag, Base: LinearBufferProtocol & ~Copyable {
    public mutating func all(by delta: Int, count: Int) {
        Operations.bump(base.value.store, count: count, by: delta)
    }
}

// Conform the existing concrete leaf.
extension LinearBuffer: LinearBufferProtocol {
    public var store: HeapStorage {
        _read { yield storage }
    }
    public var elementCount: Int { storage.capacity }
}
