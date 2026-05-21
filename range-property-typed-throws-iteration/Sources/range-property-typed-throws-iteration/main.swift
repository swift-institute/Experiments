// MARK: - Range Property Typed-Throws Iteration
// Purpose: Empirically validate that the Property-accessor pattern on
//          Swift.Range escapes stdlib Sequence.forEach overload competition
//          for typed throws, mirroring how Vector.ForEach uses Property to
//          achieve the same.
//
// Hypothesis: Adding a `range.iterate` verb-as-property whose
//             callAsFunction<E>(...) throws(E) is declared on Property
//             selects the institute typed-throws path AND preserves the
//             closure's typed-throws shape, WITHOUT competing with stdlib
//             `Range.forEach` for overload resolution.
//
// Prior failure (Phase A of Item B Option (a)):
//   extension Swift.Range { public func forEach<E>(...) throws(E) { ... } }
//   was unselectable on Range<Int> — stdlib's rethrows Sequence.forEach
//   wins overload resolution at typed-throws call sites and erases
//   throws(E) to any Error.
//
// Toolchain: Apple Swift 6.3.1
// Platform: macOS 26 (arm64)
// Date: 2026-05-17
//
// Blog: BLOG-IDEA-104 "Overloading by member kind: coexisting with the
//       standard library" — Blog/Draft/overloading-by-member-kind.md
//
// Result: CONFIRMED — Property-accessor pattern (range.iterate{...})
//   escapes stdlib Sequence.forEach overload competition. P1–P7 all PASS
//   under both debug and release in cross-module configuration. P8
//   confirmed by Package.swift building under the institute's ecosystem
//   swiftSettings (ExistentialAny, InternalImportsByDefault,
//   MemberImportVisibility, NonisolatedNonsendingByDefault).
//   Negative control (Sources/NegativeControl) confirms the prior failure
//   mode is reproducible: stdlib Range.forEach with throws(E) closure
//   produces `error: thrown expression type 'any Error' cannot be converted
//   to error type 'NegError'` — empirically proving the Property pattern
//   is escaping a real competition rather than being preferred for
//   unrelated reasons.
// Status: CONFIRMED (as of Swift 6.3.1)

internal import RangeIterateAdapter  // adapter lives in sibling library target — cross-module per [EXP-017]

// MARK: - Test harness (inline; main.swift runs on MainActor)

enum MyError: Swift.Error, Equatable {
    case foo
    case bar(Int)
}

var failures: [String] = []

// MARK: - P1: range.iterate { ... throws(MyError) } compiles + runs

do {
    do throws(MyError) {
        var collected: [Int] = []
        try (0..<3).iterate { (i: Int) throws(MyError) in
            collected.append(i)
        }
        if collected == [0, 1, 2] {
            print("P1 PASS (collected = \(collected))")
        } else {
            print("P1 FAIL (collected = \(collected))")
            failures.append("P1")
        }
    } catch {
        print("P1 FAIL (unexpected throw)")
        failures.append("P1")
    }
}

// MARK: - P2 / P5: closure error type inferred as MyError + typed propagation

do {
    do throws(MyError) {
        try (0..<5).iterate { (i: Int) throws(MyError) in
            if i == 3 { throw .bar(i) }
        }
        print("P2/P5 FAIL (expected throw never fired)")
        failures.append("P2/P5")
    } catch {
        let e: MyError = error  // typed catch — error is MyError, not any Error
        switch e {
        case .bar(let n) where n == 3:
            print("P2/P5 PASS (typed throw propagated as MyError.bar(3))")
        default:
            print("P2/P5 FAIL (wrong case: \(e))")
            failures.append("P2/P5")
        }
    }
}

// MARK: - P3: typed catch binds MyError directly

do {
    do throws(MyError) {
        try (0..<2).iterate { (_: Int) throws(MyError) in
            throw .foo
        }
        print("P3 FAIL (expected throw)")
        failures.append("P3")
    } catch {
        let e: MyError = error  // would fail to compile if `error` were `any Error`
        if e == .foo {
            print("P3 PASS (caught .foo)")
        } else {
            print("P3 FAIL (caught \(e))")
            failures.append("P3")
        }
    }
}

// MARK: - P4: stdlib Range.forEach still works unchanged

do {
    var stdlibCollected: [Int] = []
    (0..<3).forEach { stdlibCollected.append($0) }
    if stdlibCollected == [0, 1, 2] {
        print("P4 PASS (stdlib forEach output = \(stdlibCollected))")
    } else {
        print("P4 FAIL (stdlib forEach output = \(stdlibCollected))")
        failures.append("P4")
    }
}

// MARK: - P6 / P7: cross-Bound generic case

do {
    do throws(MyError) {
        var ints32: [Int32] = []
        try (Int32(0)..<Int32(3)).iterate { (i: Int32) throws(MyError) in
            ints32.append(i)
        }
        if ints32 == [0, 1, 2] {
            print("P6/P7-Int32 PASS (Int32 ints = \(ints32))")
        } else {
            print("P6/P7-Int32 FAIL (Int32 ints = \(ints32))")
            failures.append("P6/P7-Int32")
        }
    } catch {
        print("P6/P7-Int32 FAIL (unexpected throw)")
        failures.append("P6/P7-Int32")
    }
}

do {
    do throws(MyError) {
        var uints: [UInt] = []
        try (UInt(0)..<UInt(3)).iterate { (i: UInt) throws(MyError) in
            uints.append(i)
        }
        if uints == [0, 1, 2] {
            print("P6/P7-UInt PASS (UInt uints = \(uints))")
        } else {
            print("P6/P7-UInt FAIL (UInt uints = \(uints))")
            failures.append("P6/P7-UInt")
        }
    } catch {
        print("P6/P7-UInt FAIL (unexpected throw)")
        failures.append("P6/P7-UInt")
    }
}

// MARK: - P8: institute swiftSettings compatibility
// Confirmed by Package.swift carrying ExistentialAny + InternalImportsByDefault
// + MemberImportVisibility + NonisolatedNonsendingByDefault + this file
// building under -swift-version 6.

// MARK: - Negative control (commented; toggle on to confirm refutation)
//
// Without .iterate, typed throws against stdlib forEach should be
// rejected: the closure body's `throws(MyError)` is erased to `any Error`
// because stdlib's Sequence.forEach is `rethrows`, not `throws(E)`. Catch
// binding `let e: MyError = error` then fails to compile with:
//
//   error: cannot convert value of type 'any Error' to specified type 'MyError'
//
// do throws(MyError) {
//     try (0..<3).forEach { (i: Int) throws(MyError) in
//         if i == 1 { throw .foo }
//     }
// } catch {
//     let _: MyError = error  // ← rejected
// }

// MARK: - Summary

if failures.isEmpty {
    print("=== ALL PASS — Property-accessor pattern escapes stdlib overload competition ===")
} else {
    print("=== FAILURES: \(failures.joined(separator: ", ")) ===")
}
