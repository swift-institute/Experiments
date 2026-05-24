// The Layer-2 generic core — written ONCE over `some StorageProtocol`, the thing that would
// replace the current 2×2 (Heap/Inline × Copyable/~Copyable) duplication. The hot path uses
// only `pointer(at:)`. Constrained to Element == Int so the loop body is concrete.
//
// THE QUESTION: when called with a statically-known concrete storage, does the optimizer
// specialize these (turning `storage.pointer(at:)` into a direct/inlined call) — or does it
// fall back to `witness_method` dispatch through the protocol witness table?
public enum Operations {
    public static func fill<S: StorageProtocol & ~Copyable>(
        _ storage: borrowing S, count: Int, value: Int
    ) where S.Element == Int {
        var i = 0
        while i < count {
            storage.pointer(at: i).initialize(to: value)
            i &+= 1
        }
    }

    public static func sum<S: StorageProtocol & ~Copyable>(
        _ storage: borrowing S, count: Int
    ) -> Int where S.Element == Int {
        var total = 0
        var i = 0
        while i < count {
            total &+= storage.pointer(at: i).pointee
            i &+= 1
        }
        return total
    }
}
