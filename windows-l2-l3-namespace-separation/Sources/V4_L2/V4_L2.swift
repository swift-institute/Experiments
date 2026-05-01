// V4 — org-prefix (L2)
//
// Hosts the raw form under `Microsoft.Kernel.Close.close(_:)`. The L2 spec
// surface is rooted in the publishing organization's name. Microsoft is the
// owner of the Win32 specification; rooting L2 there parallels how the
// ecosystem already uses `swift-arm-ltd` for ARM ISA, `swift-intel` for x86,
// and `swift-microsoft` for the Windows family.

import SharedHandle

public enum Microsoft {}
extension Microsoft { public enum Kernel {} }
extension Microsoft.Kernel { public enum Close {} }

extension Microsoft.Kernel.Close {
    /// L2 raw form — `CloseHandle`-shaped, takes a raw `UInt` handle.
    public static func close(_ rawHandle: UInt) -> Bool {
        rawHandle != 0
    }
}
