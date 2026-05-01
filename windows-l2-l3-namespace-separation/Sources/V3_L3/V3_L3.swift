// V3 — twin roots (L3)
//
// Adds the L3 policy wrapper at `Windows.Kernel.Close.close(_:)`. The L2 spec
// surface lives under a separate root, `Win32.Kernel.X` (re-exported from
// V3_L2), so the two layers occupy parallel-but-disjoint namespace trees.

@_exported public import V3_L2
import SharedHandle

public enum Windows {}
extension Windows { public enum Kernel {} }
extension Windows.Kernel { public enum Close {} }

extension Windows.Kernel.Close {
    /// L3 policy wrapper — validates the typed handle and delegates to L2.
    public static func close(_ handle: FakeHandle) -> Bool {
        guard handle != .invalid else { return false }
        return Win32.Kernel.Close.close(handle.value)
    }
}
