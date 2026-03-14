// Client module that triggers cross-module @inlinable SIL specialization.
// Build with: swift build -c release

import UnsafeLib

let result = unsafe withCStringArray(["hello", "world"]) { argv in
    var i = 0
    while let ptr = unsafe argv[i] {
        _ = unsafe ptr
        i += 1
    }
    return i
}
print("Converted \(result) strings")
