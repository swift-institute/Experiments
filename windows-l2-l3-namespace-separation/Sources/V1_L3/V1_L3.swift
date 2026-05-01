// V1 — status quo (L3)
//
// Adds the typed L3 policy wrapper at `Windows.Kernel.Close.close(_:)` —
// the same namespace path L2 already occupies. Co-location is the variant's
// defining property; spec/policy distinction is left to method-overload
// signature divergence (raw `UInt` at L2, typed `FakeHandle` at L3).

@_exported public import V1_L2
import SharedHandle

extension Windows.Kernel.Close {
    /// L3 policy wrapper — validates the typed handle and delegates to the
    /// L2 raw form via the underlying `UInt`.
    public static func close(_ handle: FakeHandle) -> Bool {
        guard handle != .invalid else { return false }
        return Windows.Kernel.Close.close(handle.value)
    }
}
