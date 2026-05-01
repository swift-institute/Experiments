@_spi(Syscall) import V1_L2
import V1_L3

// (a) Typed-API use through L3 policy — should always pass.
do {
    let d = V1_L2.Descriptor(_rawValue: 3)
    try V1_L3.Policy.close(d)
    print("V1 (a) typed: ok")
} catch {
    print("V1 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge: bypasses L3 retry policy. Reachable only because of
// the `@_spi(Syscall)` import attribute on V1_L2.
let rc = V1_L2.Close.close(3)
print("V1 (b) raw via @_spi(Syscall): rc=\(rc)")

// (c) Cross-module: this file imports V1_L2 (with @_spi) AND V1_L3
// (regular). Both compile and link successfully; this file's compilation
// IS the cross-module test. See Outputs/V1-cross-module.txt.
print("V1 (c) cross-module: typed visible across modules; @_spi raw visible with import attribute")
