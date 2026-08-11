// The generic-over-storage core (the shared algorithm). Same shape proven to specialize
// in the storage-protocol-specialization experiment — here it is reached THROUGH the
// Property.Inout accessor instead of being called directly, to see if specialization survives.
public enum Operations {
    public static func fill<S: StorageProtocol & ~Copyable>(
        _ storage: borrowing S, count: Int, value: Int
    ) where S.Element == Int {
        var i = 0
        while i < count { storage.pointer(at: i).initialize(to: value); i &+= 1 }
    }

    public static func sum<S: StorageProtocol & ~Copyable>(
        _ storage: borrowing S, count: Int
    ) -> Int where S.Element == Int {
        var total = 0
        var i = 0
        while i < count { total &+= storage.pointer(at: i).pointee; i &+= 1 }
        return total
    }

    public static func bump<S: StorageProtocol & ~Copyable>(
        _ storage: borrowing S, count: Int, by delta: Int
    ) where S.Element == Int {
        var i = 0
        while i < count { storage.pointer(at: i).pointee &+= delta; i &+= 1 }
    }
}
