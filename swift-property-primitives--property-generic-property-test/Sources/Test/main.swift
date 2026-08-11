// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: Nested Property Type with Typealias Shorthand
// ===----------------------------------------------------------------------===//
//
// PROBLEM: Property<Tag, Base>.Of<Element> repeats Element redundantly
//
// HYPOTHESIS: A typealias in Container can eliminate the redundancy
//
// METHODOLOGY: Incremental Construction [EXP-004a]
// ===----------------------------------------------------------------------===//

// MARK: - Property Type (with Tag-first ordering per Tagged<Tag, RawValue>)

struct Property<Tag, Base> {
    var base: Base
    init(_ base: Base) { self.base = base }

    struct Of<Element> {
        var base: Base
        init(_ base: Base) { self.base = base }
    }
}

// MARK: - Container Type

struct Container<Element> {
    var storage: [Element] = []

    enum Peek {}
    enum Take {}

    var count: Int { storage.count }
    var isEmpty: Bool { storage.isEmpty }

    func peekBack() -> Element? { storage.last }
    func peekFront() -> Element? { storage.first }

    mutating func takeBack() -> Element? {
        storage.isEmpty ? nil : storage.removeLast()
    }
}

// ===----------------------------------------------------------------------===//
// TEST 1: Full Form (verbose)
// ===----------------------------------------------------------------------===//

extension Property.Of where Tag == Container<Element>.Peek, Base == Container<Element> {
    var back: Element? { base.peekBack() }
    var front: Element? { base.peekFront() }
    var count: Int { base.count }
    var isEmpty: Bool { base.isEmpty }
}

extension Container {
    // Verbose: Property<Peek, Container<Element>>.Of<Element>
    var peek1: Property<Peek, Container<Element>>.Of<Element> {
        Property.Of(self)
    }
}

// ===----------------------------------------------------------------------===//
// TEST 2: Typealias Shorthand
// ===----------------------------------------------------------------------===//

extension Container {
    // Typealias binds Container<Element> and Element, leaving only Tag
    typealias PropertyOf<Tag> = Property<Tag, Container<Element>>.Of<Element>
}

extension Container {
    // Clean: PropertyOf<Peek>
    var peek2: PropertyOf<Peek> {
        Property.Of(self)
    }
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== Typealias Shorthand Test ===\n")

    let c = Container<Int>(storage: [1, 2, 3])

    print("Full form (peek1 via Property<Peek, Container<Element>>.Of<Element>):")
    print("  peek1.back    = \(c.peek1.back ?? -1)")
    print("  peek1.count   = \(c.peek1.count)")
    print("  peek1.isEmpty = \(c.peek1.isEmpty)")

    print("\nTypealias (peek2 via PropertyOf<Peek>):")
    print("  peek2.back    = \(c.peek2.back ?? -1)")
    print("  peek2.count   = \(c.peek2.count)")
    print("  peek2.isEmpty = \(c.peek2.isEmpty)")

    print("\n=== FINDING ===")
    print("Typealias works! PropertyOf<Tag> eliminates redundant Element.")
    print("")
    print("Before: Property<Peek, Container<Element>>.Of<Element>")
    print("After:  PropertyOf<Peek>")
}

main()
