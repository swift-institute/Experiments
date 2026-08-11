// MARK: - Typed Throws Overload Resolution
// Purpose: Determine which stdlib functions support typed throws (throws(E))
//          with generic E on production Swift, and what annotations are needed.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform:  macOS 26.0 (arm64)
//
// Result: CONFIRMED — stdlib partially supports typed throws:
//
//   WORKS (generic E, explicit closure annotation):
//     Sequence.map             — Build Succeeded
//     withUnsafeBytes(of:)     — Build Succeeded
//     withUnsafeMutableBytes(of:) — Build Succeeded
//     Mutex.withLock           — Build Succeeded (verified via dependent packages)
//
//   FAILS (rethrows erasure, even with explicit annotation):
//     Sequence.compactMap, flatMap, filter, forEach
//     Sequence.reduce(_:_:), reduce(into:_:)
//     Sequence.contains(where:), allSatisfy(_:), first(where:)
//     Sequence.sorted(by:), min(by:), max(by:)
//     Sequence.drop(while:), prefix(while:)
//     Sequence.withContiguousStorageIfAvailable
//     withUnsafeTemporaryAllocation
//
//   KEY INSIGHT: @_disfavoredOverload same-name overloads INTERFERE with
//   stdlib's native typed throws support. The overloads cause the rethrows
//   version to be selected, which then erases E. The fix is to NOT add
//   overloads and instead use explicit closure annotations.
//
//   CONSUMER REQUIREMENT: Closures passed to stdlib functions in throws(E)
//   contexts MUST have explicit annotation:
//     { (x: T) throws(E) -> U in ... }   // WORKS
//     { try f($0) }                       // FAILS — infers any Error
//
// TRACKING: https://github.com/swiftlang/swift/issues/68734
// Date:     2026-03-03

// ============================================================================
// Infrastructure
// ============================================================================

enum TestError: Error, Equatable { case bang }

func transform(_ x: Int) throws(TestError) -> String {
    guard x > 0 else { throw .bang }
    return "\(x)"
}

// ============================================================================
// MARK: - Group A: Concrete E — stdlib functions
// ============================================================================

// MARK: A1: stdlib map + concrete TestError
// Result: CONFIRMED — Build Succeeded, Output: ["1", "2", "3"]

func a1() throws(TestError) -> [String] {
    try [1, 2, 3].map { (x: Int) throws(TestError) -> String in
        try transform(x)
    }
}

// MARK: A2: stdlib withUnsafeBytes + concrete TestError
// Result: CONFIRMED — Build Succeeded, Output: 42

func a2() throws(TestError) -> UInt8 {
    let value: UInt64 = 42
    return try Swift.withUnsafeBytes(of: value) { (buffer: UnsafeRawBufferPointer) throws(TestError) -> UInt8 in
        guard let first = unsafe buffer.first else { throw .bang }
        return first
    }
}

// MARK: A3: stdlib withUnsafeMutableBytes + concrete TestError
// Result: CONFIRMED — Build Succeeded, Output: 42

func a3() throws(TestError) -> UInt8 {
    var value: UInt64 = 42
    return try withUnsafeMutableBytes(of: &value) { (buffer: UnsafeMutableRawBufferPointer) throws(TestError) -> UInt8 in
        guard let first = unsafe buffer.first else { throw .bang }
        return first
    }
}

// ============================================================================
// MARK: - Group B: Generic E — stdlib functions (production scenario)
// ============================================================================

struct Segment {
    var value: Int

    func map<T, E: Error>(_ transform: (Int) throws(E) -> T) throws(E) -> T {
        try transform(value)
    }
}

// MARK: B1: stdlib map forwarding generic E
// Result: CONFIRMED — Build Succeeded, Output: ["1", "2", "3"]

func mapSegments<T, E: Error>(
    _ segments: [Segment],
    _ transform: (Int) throws(E) -> T
) throws(E) -> [T] {
    try segments.map { (seg: Segment) throws(E) -> T in
        try seg.map(transform)
    }
}

// MARK: B2: stdlib withUnsafeBytes forwarding generic E
// Result: CONFIRMED — Build Succeeded, Output: 42

func readFirstByte<E: Error>(
    of value: UInt64,
    validate: (UInt8) throws(E) -> UInt8
) throws(E) -> UInt8 {
    try Swift.withUnsafeBytes(of: value) { (buffer: UnsafeRawBufferPointer) throws(E) -> UInt8 in
        let byte = unsafe buffer.first!
        return try validate(byte)
    }
}

// MARK: B3: stdlib withUnsafeMutableBytes forwarding generic E
// Result: CONFIRMED — Build Succeeded, Output: 42

func writeByte<E: Error>(
    to value: inout UInt64,
    writer: (UnsafeMutableRawBufferPointer) throws(E) -> Void
) throws(E) {
    try withUnsafeMutableBytes(of: &value) { (buffer: UnsafeMutableRawBufferPointer) throws(E) -> Void in
        try writer(buffer)
    }
}

// ============================================================================
// MARK: - Group C: E inference (REFUTED)
// Compiler does NOT infer throws(E) from closure body
// ============================================================================

// MARK: C1: Custom throws(E) function + implicit closure
// Result: REFUTED — "thrown expression type 'any Error' cannot be converted"
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Explicit annotation REQUIRED

extension Array {
    func myMap<T, E: Error>(_ f: (Element) throws(E) -> T) throws(E) -> [T] {
        var r: [T] = []
        for e in self { r.append(try f(e)) }
        return r
    }
}

// Does NOT compile:
// func c1() throws(TestError) -> [String] {
//     try [1, 2, 3].myMap { try transform($0) }  // FAILS: any Error inferred
// }

// WORKS with explicit annotation:
func c1_explicit() throws(TestError) -> [String] {
    try [1, 2, 3].myMap { (x: Int) throws(TestError) -> String in
        try transform(x)
    }
}

// WORKS with pre-bound closure variable:
func c1_variable() throws(TestError) -> [String] {
    let f: (Int) throws(TestError) -> String = { try transform($0) }
    return try [1, 2, 3].myMap(f)
}

// ============================================================================
// MARK: - Execute
// ============================================================================

print("=== Typed Throws stdlib Audit — Swift 6.2.4 ===\n")

print("--- Group A: Concrete TestError ---")
print("A1 (stdlib map + concrete):")
do { print("  Result: \(try a1())") } catch { print("  Error: \(error)") }

print("A2 (stdlib withUnsafeBytes + concrete):")
do { print("  Result: \(try a2())") } catch { print("  Error: \(error)") }

print("A3 (stdlib withUnsafeMutableBytes + concrete):")
do { print("  Result: \(try a3())") } catch { print("  Error: \(error)") }

print("\n--- Group B: Generic E ---")
print("B1 (stdlib map forwarding generic E):")
let segs = [Segment(value: 1), Segment(value: 2), Segment(value: 3)]
do {
    let result: [String] = try mapSegments(segs) { (x: Int) throws(TestError) -> String in
        try transform(x)
    }
    print("  Result: \(result)")
} catch {
    print("  Error: \(error)")
}

print("B2 (stdlib withUnsafeBytes forwarding generic E):")
do {
    let result = try readFirstByte(of: 42) { (byte: UInt8) throws(TestError) -> UInt8 in
        guard byte > 0 else { throw .bang }
        return byte
    }
    print("  Result: \(result)")
} catch {
    print("  Error: \(error)")
}

print("B3 (stdlib withUnsafeMutableBytes forwarding generic E):")
do {
    var val: UInt64 = 0
    try writeByte(to: &val) { (buffer: UnsafeMutableRawBufferPointer) throws(TestError) -> Void in
        unsafe buffer[0] = 42
    }
    print("  Result: \(val)")
} catch {
    print("  Error: \(error)")
}

print("\n--- Group C: E inference ---")
print("C1 explicit (explicit annotation):")
do { print("  Result: \(try c1_explicit())") } catch { print("  Error: \(error)") }

print("C1 variable (closure variable):")
do { print("  Result: \(try c1_variable())") } catch { print("  Error: \(error)") }

print("\nDone.")
