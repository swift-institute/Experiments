// MARK: - @Suite Discovery in Generic Type Extensions
// Purpose: Determine if Swift Testing discovers @Suite structs nested in
//          extensions of concrete generic type specializations
// Hypothesis: Swift Testing CANNOT discover @Suite structs defined via
//             `extension GenericType<ConcreteArg> { @Suite struct S {} }`
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — concrete generic specializations compile but are not
//         discovered. Unconstrained generic extensions do not even compile.
//         Only non-generic type extensions are discovered.
// Evidence: `swift test list` output:
//   suite_discovery_generic_extension.Namespace/Tests/baseline()
//   suite_discovery_generic_extension.PlainStruct/Tests/control()
//   (V2, V5 absent despite successful compilation)
// Date: 2026-01-28

import Testing

// MARK: - Setup: Generic type + typealias (mirrors Pointer<T> = Tagged<T, Address>)

struct Tagged<Tag, RawValue> {
    var rawValue: RawValue
}

typealias Pointer<T> = Tagged<T, Int>

struct PlainStruct {}

enum Namespace {}

// MARK: - Variant 1: Non-generic enum (baseline)
// Hypothesis: @Suite in extension of non-generic enum IS discovered
// Result: CONFIRMED — discovered and passes

extension Namespace {
    @Suite
    struct Tests {
        @Test("V1: non-generic enum extension test")
        func baseline() {
            #expect(1 + 1 == 2)
        }
    }
}

// MARK: - Variant 2: Concrete specialization of generic struct via typealias
// Hypothesis: @Suite in extension of Pointer<Int> (= Tagged<Int, Int>) compiles
//             but is NOT discovered by swift test
// Result: CONFIRMED — compiles, but NOT discovered by `swift test list`

extension Pointer<Int> {
    @Suite
    struct Arithmetic {
        @Test("V2: generic specialization via typealias test")
        func fromSpecialization() {
            #expect(2 + 2 == 4)
        }
    }
}

// MARK: - Variant 3: Non-generic struct (control)
// Hypothesis: @Suite in extension of non-generic struct IS discovered
// Result: CONFIRMED — discovered and passes

extension PlainStruct {
    @Suite
    struct Tests {
        @Test("V3: non-generic struct extension test")
        func control() {
            #expect(3 + 3 == 6)
        }
    }
}

// MARK: - Variant 4: Unconstrained generic extension
// Hypothesis: @Suite in unconstrained extension of Tagged — DOES NOT COMPILE
// Result: CONFIRMED (does not compile) — @Test/@Suite macros expand to
//         `static let` properties. Nested types in `extension Tagged` inherit
//         the open generic context, and Swift forbids static stored properties
//         in generic types.
// Evidence: error: static stored properties not supported in generic types
//           Command: swift test list
//
// (Code removed — does not compile)

// MARK: - Variant 5: Direct concrete specialization (no typealias)
// Hypothesis: @Suite in extension of Tagged<String, Int> directly — same as V2
//             but without typealias indirection
// Result: CONFIRMED — compiles, but NOT discovered by `swift test list`

extension Tagged<String, Int> {
    @Suite
    struct DirectTests {
        @Test("V5: direct concrete specialization test")
        func fromDirect() {
            #expect(5 + 5 == 10)
        }
    }
}

// MARK: - Results Summary
// V1 (non-generic enum):              CONFIRMED — discovered, passes
// V2 (specialization via typealias):  CONFIRMED — compiles, NOT discovered
// V3 (non-generic struct):            CONFIRMED — discovered, passes
// V4 (unconstrained generic):         CONFIRMED — does not compile
// V5 (direct specialization):         CONFIRMED — compiles, NOT discovered
//
// Conclusion: @Suite/@Test in extensions of generic types (whether specialized
// or not) CANNOT be used for test discovery. The @Test macro expands to static
// stored properties, which either:
//   (a) fail to compile (unconstrained generic context), or
//   (b) compile but are invisible to the test runner (concrete specialization)
//
// Workaround: Use a top-level non-generic struct or enum as the suite container.
