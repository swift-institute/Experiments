// MARK: - Variant 5: Non-generic extension subscript, cross-module
// Purpose: Does a SIMPLE (non-generic) extension subscript on UnsafePointer
//          resolve across modules? Isolates generics as a factor.
// Hypothesis: If this works, generics/protocol constraints are the issue.
//             If this fails, ALL extension subscripts on stdlib types break cross-module.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

import SimpleExtension

func test() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let value = unsafe ptr[at: 1]
        print("V5 Simple: \(value)")  // Expected: 20
    }
}

test()
