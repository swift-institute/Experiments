// V1 — status quo (L2)
//
// Hosts the raw `CloseHandle`-shaped form at `Windows.Kernel.Close.close(_:)`,
// the same namespace path the L3 policy wrapper will occupy. The variant
// captures the namespace-occupancy collision rule from [PLAT-ARCH-008e]: when
// L2 and L3 share namespace identity, both layers compete for the same
// syntactic slot.

import SharedHandle

public enum Windows {}
extension Windows { public enum Kernel {} }
extension Windows.Kernel { public enum Close {} }

extension Windows.Kernel.Close {
    /// L2 raw form — `CloseHandle`-shaped, takes a raw `UInt` handle.
    public static func close(_ rawHandle: UInt) -> Bool {
        rawHandle != 0
    }
}
