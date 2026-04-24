// MARK: - Variant 4: Concrete conformer only, through Umbrella + MIV
// Purpose: Isolate whether concrete (unconditional) conformance resolves
//          through umbrella when MIV is on — without any Tagged usage
// Hypothesis: Concrete: P is unconditional and may be treated differently
//             by the compiler → should compile even if Tagged variant fails
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

import Umbrella

// --- Test: Concrete conformer only (unconditional P conformance) ---
func testConcrete() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr[position: idx]
        print("V4 Concrete: \(value)")  // Expected: 20
    }
}

testConcrete()
