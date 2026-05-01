// V5 — literal-spec (L3)
//
// Adds the L3 policy wrapper at `Windows.Kernel.Close.close(_:)`. The L2 spec
// surface lives under `WinSDK.Kernel.X` (re-exported from V5_L2).

@_exported public import V5_L2
import SharedHandle

public enum Windows {}
extension Windows { public enum Kernel {} }
extension Windows.Kernel { public enum Close {} }

extension Windows.Kernel.Close {
    /// L3 policy wrapper — validates the typed handle and delegates to L2.
    public static func close(_ handle: FakeHandle) -> Bool {
        guard handle != .invalid else { return false }
        return WinSDK.Kernel.Close.close(handle.value)
    }
}
