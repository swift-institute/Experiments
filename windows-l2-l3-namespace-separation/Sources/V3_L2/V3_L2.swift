// V3 — twin roots (L2)
//
// Hosts the raw form under `Win32.Kernel.Close.close(_:)` — a separate root
// namespace from the L3 unifier's `Windows`. Mirrors the POSIX-side shape
// where `ISO_9945` is the IEEE specification root and `POSIX` is the
// L3-policy / unifier root. "Win32" is Microsoft's own term for the literal
// Windows API specification; treating it as the spec root parallels how
// `ISO_9945` names the IEEE 1003.1 spec.

import SharedHandle

public enum Win32 {}
extension Win32 { public enum Kernel {} }
extension Win32.Kernel { public enum Close {} }

extension Win32.Kernel.Close {
    /// L2 raw form — `CloseHandle`-shaped, takes a raw `UInt` handle.
    public static func close(_ rawHandle: UInt) -> Bool {
        rawHandle != 0
    }
}
