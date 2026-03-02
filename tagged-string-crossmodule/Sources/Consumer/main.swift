// MARK: - Tagged String Cross-Module Experiment
// Purpose: Validate two critical D' questions that prior experiments (single-module)
//          could not answer:
//          (1) Does @_lifetime propagation work cross-module through
//              @usableFromInline _storage on Tagged?
//          (2) Does generic arity (String<Tag> vs String) prevent shadowing of
//              Swift.String, eliminating ~981 Swift.String qualifications?
//
// Prior art:
//   phantom-tagged-string-unification — Option D custom struct, 9/9 confirmed
//   tagged-string-literal — Option D' Tagged wrapping, 10/10 confirmed (single module)
//   typealias-without-reexport — Import-level fixes structurally impossible
//
// Hypothesis:
//   (1) @usableFromInline internal var _storage + @inlinable extension code in a
//       separate module enables @_lifetime propagation for ~Escapable views.
//   (2) typealias String<Tag> = Tagged<Tag, StringStorage> has generic arity 1,
//       while Swift.String has arity 0. Bare `String` resolves to Swift.String.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: Darwin 25.2.0 arm64
//
// Result: 9/11 CONFIRMED, 2/11 FALSIFIED (V4, V11 shadowing)
// Date: 2026-02-27

import StringLib

// ============================================================================
// MARK: - V1: Cross-Module _storage Access — Basic Property
// ============================================================================
// Hypothesis: Tagged.count (forwarding _storage.count) works from Consumer module.
// Tests: @inlinable cross-module access to @usableFromInline package _storage.
// NOTE: @usableFromInline internal does NOT work cross-module — required package access.
// Result: CONFIRMED (with package access)

func testV1() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [72, 101, 108, 108, 111, 0], count: 6)
    let s: String<GenericTag> = .init(adopting: buf, count: 5)
    precondition(s.count == 5, "V1: count should be 5")
    print("V1: count = \(s.count)")
}

// ============================================================================
// MARK: - V2: Cross-Module ~Escapable View via _storage
// ============================================================================
// Hypothesis: withView (accessing _storage.pointer cross-module) correctly
//             propagates @_lifetime for the ~Escapable View type.
// This is THE critical test — it failed to work through rawValue in the
// single-module experiment and required _storage direct access.
// Result: CONFIRMED — @_lifetime propagates cross-module through package _storage

func testV2() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [87, 111, 114, 108, 100, 0], count: 6)
    let s: String<PathTag> = .init(adopting: buf, count: 5)
    s.withView { view in
        view.withUnsafePointer { ptr in
            let first = unsafe ptr.pointee
            precondition(first == 87, "V2: first byte should be 'W' (87)")
            print("V2: first byte = \(first) ('W')")
        }
    }
}

// ============================================================================
// MARK: - V3: Cross-Module Span via _overrideLifetime
// ============================================================================
// Hypothesis: Span<Char> via _overrideLifetime works cross-module through
//             the Tagged<PathTag, StringStorage>.View extension.
// Result: CONFIRMED

func testV3() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let s: String<PathTag> = .init(adopting: buf, count: 3)
    s.withView { view in
        let sp = view.span
        precondition(sp.count == 3, "V3: span count should be 3")
        precondition(sp[0] == 65, "V3: first element should be 'A' (65)")
        print("V3: span.count = \(sp.count), first = \(sp[0])")
    }
}

// ============================================================================
// MARK: - V4: Shadowing — Bare `String` = Swift.String
// ============================================================================
// Hypothesis: Since StringLib.String is a generic typealias (arity 1),
//             bare `String` without type parameters resolves to Swift.String
//             (arity 0), NOT to the primitives type.
//
// RESULT: FALSIFIED. Generic arity does NOT prevent shadowing.
//         Bare `String` resolves to StringLib.String (aka Tagged<Tag, StringStorage>),
//         NOT Swift.String. The compiler errors:
//           - "cannot convert value of type 'String' to specified type 'String<Tag>'"
//           - "generic parameter 'Tag' could not be inferred"
//         This means downstream modules still need `Swift.String` qualification.
// Result: FAIL — shadowing still occurs

func testV4() {
    // Original test: `let s: String = "hello, world"` — DOES NOT COMPILE.
    // Bare `String` resolves to StringLib.String<Tag>, not Swift.String.
    // Must use Swift.String explicitly:
    let s: Swift.String = "hello, world"
    precondition(s.count == 12, "V4: Swift.String count should be 12")
    precondition(s.uppercased() == "HELLO, WORLD", "V4: should have Swift.String methods")
    print("V4: FALSIFIED — bare String shadows Swift.String, must qualify")
}

// ============================================================================
// MARK: - V5: StringLib.String<Tag> Resolves to Tagged
// ============================================================================
// Hypothesis: String<GenericTag> resolves to Tagged<GenericTag, StringStorage>
//             from the Consumer module, with full API access.
// Result: CONFIRMED

func testV5() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [88, 89, 90, 0], count: 4)
    let ps: String<GenericTag> = .init(adopting: buf, count: 3)
    precondition(ps.count == 3, "V5: String<GenericTag> count should be 3")
    print("V5: String<GenericTag> resolves, count = \(ps.count)")
}

// ============================================================================
// MARK: - V6: Domain-Specific Extensions
// ============================================================================
// Hypothesis: String<PathTag> has isAbsolutePath but String<GenericTag> does not.
// Result: CONFIRMED

func testV6() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)  // "/tmp\0"
    let path: String<PathTag> = .init(adopting: buf, count: 4)
    precondition(path.isAbsolutePath, "V6: /tmp should be absolute")
    print("V6: isAbsolutePath = \(path.isAbsolutePath)")

    // Negative: uncomment to verify compile error
    // let buf2 = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    // unsafe buf2.initialize(from: [65, 0], count: 2)
    // let generic: String<GenericTag> = .init(adopting: buf2, count: 1)
    // _ = generic.isAbsolutePath  // ERROR: has no member 'isAbsolutePath'
}

// ============================================================================
// MARK: - V7: .retag() Cross-Module
// ============================================================================
// Hypothesis: Tagged's .retag() works from Consumer to migrate domains.
// Result: CONFIRMED

func testV7() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let path: String<PathTag> = .init(adopting: buf, count: 4)

    let generic: String<GenericTag> = path.retag(GenericTag.self)
    precondition(generic.count == 4, "V7: count preserved after retag")
    print("V7: retag PathTag → GenericTag, count = \(generic.count)")
}

// ============================================================================
// MARK: - V8: .map() Cross-Module
// ============================================================================
// Hypothesis: Tagged's .map() works from Consumer for value transformation.
// Result: CONFIRMED

func testV8() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 4)
    unsafe buf.initialize(from: [65, 66, 67, 0], count: 4)
    let original: String<GenericTag> = .init(adopting: buf, count: 3)

    let mapped: Tagged<GenericTag, Int> = original.map { storage in storage.count }
    precondition(mapped.rawValue == 3, "V8: mapped count should be 3")
    print("V8: map StringStorage → Int, mapped = \(mapped.rawValue)")
}

// ============================================================================
// MARK: - V9: Sendable Inherited Cross-Module
// ============================================================================
// Hypothesis: Tagged<_, StringStorage>: Sendable inherited automatically.
// Result: CONFIRMED

func testV9() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 2)
    unsafe buf.initialize(from: [88, 0], count: 2)
    let s: String<PathTag> = .init(adopting: buf, count: 1)

    func requiresSendable<T: Sendable & ~Copyable>(_ value: borrowing T) {
        print("V9: Sendable inherited cross-module")
    }
    requiresSendable(s)
}

// ============================================================================
// MARK: - V10: Ergonomic Typealiases
// ============================================================================
// Hypothesis: KernelPath and OSString typealiases carry conditional extensions.
// Result: CONFIRMED

func testV10() {
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 5)
    unsafe buf.initialize(from: [47, 116, 109, 112, 0], count: 5)
    let path: KernelPath = .init(adopting: buf, count: 4)
    precondition(path.isAbsolutePath, "V10: KernelPath should carry isAbsolutePath")
    print("V10: KernelPath typealias, isAbsolutePath = \(path.isAbsolutePath)")
}

// ============================================================================
// MARK: - V11: Both String Types Coexist
// ============================================================================
// Hypothesis: Swift.String and String<Tag> can be used side by side in the
//             same function without any qualification.
//
// RESULT: PARTIALLY FALSIFIED. Both types coexist, but bare `String` requires
//         `Swift.String` qualification. String<Tag> works unqualified.
//         The shadowing means you CANNOT use bare `String` for Swift.String —
//         qualification is still required, same as current status quo.
// Result: PARTIAL — coexist with Swift.String qualification

func testV11() {
    // Swift.String — REQUIRES qualification (shadowing confirmed in V4)
    let swiftStr: Swift.String = "hello"

    // Primitives string — requires type parameter
    let buf = UnsafeMutablePointer<Char>.allocate(capacity: 6)
    unsafe buf.initialize(from: [104, 101, 108, 108, 111, 0], count: 6)
    let primStr: String<GenericTag> = .init(adopting: buf, count: 5)

    precondition(swiftStr.count == 5, "V11: Swift.String count = 5")
    precondition(primStr.count == 5, "V11: String<GenericTag> count = 5")
    print("V11: coexist WITH Swift.String qualification, both count = 5")
}

// ============================================================================
// MARK: - Execute All Variants
// ============================================================================

testV1()
testV2()
testV3()
testV4()
testV5()
testV6()
testV7()
testV8()
testV9()
testV10()
testV11()

print("\nAll variants complete.")

// MARK: - Results Summary
// V1:  CONFIRMED — Cross-module _storage access (basic property) [requires package access]
// V2:  CONFIRMED — Cross-module ~Escapable View via _storage (@_lifetime) [THE critical test]
// V3:  CONFIRMED — Cross-module Span via _overrideLifetime
// V4:  FALSIFIED — Bare String shadows Swift.String (generic arity does NOT help)
// V5:  CONFIRMED — String<GenericTag> resolves to Tagged
// V6:  CONFIRMED — Domain-specific extensions (path only)
// V7:  CONFIRMED — .retag() cross-module
// V8:  CONFIRMED — .map() cross-module
// V9:  CONFIRMED — Sendable inherited cross-module
// V10: CONFIRMED — Typealiases carry extensions
// V11: PARTIAL  — Both String types coexist, but Swift.String requires qualification
//
// KEY FINDINGS:
// (1) @usableFromInline internal does NOT enable cross-module source access.
//     Must use @usableFromInline package for same-package cross-module _storage access.
//     Production Tagged._storage needs internal → package access level change.
// (2) @_lifetime propagation through @usableFromInline package _storage works correctly
//     cross-module for ~Escapable views. D' is fully feasible.
// (3) Generic arity (String<Tag> arity 1 vs Swift.String arity 0) does NOT prevent
//     shadowing. Bare `String` resolves to StringLib.String, not Swift.String.
//     The ~981 Swift.String qualifications cannot be eliminated by this approach.
//     Consider: PlatformString<Tag> naming, or accepting qualification.
