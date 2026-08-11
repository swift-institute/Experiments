//
// Purpose: A domain witness (Socket.IO) generic over the IO substrate it
//   consumes. One Socket.IO<Substrate> type serves blocking / events /
//   completions via substrate specialization.
// Hypothesis: Because protocols are forbidden, there is no way to constrain
//   `Substrate` to "has .ready, .read, .write". The workaround is to store
//   the substrate AND closures that project operations off it — which means
//   the generic parameter buys very little over just carrying the closures.
//   Compiles, but the shape is REDUNDANT vs io-witness-domain-via-map.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Compile-only demonstration
// ============================================================================

let io = IO(
    read:  { _, _ in 0 },
    write: { _, _ in 0 },
    ready: { _, _ in },
    close: { _ in }
)

let socketIO: Socket.IO<IO> = .on(io)

func observe(_ s: borrowing Socket.IO<IO>) { _ = s }
observe(socketIO)

print("Socket.IO<Substrate=IO> compiles. Substrate is opaque without protocols — projection closures must be stored explicitly, making this shape near-equivalent to io-witness-domain-via-map.")
