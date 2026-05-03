@_exported public import L2Methods
public import Tagged_Primitives
public import Carrier_Primitives

// L3-policy namespace. Tagged<POSIX, ISO_9945.Kernel.File.Stats> wraps
// L2's struct with the L3 namespace as phantom tag. Tagged's Carrier
// conformance cascades: `Tagged<POSIX, ISO_9945.Kernel.File.Stats>.Underlying
//   == ISO_9945.Kernel.File.Stats.Underlying
//   == ISO_9945.Kernel.File.Stats` (trivial self-carrier at L2).
//
// Net effect: any `some Carrier<ISO_9945.Kernel.File.Stats>` accepts
// BOTH the bare L2 struct AND the L3 Tagged variant uniformly.
public enum POSIX {}
extension POSIX { public enum Kernel {} }
extension POSIX.Kernel { public enum File {} }

extension POSIX.Kernel.File {
    public typealias Stats = Tagged<POSIX, ISO_9945.Kernel.File.Stats>
}

// L3-policy operation: constrained init extension on Tagged.
extension Tagged where Tag == POSIX, Underlying == ISO_9945.Kernel.File.Stats {
    public init(descriptor: Int32) throws(FooError) {
        do throws(FooError) {
            let l2 = try ISO_9945.Kernel.File.Stats(descriptor: descriptor)
            self.init(l2)
        } catch FooError.interrupted {
            let l2 = try ISO_9945.Kernel.File.Stats(descriptor: 0)
            self.init(l2)
        }
    }

    public static func get(descriptor: Int32) throws(FooError) -> Self {
        try Self(descriptor: descriptor)
    }
}

// L3-unifier flip:
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}

// Layer-agnostic helper: takes ANY Carrier whose Underlying is L2's
// struct. Accepts bare ISO_9945.Kernel.File.Stats (self-carrier) AND
// Tagged<POSIX, ISO_9945.Kernel.File.Stats> (cascaded carrier).
//
// This is the user's 2026-05-02 generalization: write code at the
// L1/L2 underlying level when you don't care which layer you got.
public func describeStats(
    _ stats: borrowing some Carrier.`Protocol`<ISO_9945.Kernel.File.Stats>
) -> String {
    let u = stats.underlying
    return "size=\(u.size) perms=\(String(u.permissions, radix: 8))"
}
