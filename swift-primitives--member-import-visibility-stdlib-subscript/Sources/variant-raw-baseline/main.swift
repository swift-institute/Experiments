// MARK: - Variant 6: No Swift features at all (raw baseline)
// Purpose: Strip ALL upcoming features — does the generic subscript resolve
//          in a vanilla Swift 6.2 configuration?
// Hypothesis: If this works, one of the upcoming features is the culprit.
//             If this fails, it's a base Swift 6 issue.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

import Core
import Extensions

func testConcrete() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr[position: idx]
        print("V6-A Concrete: \(value)")  // Expected: 20
    }
}

testConcrete()
