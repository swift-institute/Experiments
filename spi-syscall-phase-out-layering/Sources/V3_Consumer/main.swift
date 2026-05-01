@testable import V3_L2
import V3_L3

// (a) Typed-API use through L3 — passes.
do {
    let d = V3_L2.Descriptor(_rawValue: 3)
    try V3_L3.Policy.close(d)
    print("V3 (a) typed: ok")
} catch {
    print("V3 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge: reachable because V3_Consumer uses `@testable import`
// and V3_L2 was compiled with `-enable-testing`.
let rc = V3_L2.internalRawClose(3)
print("V3 (b) raw via @testable: rc=\(rc)")

// (c) Cross-module: works in this experiment because BOTH modules carry
// `-enable-testing`. In a real ecosystem, this means production L2 modules
// would need to ship with -enable-testing — a non-trivial cost.
// Without -enable-testing on V3_L2, @testable import fails:
//   error: module 'V3_L2' was not compiled for testing
print("V3 (c) cross-module: works only when L2 ships with -enable-testing")
