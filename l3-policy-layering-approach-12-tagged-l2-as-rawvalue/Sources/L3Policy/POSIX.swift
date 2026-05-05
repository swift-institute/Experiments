@_exported public import L2Methods
public import Tagged_Primitives

// L3-policy namespace. L3 is asymmetric vs L2: L2 stays a plain struct;
// L3 wraps L2 via Tagged with the L3 namespace enum (POSIX) as the
// phantom tag. This formulation:
//   - Keeps L2 unchanged (zero migration cost at iso-9945)
//   - Single source of data: ISO_9945.Kernel.File.Stats is the RawValue,
//     so adding a field at L2 propagates automatically
//   - Distinct nominal types via generic instantiation: Tagged<POSIX, ...>
//     ≠ ISO_9945.Kernel.File.Stats (Swift's overload resolution sees
//     them as unrelated types — no same-signature collision possible)
//   - Phantom tag = the L3 namespace enum itself; no new tag types needed
public enum POSIX {}
extension POSIX { public enum Kernel {} }
extension POSIX.Kernel { public enum File {} }

extension POSIX.Kernel.File {
    /// L3's Stats — Tagged<POSIX, L2.Stats>. Single nominal type via
    /// generic instantiation, single source of data via Tagged's
    /// `rawValue: ISO_9945.Kernel.File.Stats`.
    public typealias Stats = Tagged<POSIX, ISO_9945.Kernel.File.Stats>
}

// L3-policy operation: constrained init extension on Tagged. EINTR retry
// applied here; delegates to L2's init for the actual syscall.
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public init(descriptor: Int32) throws(FooError) {
        do throws(FooError) {
            let l2 = try ISO_9945.Kernel.File.Stats(descriptor: descriptor)
            self.init(__unchecked: (), l2)
        } catch FooError.interrupted {
            // EINTR: retry once with descriptor 0 (simulated successful retry)
            let l2 = try ISO_9945.Kernel.File.Stats(descriptor: 0)
            self.init(__unchecked: (), l2)
        }
    }
}

// Forwarding accessors at the L3 surface — small per-field boilerplate
// for fields consumers want to access without `.rawValue` reach-through.
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public var size: Int64 { rawValue.size }
    public var permissions: UInt16 { rawValue.permissions }
}

// L3-unifier flip: cross-platform `Kernel.*` resolves through `POSIX.*`
// to the Tagged variant.
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}

// Ergonomic method at the L3-unifier — adds via constrained extension
// on Tagged (since Kernel.File.Stats resolves through to that
// instantiation). Body calls Self's init (the L3 policy init).
extension Tagged where Tag == POSIX, RawValue == ISO_9945.Kernel.File.Stats {
    public static func get(descriptor: Int32) throws(FooError) -> Self {
        try Self(descriptor: descriptor)
    }
}
