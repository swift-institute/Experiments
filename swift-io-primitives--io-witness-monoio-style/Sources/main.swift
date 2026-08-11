//
// Purpose: Emulate monoio's "rental" buffer ownership pattern for io_uring.
//   The closure consumes the buffer for the duration of the kernel operation,
//   then returns it alongside the byte count. Caller must re-bind the buffer
//   each call.
// Hypothesis: The rental shape compiles using `consuming` parameter and a
//   tuple return. The ergonomic cost is significant for buffer-reuse loops:
//   the caller must re-bind `buf = result.0` on every iteration, and the
//   buffer cannot be captured across nested closures that themselves consume.
//   Expressible but hostile.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Consumer demonstration: the re-bind loop
// ============================================================================

// Typical reuse-in-a-loop pattern — each iteration re-binds `buf` from the
// returned tuple. This is monoio's actual API shape for io_uring.
// `@Sendable` annotation removed; non-Sendable IO/Memory.Buffer flow through
// region isolation, but here both remain Sendable so this is a no-op in
// practice.
func readLoop(
    io: IO,
    fd: borrowing Kernel.Descriptor,
    iterations: Int
) async throws(IO.Error) -> Int {
    var buf = Memory.Buffer(capacity: 4096)
    var total = 0
    for _ in 0..<iterations {
        let (returnedBuf, n) = try await io.read(fd, consume buf)
        buf = returnedBuf   // <-- re-bind every iteration; this is the ergonomic cost
        total &+= n
    }
    return total
}

// ============================================================================
// MARK: - Compile-only demonstration
// ============================================================================

let io = IO(
    read:  { _, buf in (buf, 0) },
    write: { _, buf in (buf, 0) }
)

func observe(_ io: IO) { _ = io }
observe(io)

print("monoio-style rental IO compiles. Consumer re-binds buffer every iteration — buffer-reuse loops pay explicit cost.")
