// Library with @inlinable functions using expression-level unsafe for-in.
// When the SIL optimizer inlines these into the client module during release
// builds, it crashes with signal 6.

/// Converts an array of strings to NULL-terminated C string buffers,
/// passes the pointer array to a closure, then deallocates.
@inlinable
@unsafe
public func withCStringArray<R>(
    _ strings: [String],
    _ body: (UnsafePointer<UnsafePointer<CChar>?>) -> R
) -> R {
    var buffers: [UnsafeMutablePointer<CChar>] = unsafe []
    unsafe buffers.reserveCapacity(strings.count)

    // CRASHING PATTERN: expression-level unsafe on for-in over pointer array
    defer { for buffer in unsafe buffers { unsafe buffer.deallocate() } }

    for string in strings {
        let count = string.utf8.count + 1
        let buffer = unsafe UnsafeMutablePointer<CChar>.allocate(capacity: count)
        var i = 0
        for byte in string.utf8 {
            unsafe (buffer[i] = CChar(bitPattern: byte))
            i += 1
        }
        unsafe (buffer[i] = 0)
        unsafe buffers.append(buffer)
    }

    let pointerArray = unsafe UnsafeMutablePointer<UnsafePointer<CChar>?>.allocate(
        capacity: strings.count + 1
    )
    defer { unsafe pointerArray.deallocate() }

    for (index, buffer) in unsafe buffers.enumerated() {
        unsafe (pointerArray[index] = UnsafePointer(buffer))
    }
    unsafe (pointerArray[strings.count] = nil)

    return unsafe body(UnsafePointer(pointerArray))
}
