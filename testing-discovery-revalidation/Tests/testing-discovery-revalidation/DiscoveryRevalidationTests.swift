// MARK: - Swift Testing Discovery Revalidation
// Purpose: Revalidate whether backticked test names, nested suites, and generic
//          nesting are discovered by `swift test` in Swift 6.2.4
// Prior:   suite-discovery-generic-extension (Swift 6.2.3, 2026-01-28)
//          confirmed generic nesting NOT discovered
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform:  macOS 26.0 (arm64)
// Date:      2026-03-20
//
// Result:   PARTIALLY RESOLVED
//   V1 — Backticked function names:         DISCOVERED ✅ (passes)
//   V2 — Nested non-generic suites:         DISCOVERED ✅ (passes)
//   V3a — Generic specialization (alias):   NOT DISCOVERED ❌ (still broken)
//   V3b — Generic specialization (direct):  NOT DISCOVERED ❌ (still broken)
//   V4 — Backticked suite names:            DISCOVERED ✅ (passes)
//   V5 — Deep nesting (3 levels):           DISCOVERED ✅ (passes)
//   V6 — Combined nested + backticked:      DISCOVERED ✅ (passes)
//
// Evidence: `swift test list` output:
//   testing_discovery_revalidation.BacktickedFunctionNames/`another backticked name with special chars 123`()
//   testing_discovery_revalidation.BacktickedFunctionNames/`backticked test name is discovered`()
//   testing_discovery_revalidation.Container/Tests/`combined nested and backticked`()
//   testing_discovery_revalidation.LevelA/LevelB/LevelC/Tests/`deeply nested test is discovered`()
//   testing_discovery_revalidation.Outer/Inner/`nested suite test is discovered`()
//   testing_discovery_revalidation.`Backticked Suite Name`/`test inside backticked suite`()
//   (V3a Pointer<Int>/Arithmetic and V3b Tagged<String,Int>/DirectTests ABSENT)
//
// Conclusion: Backticked names (both functions and suites), non-generic nesting,
//   and deep nesting all work perfectly in Swift 6.2.4. The ONLY remaining
//   limitation is @Suite/@Test in extensions of generic type specializations
//   (swiftlang/swift-testing#1508), which remains broken.

import Testing

// MARK: - Setup

struct Tagged<Tag, RawValue> {
    var rawValue: RawValue
}

typealias Pointer<T> = Tagged<T, Int>

// MARK: - V1: Backticked function names
// Hypothesis: `swift test` discovers @Test func `backticked name`()
// Result: CONFIRMED — both discovered and pass

@Suite
struct BacktickedFunctionNames {
    @Test
    func `backticked test name is discovered`() {
        #expect(1 + 1 == 2)
    }

    @Test
    func `another backticked name with special chars 123`() {
        #expect(2 + 2 == 4)
    }
}

// MARK: - V2: Nested suites (non-generic)
// Hypothesis: Nested @Suite inside non-generic @Suite is discovered
// Result: CONFIRMED — discovered and passes

enum Outer {
    @Suite
    struct Inner {
        @Test
        func `nested suite test is discovered`() {
            #expect(3 + 3 == 6)
        }
    }
}

// MARK: - V3: Generic nesting (re-test from prior experiment)
// Hypothesis: @Suite in extension of generic specialization is NOT discovered
// Prior result: CONFIRMED not discovered in Swift 6.2.3
// Result: STILL NOT DISCOVERED in Swift 6.2.4 — both variants absent from `swift test list`

extension Pointer<Int> {
    @Suite
    struct Arithmetic {
        @Test
        func `generic specialization via typealias`() {
            #expect(4 + 4 == 8)
        }
    }
}

extension Tagged<String, Int> {
    @Suite
    struct DirectTests {
        @Test
        func `direct concrete specialization`() {
            #expect(5 + 5 == 10)
        }
    }
}

// MARK: - V4: Backticked suite names
// Hypothesis: @Suite struct `My Suite` is discovered
// Result: CONFIRMED — discovered and passes

@Suite
struct `Backticked Suite Name` {
    @Test
    func `test inside backticked suite`() {
        #expect(6 + 6 == 12)
    }
}

// MARK: - V5: Deep nesting (3+ levels)
// Hypothesis: A.B.C.Tests with 3+ nesting levels is discovered
// Result: CONFIRMED — discovered and passes (LevelA/LevelB/LevelC/Tests)

enum LevelA {
    enum LevelB {
        enum LevelC {
            @Suite
            struct Tests {
                @Test
                func `deeply nested test is discovered`() {
                    #expect(7 + 7 == 14)
                }
            }
        }
    }
}

// MARK: - V6: Combined — backticked names inside nested non-generic types
// Hypothesis: Backticked function names inside nested suites are discovered
// Result: CONFIRMED — discovered and passes

enum Container {
    @Suite
    struct Tests {
        @Test
        func `combined nested and backticked`() {
            #expect(8 + 8 == 16)
        }
    }
}
