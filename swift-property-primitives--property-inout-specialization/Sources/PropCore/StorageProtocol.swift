// Capability protocol — same faithful reduction as the storage-protocol-specialization
// experiment: ~Copyable, suppressed associated Element, single `pointer(at:)` primitive.
public protocol StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Int { get }
    func pointer(at slot: Int) -> UnsafeMutablePointer<Element>
}
