// MARK: - Copyable Overload Resolution with ~Copyable
// Purpose: Validate whether a Copyable extension method can call the ~Copyable
//          version with the same name, or whether Swift's overload resolution
//          causes infinite recursion. Test alternatives to _ prefix indirection.
//
// Hypothesis: A method in `where Element: Copyable` calling `self.foo()` will
//             resolve to itself (the Copyable overload), not the ~Copyable
//             version, causing infinite recursion.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — all four hypotheses validated
// Date: 2026-02-12
//
// Results Summary:
// V1: CONFIRMED — Copyable self.mutate() recurses infinitely (compiler warns, runtime confirms)
// V2: CONFIRMED — _ prefix breaks recursion, Copyable overload calls ~Copyable _doWork()
// V3: CONFIRMED — Static methods avoid the problem entirely
// V4: CONFIRMED — ~Copyable context always dispatches to ~Copyable overload,
//                  even when Element is Copyable at runtime (Int)
//
// Implications:
// - A Copyable overload CANNOT call the ~Copyable version by the same name.
// - Two viable patterns: _ prefix instance methods (V2) or static methods (V3).
// - A ~Copyable extension method will NEVER dispatch to a Copyable overload,
//   meaning consumers in ~Copyable context don't get CoW-safe overloads
//   automatically — Copyable overloads at the consumer level are still needed.

// ============================================================================
// MARK: - Minimal Reproduction Type
// ============================================================================

struct Container<Element: ~Copyable>: ~Copyable {
    var value: Int = 0
}

extension Container: Copyable where Element: Copyable {}

// ============================================================================
// MARK: - Variant 1: Same-name overload, Copyable calls self
// Hypothesis: Calling mutate() from the Copyable extension resolves to itself
// Result: CONFIRMED — infinite recursion (compiler warning + runtime stack overflow)
// Evidence: warning: function call causes an infinite recursion
//           Output: "Copyable mutate() entered" repeated until stack overflow
// ============================================================================

extension Container where Element: ~Copyable {
    mutating func mutate() {
        value += 1
        print("  ~Copyable mutate() called, value = \(value)")
    }
}

extension Container where Element: Copyable {
    mutating func mutate() {
        print("  Copyable mutate() entered")
        // This resolves to self (Copyable overload), NOT the ~Copyable version.
        self.mutate()
    }
}

// ============================================================================
// MARK: - Variant 2: _ prefix indirection (current approach)
// Hypothesis: _ prefix breaks recursion
// Result: CONFIRMED — Copyable doWork() calls _doWork() which resolves to ~Copyable
// Evidence: Output: "Copyable doWork() entered" → "_doWork() called, value = 10"
// ============================================================================

extension Container where Element: ~Copyable {
    mutating func _doWork() {
        value += 10
        print("  _doWork() called, value = \(value)")
    }

    mutating func doWork() {
        _doWork()
        print("  ~Copyable doWork() wrapper, value = \(value)")
    }
}

extension Container where Element: Copyable {
    mutating func doWork() {
        print("  Copyable doWork() entered")
        _doWork()
        print("  Copyable doWork() done, value = \(value)")
    }
}

// ============================================================================
// MARK: - Variant 3: Static method delegation (Ring/Linear pattern)
// Hypothesis: Static methods avoid the recursion problem entirely
// Result: CONFIRMED — static _performWork() called correctly from Copyable overload
// Evidence: Output: "Copyable work() entered" → "static _performWork() called, value = 100"
// ============================================================================

extension Container where Element: ~Copyable {
    static func _performWork(value: inout Int) {
        value += 100
        print("  static _performWork() called, value = \(value)")
    }

    mutating func work() {
        Container._performWork(value: &value)
        print("  ~Copyable work() wrapper, value = \(value)")
    }
}

extension Container where Element: Copyable {
    mutating func work() {
        print("  Copyable work() entered")
        Container._performWork(value: &value)
        print("  Copyable work() done, value = \(value)")
    }
}

// ============================================================================
// MARK: - Variant 4: Can ~Copyable context call site resolve Copyable overload?
// Hypothesis: A method in where Element: ~Copyable always calls the ~Copyable
//             overload, even when Element is actually Copyable at runtime.
// Result: CONFIRMED — ~Copyable caller() dispatches to ~Copyable mutate(),
//         NOT Copyable mutate(), even though Element is Int (Copyable).
// Evidence: Output: "~Copyable mutate() called, value = 1"
//           (NOT "Copyable mutate() entered")
// ============================================================================

extension Container where Element: ~Copyable {
    mutating func caller() {
        print("  ~Copyable caller() — about to call mutate()")
        self.mutate()
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("=== Variant 2: _ prefix indirection ===")
var c2 = Container<Int>()
c2.doWork()
// Output:
//   Copyable doWork() entered
//   _doWork() called, value = 10
//   Copyable doWork() done, value = 10

print("")
print("=== Variant 3: Static method delegation ===")
var c3 = Container<Int>()
c3.work()
// Output:
//   Copyable work() entered
//   static _performWork() called, value = 100
//   Copyable work() done, value = 100

print("")
print("=== Variant 4: ~Copyable caller with Copyable Element ===")
var c4 = Container<Int>()
c4.caller()
// Output:
//   ~Copyable caller() — about to call mutate()
//   ~Copyable mutate() called, value = 1

// Variant 1 (same-name recursion) intentionally omitted from execution —
// compiler warning confirms infinite recursion, runtime confirms stack overflow.
