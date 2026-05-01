import V5_L2
import V5_L3

// (a) Typed-API use through L3 — passes.
do {
    let d = V5_L2.Descriptor(_rawValue: 3)
    try V5_L3.Policy.close(d)
    print("V5 (a) typed: ok")
} catch {
    print("V5 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge: V5_Consumer's own shim (ConsumerShim.swift).
// L2 exposes nothing raw; the consumer wrote its own.
let rc = consumerOwnedRawClose(3)
print("V5 (b) raw via consumer-owned shim: rc=\(rc)")

// (c) Cross-module: typed surface from L2/L3 crosses normally; raw is
// entirely consumer-local. The trade is: every consumer that needs raw
// duplicates its own FFI binding, AND each duplicate violates
// [PLAT-ARCH-008a] by importing platform C from outside the platform stack.
print("V5 (c) cross-module: typed crosses normally; raw is consumer-local (duplication)")
