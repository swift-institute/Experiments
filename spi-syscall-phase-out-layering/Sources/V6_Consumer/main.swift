import V6_L2
import V6_L3

// (a) Typed-API use — passes.
do {
    let d = V6_L2.Descriptor(_rawValue: 3)
    try V6_L3.Policy.close(d)
    print("V6 (a) typed: ok")
} catch {
    print("V6 (a) typed: error \(error)")
}

// (b) Raw-FFI bridge: REFUTED by design.
//
// V6 has no raw access anywhere. Production raw use cases enumerated in
// the recommendation document include:
//
//   1. Benchmark bypass — measuring close(2) cost without retry overhead.
//   2. posix_spawn_file_actions_addclose(_:_:) — takes Int32 fd; the typed
//      Descriptor's `consuming` semantics conflict with the descriptor
//      being kept alive across the spawn for the child to inherit.
//   3. setrlimit / dup2 fd-table manipulation where the fd table is
//      reasoned about as raw integers, not consumable resources.
//   4. ABI shims for non-Swift callers (C, Objective-C, Rust FFI) where
//      the consumer literally has an Int32 with no Descriptor in sight.
//   5. `select(2)` / `poll(2)` legacy fd-set handling where the API
//      operates on integer ranges by definition.
//
// V6 cannot serve any of these without either (i) growing typed APIs to
// cover every spec syscall family — unbounded scope — or (ii) silently
// admitting unsafe-but-untyped escape hatches (defeats the purpose).
print("V6 (b) raw: REFUTED — no raw access; production raw use cases unserved")

// (c) Cross-module: typed surface crosses normally. Build/run succeeds;
// the refutation is at the *use-case coverage* level, not the
// build-success level.
print("V6 (c) cross-module: typed surface crosses; raw use cases unserved")
