import V2_L2
import V2_L3

// (a) Typed-API use — passes.
do {
    let d = V2_L2.Descriptor(_rawValue: 3)
    try V2_L3.Policy.close(d)
    print("V2 (a) typed: ok")
} catch {
    print("V2 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge: V2 has NO raw access reachable from any consumer.
// The L2 wrapper's `privateRawClose` is file-scope-private; not visible
// to other files in V2_L2, not visible to V2_L3, not visible to V2_Consumer.
// Uncommenting the line below would fail with:
//   error: cannot find 'privateRawClose' in scope
// let rc = V2_L2.privateRawClose(3)
print("V2 (b) raw: NOT REACHABLE — private helper invisible to consumers")

// (c) Cross-module: typed surface crosses module boundary; raw does not
// exist on the public surface to begin with.
print("V2 (c) cross-module: typed only crosses boundary")
