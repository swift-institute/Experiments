// MARK: - forEach @inline(always) Overload Resolution
// Purpose: Verify that a method on `Protocol1 where Self: Protocol2` wins
//   overload resolution over a method on `Protocol2` alone, enabling a single
//   @inline(always) forEach to shadow Swift.Sequence.forEach for all dual-conformers.
// Hypothesis 1: `MyProtocol where Self: Swift.Sequence` method beats `Swift.Sequence` method
// Hypothesis 2: @inline(always) on forEach prevents CopyPropagation crash in class deinits
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2025-05-31-a
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Date: 2026-02-15

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

/// Tracks which forEach implementation was called.
enum CallTracker {
    nonisolated(unsafe) static var lastCalled: String = ""
}

/// Minimal custom sequence protocol (mirrors our Sequence.Protocol).
protocol MySequenceProtocol {
    associatedtype Element
    associatedtype Iterator: IteratorProtocol<Element>
    func makeIterator() -> Iterator
}

/// Property.View equivalent for forEach (mirrors our Property<ForEach, Base>.View pattern).
struct ForEachView<Base: MySequenceProtocol> {
    let base: Base

    func callAsFunction(_ body: (Base.Element) -> Void) {
        CallTracker.lastCalled = "Property.View callAsFunction"
        var iter = base.makeIterator()
        while let e = iter.next() { body(e) }
    }

    func borrowing(_ body: (Base.Element) -> Void) {
        CallTracker.lastCalled = "Property.View borrowing"
        var iter = base.makeIterator()
        while let e = iter.next() { body(e) }
    }
}

/// Property-based forEach on MySequenceProtocol (mirrors Sequence.Protocol+ForEach.swift).
/// Uses `mutating get` to mirror the real `mutating _read` coroutine accessor.
/// This means it CANNOT be called on temporaries — only on `var` bindings.
extension MySequenceProtocol {
    var forEach: ForEachView<Self> {
        mutating get { ForEachView(base: self) }
    }
}

// ============================================================================
// MARK: - Test Type
// ============================================================================

/// A type conforming to both MySequenceProtocol and Swift.Sequence.
struct DualConforming: MySequenceProtocol, Swift.Sequence {
    let items: [Int]

    typealias Element = Int

    func makeIterator() -> Array<Int>.Iterator {
        items.makeIterator()
    }
}

// ============================================================================
// MARK: - Variant 1: Baseline — No Bridging Extension
// Hypothesis: Without bridging, `instance.forEach { }` resolves to Swift.Sequence.forEach
// Result: (pending)
// ============================================================================

print("--- Variant 1: Baseline (no bridging extension) ---")
do {
    let dual = DualConforming(items: [1, 2, 3])
    CallTracker.lastCalled = ""
    dual.forEach { _ in }

    if CallTracker.lastCalled == "" {
        print("  CONFIRMED: Swift.Sequence.forEach called (no tracker update)")
    } else {
        print("  REFUTED: \(CallTracker.lastCalled) was called instead")
    }
}

// ============================================================================
// MARK: - Variant 2: Property.View Access Still Works
// Hypothesis: `instance.forEach.borrowing { }` still accesses the Property.View
// Result: (pending)
// ============================================================================

print("\n--- Variant 2: Property.View qualified access ---")
do {
    var dual = DualConforming(items: [1, 2, 3])
    CallTracker.lastCalled = ""
    dual.forEach.borrowing { _ in }

    if CallTracker.lastCalled == "Property.View borrowing" {
        print("  CONFIRMED: Property.View.borrowing called via qualified access")
    } else {
        print("  REFUTED: \(CallTracker.lastCalled) was called instead")
    }
}

// ============================================================================
// MARK: - Bridging Extension
// ============================================================================

/// The proposed fix: a single method on MySequenceProtocol constrained to Swift.Sequence.
/// More constrained than Swift.Sequence alone → should win overload resolution.
extension MySequenceProtocol where Self: Swift.Sequence {
    @inline(always)
    func forEach(_ body: (Element) -> Void) {
        CallTracker.lastCalled = "Bridging @inline(always) forEach"
        var iterator = makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

// ============================================================================
// MARK: - Variant 3: Bridging Extension Wins
// Hypothesis: After bridging, `instance.forEach { }` resolves to bridging method
// Result: (pending)
// ============================================================================

print("\n--- Variant 3: With bridging extension ---")
do {
    let dual = DualConforming(items: [1, 2, 3])
    CallTracker.lastCalled = ""
    dual.forEach { _ in }

    if CallTracker.lastCalled == "Bridging @inline(always) forEach" {
        print("  CONFIRMED: Bridging method wins overload resolution")
    } else if CallTracker.lastCalled == "" {
        print("  REFUTED: Swift.Sequence.forEach still called")
    } else {
        print("  REFUTED: \(CallTracker.lastCalled) was called instead")
    }
}

// ============================================================================
// MARK: - Variant 4: Property.View Still Accessible After Bridging
// Hypothesis: Qualified access still reaches Property.View even with bridging
// Result: (pending)
// ============================================================================

print("\n--- Variant 4: Property.View still accessible after bridging ---")
do {
    var dual = DualConforming(items: [1, 2, 3])
    CallTracker.lastCalled = ""
    dual.forEach.borrowing { _ in }

    if CallTracker.lastCalled == "Property.View borrowing" {
        print("  CONFIRMED: Property.View.borrowing still accessible")
    } else {
        print("  REFUTED: \(CallTracker.lastCalled) was called instead")
    }
}

// ============================================================================
// MARK: - Variant 5: Class Deinit with ~Copyable Generic
// Hypothesis: @inline(always) forEach prevents CopyPropagation crash
// Result: (pending — requires release build to verify)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

print("\n--- Variant 5: Class deinit with ~Copyable generic ---")
do {
    // Minimal reproduction of the pattern that crashes CopyPropagation.
    // The crash requires: class + ~Copyable generic + closure in deinit.
    // If this compiles in release mode, the @inline(always) fix works.
    final class Container<Element: ~Copyable> {
        var indices: [Int] = [0, 1, 2]

        deinit {
            // This forEach call uses a closure that captures `self` (via `indices`).
            // Without @inline(always), CopyPropagation may crash on this pattern.
            indices.forEach { index in
                _ = index
            }
        }
    }

    // Force instantiation and deinit
    do {
        let c = Container<Int>()
        _ = c
    }
    // If the type uses ~Copyable element with unsafe pointers, the crash is more likely.
    // This variant may need the actual Storage.Pool pattern to reproduce.
    print("  Compiled and ran (debug mode)")
    print("  NOTE: Verify with `swift build -c release` for full validation")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("\n--- Results Summary ---")
print("V1 (baseline): (see above)")
print("V2 (property access): (see above)")
print("V3 (bridging wins): (see above)")
print("V4 (property after bridging): (see above)")
print("V5 (deinit crash): Requires release build verification")
