// V2 — sub-namespace (L3)
//
// Adds the L3 policy wrapper at `Windows.Kernel.Close.close(_:)`. The L2 spec
// surface lives at `Windows.ABI.Kernel.X` (re-exported from V2_L2), so the
// two tiers occupy disjoint namespace paths under the same `Windows` root.

@_exported public import V2_L2
import SharedHandle

extension Windows { public enum Kernel {} }
extension Windows.Kernel { public enum Close {} }

extension Windows.Kernel.Close {
    /// L3 policy wrapper — validates the typed handle and delegates to L2.
    public static func close(_ handle: FakeHandle) -> Bool {
        guard handle != .invalid else { return false }
        return Windows.ABI.Kernel.Close.close(handle.value)
    }
}
