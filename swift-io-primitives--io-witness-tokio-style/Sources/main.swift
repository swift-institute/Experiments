//
// Purpose: Emulate Tokio's AsyncRead / AsyncWrite split as three separate
//   @Witness structs, bundled by a plain IO.Duplex struct. Tests whether
//   the trait-per-capability shape translates cleanly to witnesses.
// Hypothesis: Three @Witness structs compile and bundle into a plain struct.
//   Downside relative to a single unified witness: consumers that need all
//   three must thread three parameters, or always take the bundle. There is
//   no "IO.Reader + IO.Writer" spelling without a combining type.
// Toolchain: Swift 6.3 release
// Platform: macOS 26 (arm64)
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Demo namespace (consumer API demonstrating the threading cost)
// ============================================================================

enum Demo {
    // Consumer that only needs reading.
    static func drain(
        fd: borrowing Kernel.Descriptor,
        reader: sending IO.Reader,
        buffer: Memory.Buffer.Mutable
    ) async throws(IO.Error) {
        _ = try await reader.read(fd, buffer)
    }

    // Consumer that needs full duplex. Either thread three parameters, or take bundle.
    static func proxy(
        fd: borrowing Kernel.Descriptor,
        ops: sending IO.Duplex,
        buf: Memory.Buffer.Mutable,
        payload: Memory.Buffer
    ) async throws(IO.Error) {
        _ = try await ops.reader.read(fd, buf)
        _ = try await ops.writer.write(fd, payload)
    }
}

// ============================================================================
// MARK: - Compile-only demonstration
// ============================================================================

let bundle = IO.Duplex(
    reader: .unimplemented(),
    writer: .unimplemented(),
    closer: .unimplemented()
)

func observe(_ b: sending IO.Duplex) { _ = b }
observe(bundle)

print("Tokio-style split witnesses compile. Bundle or threaded params required for multi-capability consumers.")
