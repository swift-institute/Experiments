// MARK: - ~Copyable Multifile Poisoning
// Purpose: File organization within the same module does NOT prevent poisoning
// Status: CONFIRMED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Origin: noncopyable-multifile-poisoning
//
// Original structure:
//   Base.swift         — Slab<Element: ~Copyable> with UnsafeMutablePointer storage
//   Conformance.swift  — conditional Sequence conformance (where Element: Copyable)
//   main.swift         — instantiation with non-Copyable element
//
// Expected: Compiler errors on Slab's stored properties despite file separation

enum V02_MultifilePoisoning {

    // MARK: - Originally Base.swift

    // Generic struct with ~Copyable element and unsafe storage.
    // Defined separately from the conditional conformance.

    struct Slab<Element: ~Copyable>: ~Copyable {
        var base: UnsafeMutablePointer<Element>
        var capacity: Int

        init(capacity: Int) {
            self.base = .allocate(capacity: capacity)
            self.capacity = capacity
        }

        deinit {
            base.deallocate()
        }
    }

    // MARK: - Originally Conformance.swift

    // COMPILE ERROR (expected): Adding this conformance poisons Slab's
    // stored properties at the module level. Even though it is conditioned
    // on `where Element: Copyable`, the compiler resolves constraints at
    // the module level, not the file level. This causes
    // UnsafeMutablePointer<Element> to require Element: Copyable everywhere.
    //
    // extension Slab: Sequence where Element: Copyable {
    //     struct Iterator: IteratorProtocol {
    //         var index: Int
    //         let count: Int
    //         let pointer: UnsafeMutablePointer<Element>
    //         mutating func next() -> Element? {
    //             guard index < count else { return nil }
    //             defer { index += 1 }
    //             return pointer[index]
    //         }
    //     }
    //     func makeIterator() -> Iterator {
    //         Iterator(index: 0, count: capacity, pointer: base)
    //     }
    // }

    // MARK: - Originally main.swift

    struct Token: ~Copyable {
        var id: Int
    }

    static func run() {
        // This should compile but fails due to poisoning from the Sequence conformance
        let slab = Slab<Token>(capacity: 16)
        print("Slab created: capacity = \(slab.capacity)")
        _ = slab
    }
}
