// Minimal reproduction: expression-level `unsafe` on for-in over
// [UnsafeMutablePointer<T>] crashes the SIL optimizer in release mode
// with StrictMemorySafety enabled.
//
// Build with: swift build -c release
//
// Expected: Compilation succeeds (or diagnostic emitted)
// Actual:   Signal 6 — compiler crash during SIL optimization
//
// The crash is in the Iterator protocol's `next()` method which involves
// `inout IndexingIterator<[UnsafeMutablePointer<CChar>]>` — an unsafe type.
// The SIL optimizer cannot handle expression-level `unsafe` threading
// through the iterator machinery.
//
// Workaround: Use index-based loops instead of for-in.
//
// Swift version: 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 15 / arm64

// ── CRASHING PATTERN ──────────────────────────────────────────────────

@unsafe
func crashingPattern(_ strings: [String]) {
    var buffers: [UnsafeMutablePointer<CChar>] = unsafe []
    unsafe buffers.reserveCapacity(strings.count)

    // This defer causes signal 6 in release mode:
    defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }

    for string in strings {
        let buffer = unsafe UnsafeMutablePointer<CChar>.allocate(capacity: string.utf8.count + 1)
        unsafe buffers.append(buffer)
    }

    // Use buffers...
    for (index, buffer) in unsafe buffers.enumerated() {
        _ = unsafe buffer
        _ = index
    }
}

// ── WORKING WORKAROUND ────────────────────────────────────────────────

@unsafe
func workingPattern(_ strings: [String]) {
    var buffers: [UnsafeMutablePointer<CChar>] = unsafe []
    unsafe buffers.reserveCapacity(strings.count)

    // Index-based loop bypasses Iterator protocol entirely:
    defer { for i in 0..<buffers.count { unsafe buffers[i].deallocate() } }

    for string in strings {
        let buffer = unsafe UnsafeMutablePointer<CChar>.allocate(capacity: string.utf8.count + 1)
        unsafe buffers.append(buffer)
    }

    for i in 0..<buffers.count {
        _ = unsafe buffers[i]
    }
}

// ── Entry point ───────────────────────────────────────────────────────

// Comment out crashingPattern to verify workingPattern compiles in release.
// Uncomment to reproduce the crash.

// crashingPattern(["hello", "world"])
workingPattern(["hello", "world"])
print("OK")
