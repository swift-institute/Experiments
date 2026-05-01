import V4_L2
import V4_L3

// (a) Typed-API use — passes.
do {
    let d = V4_L2.Descriptor(_rawValue: 3)
    try V4_L3.Policy.close(d)
    print("V4 (a) typed: ok")
} catch {
    print("V4 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge via package access. V4_Consumer is in the same SPM
// package as V4_L2, so the `package` raw form is visible.
let rc = V4_L2.Close.close(3)
print("V4 (b) raw via package: rc=\(rc)")

// (c) Cross-module: works WITHIN this Package.swift. In production, L2
// packages and consumers (e.g., swift-iso-9945 vs swift-foundations) are
// SEPARATE SPM packages — `package` access will NOT cross those bounds.
// Either every cross-stack consumer would have to live in the same SPM
// package as the L2 it accesses (a major restructure), or this scheme
// admits raw access only to within-stack-package siblings.
print("V4 (c) cross-module: works WITHIN one SPM package only")
