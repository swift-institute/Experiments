// V2 — sub-namespace (L2)
//
// Hosts the raw form under `Windows.ABI.Kernel.Close.close(_:)`. The L2 spec
// surface lives one level deeper than the cross-platform-unifier slot, freeing
// `Windows.Kernel.X` for the L3 policy tier. The "ABI" sub-namespace names the
// underlying binary contract — Microsoft documents the Win32 calling
// convention as the Windows ABI — and gives the spec layer a semantically
// distinct home.

import SharedHandle

public enum Windows {}
extension Windows { public enum ABI {} }
extension Windows.ABI { public enum Kernel {} }
extension Windows.ABI.Kernel { public enum Close {} }

extension Windows.ABI.Kernel.Close {
    /// L2 raw form — `CloseHandle`-shaped, takes a raw `UInt` handle.
    public static func close(_ rawHandle: UInt) -> Bool {
        rawHandle != 0
    }
}
