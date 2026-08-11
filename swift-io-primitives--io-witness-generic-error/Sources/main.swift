//
// Purpose: A hand-written IO<LeafError> witness: generic over the error type.
//   Domain packages (Socket, File) specialize the error vocabulary via mapError.
// Hypothesis: Hand-writing a generic witness bypasses the @Witness macro's
//   lack of generic-parameter propagation. The type remains Sendable, supports
//   ~Copyable Descriptor parameters, and mapError composes two IO values into
//   a third with a different error type.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// Start with a generic IO<IO<Never>.Error>
let baseIO = IO<IO<Never>.Error>(
    read:  { _, _ in 0 },
    write: { _, _ in 0 },
    close: { _ in }
)

// Derive IO<Socket.Error> via mapError
let socketIO: IO<Socket.Error> = baseIO.mapError { Socket.Error.io($0) }

// Derive IO<File.Error> via mapError
let fileIO: IO<File.Error> = baseIO.mapError { File.Error.io($0) }

func observe<E: Swift.Error>(_ io: IO<E>) { _ = io }
observe(baseIO)
observe(socketIO)
observe(fileIO)

print("IO<LeafError> compiles. mapError: IO<IO<Never>.Error> -> IO<Socket.Error>, IO<File.Error>.")
