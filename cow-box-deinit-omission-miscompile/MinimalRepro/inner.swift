// Module A v2 — the NESTED-generic-namespace shape (Storage<A>.Contiguous<E> / Buffer<S>.Linear).
public final class Counter3 {
    public static let shared = Counter3()
    public var deinits = 0
    public var fieldFrees = 0
    public init() {}
}

public struct Region3: ~Copyable {
    public init() {}
    deinit { Counter3.shared.fieldFrees += 1 }
}

public struct NS<A: ~Copyable>: ~Copyable {
    public struct Inner<E: ~Copyable>: ~Copyable {       // deinit on the nested generic (Storage.Contiguous shape)
        @usableFromInline var region: A
        @usableFromInline var p: UnsafeMutableRawPointer?
        @usableFromInline var count: Int
        public init(region: consuming A) { self.region = region; self.p = nil; self.count = 0 }
        deinit { Counter3.shared.deinits += 1 }
    }
}

public struct NB<S: ~Copyable>: ~Copyable {              // Buffer namespace shape
    public struct Wrap: ~Copyable {                      // Linear shape (no deinit)
        @usableFromInline var inner: S
        public init(inner: consuming S) { self.inner = inner }
    }
}
