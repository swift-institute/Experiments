// MARK: - V9: Negative Test — Cross-Domain Rejection
// Hypothesis: Passing PlatformString<GenericDomain> where PathDomain is expected
//             produces a compile-time error. Type safety is preserved.
//
// This file should NOT compile. To test:
//   1. Uncomment the body of testV9_negative()
//   2. Build — should fail with type mismatch error
//   3. Re-comment and rebuild to confirm positive tests pass
//
// Result: CONFIRMED — all three lines produce compile-time errors when uncommented.
//         Error: "requires the types 'PathDomain' and 'GenericDomain' be equivalent"
//         (for requireSameDomain cross-domain call)
//         Error: "has no member 'isAbsolutePath'" (for GenericDomain access)
//         Error: "has no member 'scope'" (for GenericDomain scope access)

#if false  // Change to true to verify compile-time rejection

func testV9_negative() {
    let buf1 = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf1.initialize(from: [65, 66, 67, 0], count: 4)
    let pathString = unsafe PlatformString<PathDomain>(adopting: buf1, count: 3)

    let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 3)
    unsafe buf2.initialize(from: [68, 69, 0], count: 3)
    let genericString = unsafe PlatformString<GenericDomain>(adopting: buf2, count: 2)

    // ERROR: PathDomain != GenericDomain
    _ = requireSameDomain(pathString, genericString)

    // ERROR: GenericDomain has no isAbsolutePath
    _ = genericString.isAbsolutePath

    // ERROR: GenericDomain has no scope
    _ = PlatformString<GenericDomain>.scope
}

#endif
