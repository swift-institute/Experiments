// MARK: - Variant 8: Absolute minimal reproduction
// Purpose: Smallest possible code that triggers the bug.
// Hypothesis: Generic extension subscripts fail to resolve at call sites in Swift 6.2.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: <PENDING>
// Date: 2026-02-10

// ── Minimal setup ──

protocol P {
    var rawValue: Int { get }
}

struct Idx: P {
    var rawValue: Int
}

// ── Test 1: Generic extension subscript on own type ──

struct Buf {
    var storage: [Int]
    subscript<O: P>(at o: O) -> Int { storage[o.rawValue] }
}

let buf = Buf(storage: [10, 20, 30])
print("Test 1:", buf[at: Idx(rawValue: 1)])    // Expected: 20

// ── Test 2: Generic extension subscript on Array ──

extension Array {
    subscript<O: P>(at o: O) -> Element { self[o.rawValue] }
}

let arr = [10, 20, 30]
print("Test 2:", arr[at: Idx(rawValue: 1)])    // Expected: 20

// ── Test 3: Non-generic subscript (control) ──

extension Array {
    subscript(idx: Idx) -> Element { self[idx.rawValue] }
}

print("Test 3:", arr[Idx(rawValue: 1)])        // Expected: 20

// ── Test 4: Generic method (control) ──

extension Array {
    func element<O: P>(at o: O) -> Element { self[o.rawValue] }
}

print("Test 4:", arr.element(at: Idx(rawValue: 1)))  // Expected: 20
