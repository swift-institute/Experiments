// MARK: - Variant 3: Import Umbrella, WITHOUT MemberImportVisibility (control)
// Purpose: Establish baseline — does it work without MIV?
// Hypothesis: Without MemberImportVisibility, all extension members resolve
//             through transitive @_exported imports → should compile
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
        print("V3-A Concrete: \(value)")  // Expected: 20
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
        print("V3-B Tagged: \(value)")  // Expected: 20
    }
}

testConcrete()
testTagged()
