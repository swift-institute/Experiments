//
// Purpose: A hand-written IO<Ops> witness: generic over the operation set.
//   Socket.Ops and File.Ops are concrete structs of closures;
//   IO<Ops> carries them as a single stored property, alongside a runner.
// Hypothesis: The generic parameter compiles, BUT propagates virally through
//   every consumer signature. Code that takes IO<Socket.Ops> must explicitly
//   name the specialization everywhere; there is no covering opaque type for
//   "some IO with socket ops" because that requires a protocol.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Compile-only demonstration
// ============================================================================

// Viral specialization at construction: each IO<Ops> names its specialization.
let socketIO = IO<Socket.Ops>(ops: Socket.Ops(
    accept:  { _ in Kernel.Descriptor(raw: -1) },
    connect: { _, _ in },
    read:    { _, _ in 0 },
    write:   { _, _ in 0 },
    close:   { _ in }
))

let fileIO = IO<File.Ops>(ops: File.Ops(
    seek:   { _, _ in 0 },
    pread:  { _, _, _ in 0 },
    pwrite: { _, _, _ in 0 },
    fsync:  { _ in },
    close:  { _ in }
))

// Inline observers — demonstrating that each reference names the specialization.
func observe(_ io: borrowing IO<Socket.Ops>) { _ = io }
func observe(_ io: borrowing IO<File.Ops>)   { _ = io }
observe(socketIO)
observe(fileIO)

print("IO<Ops> compiles. Consumer APIs are specialized per Ops type (viral generics confirmed).")
