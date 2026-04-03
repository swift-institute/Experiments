// MARK: - ~Copyable Constraint Poisoning (Multi-file)
// Purpose: Test whether file-level separation prevents constraint poisoning
// Status: BUG REPRODUCED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — file separation doesn't prevent Sequence Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Origin: noncopyable-pointer-propagation-multifile
//
// Original structure:
//   Container.swift           — base type with ~Copyable element
//   Container+Sequence.swift  — conditional Sequence conformance
//   main.swift                — test with non-Copyable element
//
// Expected: Poisoning persists despite file separation (module-level resolution)

enum V05_PointerPropagationMultifile {

    // MARK: - Originally Container.swift

    // Defined in a separate file from the Sequence conformance to test
    // whether file-level separation prevents constraint poisoning.

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

    // MARK: - Originally Container+Sequence.swift

    // COMPILE ERROR (expected): This conformance is in a separate file from
    // Container's definition. The poisoning still occurs because the compiler
    // resolves constraints at the module level, not the file level.
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

    // MARK: - Originally main.swift

    struct Resource: ~Copyable {
        var value: Int
    }

    static func run() {
        // This should compile but fails due to poisoning from the Sequence conformance
        let c = Container<Resource>(capacity: 4)
        print("Container created: count = \(c.count)")
        _ = c
    }
}
