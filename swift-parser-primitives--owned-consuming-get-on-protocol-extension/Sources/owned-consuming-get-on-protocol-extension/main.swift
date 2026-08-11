//
// Experiment driver — print each variant's result, abort on mismatch.
//

print("=== owned-consuming-get-on-protocol-extension ===")

let v1 = runV1()
print("V1 (non-generic struct, @_owned consuming get) -> \(v1)")
precondition(v1 == 42, "V1 expected 42, got \(v1)")

let v2a = runV2A()
print("V2A (generic struct, @_owned returning Int marker) -> \(v2a)")
precondition(v2a == 42, "V2A expected 42, got \(v2a)")

let v2b = runV2B()
print("V2B (generic struct, @_owned extracting stored ~Copyable field) -> \(v2b)")
precondition(v2b == 99, "V2B expected 99, got \(v2b)")

let v3 = runV3()
print("V3 (protocol-extension @_owned consuming get) -> \(v3)")
precondition(v3 == 42, "V3 expected 42, got \(v3)")

let v4 = runV4()
print("V4 (end-to-end parser.error.map chain) -> \(v4)")
precondition(v4 == 7, "V4 expected 7, got \(v4)")

print("All variants PASS.")
