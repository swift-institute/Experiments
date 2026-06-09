// Module A — the deinit-carrying shapes. The load-bearing ingredient is the NESTED-generic-
// namespace spelling (`NS<A>.Inner<E>`, the tower's `Storage<Allocation>.Contiguous<Element>`
// shape): a FLAT top-level generic struct with the same fields does NOT reproduce (see
// `FlatInner` below, exercised as a control by the Repro executable).

/// `@unchecked Sendable`: the repro is strictly single-threaded; the counter exists only to
/// observe destruction order without any synchronization noise in the reproducing shapes.
public final class Counter: @unchecked Sendable {
    public static let shared = Counter()
    public var deinits = 0      // user-deinit executions (the oracle)
    public var fieldFrees = 0   // stored-field (Region) destructions
    public var drains = 0       // explicit drain() executions (mitigation probe)
    public init() {}
    public func reset() { deinits = 0; fieldFrees = 0; drains = 0 }
}

/// Stands in for the raw allocation field (`Memory.Heap`): its deinit observably fires when the
/// enclosing struct's STORED FIELDS are destroyed — distinguishing "user deinit skipped" from
/// "destruction skipped entirely".
public struct Region: ~Copyable {
    public init() {}
    deinit { Counter.shared.fieldFrees += 1 }
}

/// The generic namespace carrier (the `Storage<Allocation>` shape).
public struct NS<A: ~Copyable>: ~Copyable {
    /// The nested deinit-carrying struct (the `Storage<A>.Contiguous<E>` shape).
    public struct Inner<E: ~Copyable>: ~Copyable {
        @usableFromInline var region: A
        @usableFromInline var p: UnsafeMutableRawPointer?
        @usableFromInline var count: Int
        public init(region: consuming A) { self.region = region; self.p = nil; self.count = 0 }
        deinit { Counter.shared.deinits += 1 }          // THE ORACLE — must run exactly once
    }

    /// Variant W — carries the `[MEM-SAFE-027]`-style `AnyObject?` FIRST field (probed
    /// mitigation; does NOT restore the user deinit — different bug than swift#86652's
    /// triviality misclassification).
    public struct InnerW<E: ~Copyable>: ~Copyable {
        @usableFromInline var _deinitWorkaround: AnyObject? = nil
        @usableFromInline var region: A
        @usableFromInline var count: Int
        public init(region: consuming A) { self.region = region; self.count = 0 }
        deinit { Counter.shared.deinits += 1 }
    }

    /// Variant D — drainable: teardown can be driven EXPLICITLY by the box's class deinit
    /// (the WORKING mitigation; converges with the stdlib `_ContiguousArrayStorage` factoring).
    public struct InnerD<E: ~Copyable>: ~Copyable {
        @usableFromInline var region: A
        @usableFromInline var count: Int
        public init(region: consuming A) { self.region = region; self.count = 0 }
        public mutating func drain() { Counter.shared.drains += 1; count = 0 }
        deinit { Counter.shared.deinits += 1 }
    }
}

/// Control — IDENTICAL fields and deinit, but top-level (NOT namespace-nested): does not reproduce.
public struct FlatInner<E: ~Copyable>: ~Copyable {
    @usableFromInline var region: Region
    @usableFromInline var p: UnsafeMutableRawPointer?
    @usableFromInline var count: Int
    public init() { self.region = Region(); self.p = nil; self.count = 0 }
    deinit { Counter.shared.deinits += 1 }
}
