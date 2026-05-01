// V5 — literal-spec (L2)
//
// Hosts the raw form under `WinSDK.Kernel.Close.close(_:)`. "WinSDK" echoes
// the existing Microsoft-published Swift module name (the C-shim umbrella
// that surfaces the Windows SDK headers to Swift). Rooting L2 at the SDK
// distribution name tracks Microsoft's own conceptual layering between the
// SDK headers and the Win32 API.

import SharedHandle

public enum WinSDK {}
extension WinSDK { public enum Kernel {} }
extension WinSDK.Kernel { public enum Close {} }

extension WinSDK.Kernel.Close {
    /// L2 raw form — `CloseHandle`-shaped, takes a raw `UInt` handle.
    public static func close(_ rawHandle: UInt) -> Bool {
        rawHandle != 0
    }
}
