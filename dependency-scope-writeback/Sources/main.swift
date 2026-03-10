// MARK: - Dependency.Scope Writeback Verification
// Purpose: Can code inside Dependency.Scope.with() write values back
//          that the caller can read after the operation completes?
// Hypothesis: Direct value mutation is LOST (value semantics).
//             Reference type (class) mutation IS visible.
//             This determines how .timed() scope provider communicates
//             with Test.Benchmark.measure {}.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all 6 variants pass. Reference type (class) injected
//         via Dependency.Scope.with() IS visible after mutation from inside
//         the operation, including across await points and nested scopes.
//         Direct value mutation is impossible (current returns a struct copy).
//         The benchmark pattern (scope provider injects Box<Measurement?>,
//         measure {} writes to it, scope provider reads it back) works.
// Date: 2026-03-10

import Dependency_Primitives

// MARK: - Keys

// Value-type key (Int)
enum CounterKey: Dependency.Key {
    static var liveValue: Int { 0 }
}

// Reference-type key (class)
final class Box<T: Sendable>: @unchecked Sendable {
    var value: T
    init(_ value: T) { self.value = value }
}

enum BoxKey: Dependency.Key {
    static var liveValue: Box<Int> { Box(0) }
}

// Optional value key (simulates Measurement?)
enum OptionalKey: Dependency.Key {
    static var liveValue: Box<String?> { Box(nil) }
}

// MARK: - Variant 1: Direct value mutation inside operation
// Hypothesis: LOST — Dependency.Scope.current returns a copy

func variant1() {
    print("--- Variant 1: Direct value mutation ---")

    Dependency.Scope.with({ $0[CounterKey.self] = 0 }) {
        // Try to mutate from inside
        // Dependency.Scope.current[CounterKey.self] = 42
        // ^^^ This won't compile: current returns Dependency.Values (a let struct),
        //     subscript set requires `var`.
        let value = Dependency.Scope.current[CounterKey.self]
        print("  Inside: \(value)")
    }

    let after = Dependency.Scope.current[CounterKey.self]
    print("  After:  \(after)")
    print("  Verdict: Cannot even attempt — `current` is a get-only computed property returning a struct")
    print()
}

// MARK: - Variant 2: Reference type (class) injected, mutated inside
// Hypothesis: VISIBLE — both sides hold the same reference

func variant2() {
    print("--- Variant 2: Reference type mutation ---")

    let box = Box(0)

    Dependency.Scope.with({ $0[BoxKey.self] = box }) {
        // Mutate the class instance from inside
        let ref = Dependency.Scope.current[BoxKey.self]
        ref.value = 42
        print("  Inside: ref.value = \(ref.value)")
    }

    print("  After:  box.value = \(box.value)")
    let passed = box.value == 42
    print("  Verdict: \(passed ? "CONFIRMED — mutation visible" : "REFUTED — mutation lost")")
    print()
}

// MARK: - Variant 3: Optional Box (simulates Measurement? pattern)
// Hypothesis: VISIBLE — scope provider injects Box<Measurement?>(nil),
//             measure {} sets box.value = measurement

func variant3() {
    print("--- Variant 3: Optional box (benchmark pattern) ---")

    let resultBox = Box<String?>(nil)

    Dependency.Scope.with({ $0[OptionalKey.self] = resultBox }) {
        // Simulate measure {} storing its result
        let ref = Dependency.Scope.current[OptionalKey.self]
        ref.value = "measurement-data-here"
        print("  Inside: set ref.value = \(ref.value ?? "nil")")
    }

    print("  After:  resultBox.value = \(resultBox.value ?? "nil")")
    let passed = resultBox.value == "measurement-data-here"
    print("  Verdict: \(passed ? "CONFIRMED — benchmark pattern works" : "REFUTED — measurement lost")")
    print()
}

// MARK: - Variant 4: Async operation with reference type
// Hypothesis: VISIBLE — @TaskLocal preserves the scope across await points

func variant4() async {
    print("--- Variant 4: Async operation with reference type ---")

    let box = Box(0)

    await Dependency.Scope.with({ $0[BoxKey.self] = box }) {
        // Simulate async measure {}
        let ref = Dependency.Scope.current[BoxKey.self]
        // Cross an await point
        await Task.yield()
        ref.value = 99
        print("  Inside (after await): ref.value = \(ref.value)")
    }

    print("  After:  box.value = \(box.value)")
    let passed = box.value == 99
    print("  Verdict: \(passed ? "CONFIRMED — survives await" : "REFUTED — lost across await")")
    print()
}

// MARK: - Variant 5: Nested scope does NOT shadow the reference
// Hypothesis: Inner scope can access and mutate the outer scope's box
//             because the Values are inherited (copy includes the reference)

func variant5() {
    print("--- Variant 5: Nested scope access to outer reference ---")

    let box = Box(0)

    Dependency.Scope.with({ $0[BoxKey.self] = box }) {
        // Nested scope that doesn't set BoxKey
        Dependency.Scope.with({ _ in }) {
            let ref = Dependency.Scope.current[BoxKey.self]
            ref.value = 77
            print("  Inner scope: ref.value = \(ref.value)")
        }
        let ref = Dependency.Scope.current[BoxKey.self]
        print("  Outer scope after inner: ref.value = \(ref.value)")
    }

    print("  After:  box.value = \(box.value)")
    let passed = box.value == 77
    print("  Verdict: \(passed ? "CONFIRMED — nested scope inherits reference" : "REFUTED")")
    print()
}

// MARK: - Variant 6: Scope provider pattern (full simulation)
// Simulates the actual .timed() scope provider + measure {} interaction

func variant6() async {
    print("--- Variant 6: Full scope provider simulation ---")

    // Simulate Test.Benchmark.Measurement
    struct Measurement {
        let durations: [Double]
        var median: Double { durations.sorted()[durations.count / 2] }
    }

    // The "context" class that bridges scope provider ↔ measure {}
    final class BenchmarkContext: @unchecked Sendable {
        var measurement: Measurement? = nil
    }

    enum ContextKey: Dependency.Key {
        static var liveValue: BenchmarkContext? { nil }
    }

    // --- Scope provider side ---
    let context = BenchmarkContext()

    await Dependency.Scope.with({ $0[ContextKey.self] = context }) {
        // --- Test body side ---

        // Setup (not measured)
        let data = Array(0..<1000)

        // Simulate Test.Benchmark.measure {}
        func simulateMeasure(iterations: Int, body: () -> Void) {
            var durations: [Double] = []
            for _ in 0..<iterations {
                let start = ContinuousClock.now
                body()
                let elapsed = ContinuousClock.now - start
                let seconds = Double(elapsed.components.seconds)
                    + Double(elapsed.components.attoseconds) / 1e18
                durations.append(seconds)
            }
            // Store measurement on the injected context
            if let ctx = Dependency.Scope.current[ContextKey.self] {
                ctx.measurement = Measurement(durations: durations)
                print("  measure {}: stored \(durations.count) durations on context")
            }
        }

        simulateMeasure(iterations: 5) {
            _ = data.reduce(0, +)
        }
    }

    // --- Back in scope provider ---
    if let m = context.measurement {
        print("  Scope provider: read \(m.durations.count) durations, median = \(m.median)")
        print("  Verdict: CONFIRMED — full benchmark pattern works")
    } else {
        print("  Scope provider: measurement is nil")
        print("  Verdict: REFUTED — measurement not visible")
    }
    print()
}

// MARK: - Results Summary

print("=== Dependency.Scope Writeback Experiment ===\n")
variant1()
variant2()
variant3()
await variant4()
variant5()
await variant6()
print("=== Done ===")
