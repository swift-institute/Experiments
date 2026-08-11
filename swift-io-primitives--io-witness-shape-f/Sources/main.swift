//
// Purpose: Verify Shape F — capability + runner as two separate @Witness structs
//   bundled by a plain IO.Bound struct — compiles, is Sendable, and composes.
// Hypothesis: Two @Witness structs (IO + IO.Runner) plus a plain IO.Bound compile
//   cleanly on Swift 6.3 release with ~Copyable Kernel.Descriptor, typed throws, Sendable.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// Construction: build an IO.Bound from hand-written unimplemented() placeholders.
let demo: IO.Bound = IO.Bound(
    io: .unimplemented(),
    runner: .unimplemented()
)

// Pass the bundle around — region-based isolation replaces @Sendable on the function.
func observe(_ bound: sending IO.Bound) { _ = bound }
observe(demo)

print("Shape F compiles: IO.Bound has io=\(type(of: demo.io)) + runner=\(type(of: demo.runner))")
