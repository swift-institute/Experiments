// Capability protocol — faithful reduction of swift-storage-primitives' `Storage.Protocol`
// (hoisted `__StorageProtocol`): ~Copyable, with a suppressed associated Element and the
// single primitive `pointer(at:)`. (Real one uses typed `Index<Element>`; reduced to Int
// here — the typed index is orthogonal to the specialization question.)
public protocol StorageProtocol: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Int { get }
    func pointer(at slot: Int) -> UnsafeMutablePointer<Element>
}
