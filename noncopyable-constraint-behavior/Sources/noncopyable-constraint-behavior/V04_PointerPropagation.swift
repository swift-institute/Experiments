// MARK: - ~Copyable Constraint Poisoning Test
// Purpose: Adding Sequence conformance where Element: Copyable poisons stored UnsafeMutablePointer<Element>
// Status: BUG REPRODUCED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Origin: noncopyable-pointer-propagation

enum V04_PointerPropagation {

    struct Container<Element: ~Copyable>: ~Copyable {
        var storage: UnsafeMutablePointer<Element>
        var count: Int

        init(capacity: Int) {
            storage = .allocate(capacity: capacity)
            count = 0
        }

        deinit {
            storage.deallocate()
        }
    }

    // COMPILE ERROR (expected): This conformance poisons the struct above.
    // UnsafeMutablePointer<Element> in Container's stored property requires
    // Element: Copyable once Sequence conformance is added, even conditionally.
    //
    // extension Container: Sequence where Element: Copyable {
    //     struct Iterator: IteratorProtocol {
    //         var current: Int
    //         let end: Int
    //         let base: UnsafeMutablePointer<Element>
    //         mutating func next() -> Element? {
    //             guard current < end else { return nil }
    //             defer { current += 1 }
    //             return base[current]
    //         }
    //     }
    //     func makeIterator() -> Iterator {
    //         Iterator(current: 0, end: count, base: storage)
    //     }
    // }

    // Test with non-Copyable element
    struct Resource: ~Copyable {
        var value: Int
    }

    static func run() {
        // This should compile but fails due to poisoning when conformance is present
        let c = Container<Resource>(capacity: 4)
        print("Container created: count = \(c.count)")
        _ = c
    }
}
