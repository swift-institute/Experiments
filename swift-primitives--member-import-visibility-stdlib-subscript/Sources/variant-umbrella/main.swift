// MARK: - Variant 2: Import ONLY Umbrella + MemberImportVisibility
// Purpose: Test if subscript resolves through @_exported re-export chain
// Hypothesis: Umbrella @_exported imports Core + Extensions, but under MIV
//             the extension subscript or its conditional conformance may not
//             be visible → may fail to compile
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

import Umbrella

// --- Test A: Concrete conformer (unconditional P conformance) ---
func testConcrete() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Concrete(rawValue: 1)
        let value = unsafe ptr[position: idx]
        print("V2-A Concrete: \(value)")  // Expected: 20
    }
}

// --- Test B: Tagged<Bucket, Concrete> (conditional conformance from Core) ---
enum Bucket {}

func testTagged() {
    let values: [Int] = [10, 20, 30]
    values.withUnsafeBufferPointer { buf in
        let ptr = buf.baseAddress!
        let idx = Tagged<Bucket, Concrete>(Concrete(rawValue: 1))
        let value = unsafe ptr[position: idx]
        print("V2-B Tagged: \(value)")  // Expected: 20
    }
}

testConcrete()
testTagged()
