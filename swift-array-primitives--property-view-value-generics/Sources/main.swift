// Status: SUPERSEDED -- Property.View.Typed.Valued shipped in swift-property-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ============================================================================
// EXPERIMENT: Property.View.Typed.Valued
// ============================================================================
//
// HYPOTHESIS: Can we nest Valued inside Typed for cleaner API?
//             Property<Tag, Base>.View.Typed<Element>.Valued<n>
//
// NAMING: "Valued" parallels "Typed"
//         - Typed  → parameterized by a type
//         - Valued → parameterized by a value
//
// STATUS: CONFIRMED
//
// ============================================================================

// MARK: - Property.View.Typed.Valued structure

struct Property<Tag, Base: ~Copyable> {
    struct View: ~Copyable {
        struct Typed<Element: ~Copyable>: ~Copyable {
            struct Valued<let n: Int>: ~Copyable {
                let base: UnsafeMutablePointer<Base>

                init(_ base: UnsafeMutablePointer<Base>) {
                    unsafe self.base = base
                }
            }
        }
    }
}

// MARK: - Tags

enum Sequence {
    struct ForEach {}
    struct Drain {}
}

// MARK: - Test Container (mimics Array<Element>.Inline<capacity>)

enum Array<Element: ~Copyable>: ~Copyable {
    struct Inline<let capacity: Int>: ~Copyable {
        var count: Int = 0
    }
}

// MARK: - ForEach Extension

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Inline<n>, Element: ~Copyable {

    /// `.forEach { }` via callAsFunction
    func callAsFunction(_ body: (borrowing Element) -> Void) {
        print("forEach: Element=\(Element.self), capacity=\(n)")
    }

    /// `.forEach.borrowing { }`
    func borrowing(_ body: (borrowing Element) -> Void) {
        print("forEach.borrowing: Element=\(Element.self), capacity=\(n)")
    }
}

extension Property.View.Typed.Valued
where Tag == Sequence.ForEach, Base == Array<Element>.Inline<n>, Element: Copyable {

    /// `.forEach.consuming { }` - Copyable only
    mutating func consuming(_ body: (Element) -> Void) {
        print("forEach.consuming: Element=\(Element.self), capacity=\(n)")
    }
}

// MARK: - Drain Extension

extension Property.View.Typed.Valued
where Tag == Sequence.Drain, Base == Array<Element>.Inline<n>, Element: ~Copyable {

    /// `.drain { }` via callAsFunction
    mutating func callAsFunction(_ body: (consuming Element) -> Void) {
        print("drain: Element=\(Element.self), capacity=\(n)")
    }
}

// MARK: - Array.Inline Properties

extension Array.Inline where Element: ~Copyable {

    var forEach: Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.ForEach, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }

    var drain: Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity> {
        mutating _read {
            yield unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
        }
        mutating _modify {
            var view = unsafe Property<Sequence.Drain, Self>.View.Typed<Element>.Valued<capacity>(&self)
            yield &view
        }
    }
}

// MARK: - Test Types

struct MoveOnly: ~Copyable {
    var id: Int
}

// MARK: - Tests

func testCopyable() {
    print("=== Copyable Elements (Int) ===")
    var array = Array<Int>.Inline<8>()

    array.forEach { _ in }
    array.forEach.borrowing { _ in }
    array.forEach.consuming { _ in }
    array.drain { _ in }

    print("✓ All operations work for Copyable\n")
}

func testNonCopyable() {
    print("=== ~Copyable Elements (MoveOnly) ===")
    var array = Array<MoveOnly>.Inline<4>()

    array.forEach { _ in }
    array.forEach.borrowing { _ in }
    // array.forEach.consuming { _ in }  // Should NOT compile
    array.drain { _ in }

    print("✓ forEach and drain work, consuming correctly unavailable\n")
}

func testDifferentCapacities() {
    print("=== Different Capacities ===")
    var small = Array<Int>.Inline<2>()
    var large = Array<Int>.Inline<1024>()

    small.forEach { _ in }
    large.forEach { _ in }

    print("✓ Works with different capacity values\n")
}

// MARK: - Main

print("=== Property.View.Typed.Valued Experiment ===\n")

testCopyable()
testNonCopyable()
testDifferentCapacities()

print("=== RESULTS ===")
print("✓ Property.View.Typed.Valued<n> structure works")
print("✓ Extensions can constrain: Base == Array<Element>.Inline<n>")
print("✓ Element from Typed, n from Valued - both in scope")
print("✓ callAsFunction works")
print("✓ Copyable-only methods work")
print("✓ ~Copyable elements work")
print("\nNaming: Typed/Valued parallels type/value")
print("  - Typed<Element>  → parameterized by a type")
print("  - Valued<n>       → parameterized by a value")
print("\nAPI Surface:")
print("  array.forEach { }           - borrowing (all elements)")
print("  array.forEach.borrowing { } - explicit borrowing")
print("  array.forEach.consuming { } - Copyable only")
print("  array.drain { }             - ownership transfer")
