// MARK: - ABSOLUTE MINIMAL: Generic subscript label == param name bug
// Purpose: Smallest possible reproduction of the compiler bug.
// Bug: subscript<O: P>(position: O) fails at call site but
//      subscript<O: P>(position o: O) works — same external label.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — bug reproduces with both features (MIV + IIBD)
// Date: 2026-02-10

protocol P { var rawValue: Int { get } }
struct Idx: P { var rawValue: Int }

// FAILS — label `position` is also the parameter name
extension Array {
    subscript<O: P>(position: O) -> Element { self[position.rawValue] }
}

print([1, 2, 3][position: Idx(rawValue: 0)])
