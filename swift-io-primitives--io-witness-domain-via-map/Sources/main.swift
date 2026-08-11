//
// Purpose: A domain-specific witness (Socket.IO) built from the generic IO
//   via an io.map { ... } composition, with no SPI and no protocol.
// Hypothesis: Socket.IO can be constructed from IO by capturing `io` in a
//   closure that calls io.ready + a raw syscall stand-in. Compiles on Swift
//   6.3 release with ~Copyable descriptors and typed throws.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

let io: IO = .unimplemented()
let sockets: Socket.IO = Socket.IO.make(from: io)

func observe(_ s: sending Socket.IO) { _ = s }
observe(sockets)

print("Domain-via-map compiles: Socket.IO=\(type(of: sockets)) built from IO=\(type(of: io))")
