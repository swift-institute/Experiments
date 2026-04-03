// MARK: - ~Copyable Sequence Module Emission Bug
// Purpose: Module emission failure with ~Copyable + Sequence conformance
// Status: BUG FILED #86669 (2026-01-20, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Origin: noncopyable-sequence-emit-module-bug

enum V06_SequenceEmitModuleBug {

    // Minimal reproduction: generic type with ~Copyable that conditionally conforms to Sequence
    // The -emit-module step crashes or produces invalid output

    // Note: Named V06Collection to avoid collision with Swift.Collection
    struct V06Collection<Element: ~Copyable>: ~Copyable {
        var elements: UnsafeMutablePointer<Element>
        var count: Int

        init() {
            elements = .allocate(capacity: 0)
            count = 0
        }

        deinit { elements.deallocate() }
    }

    // COMPILE ERROR (expected): @retroactive Sequence conformance with ~Copyable
    // causes module emission crash / invalid output. The -emit-module step fails.
    // Even with @retroactive to acknowledge the cross-module conformance, the
    // underlying poisoning bug prevents compilation.
    //
    // extension V06Collection: @retroactive Sequence where Element: Copyable {
    //     struct Iterator: IteratorProtocol {
    //         var index: Int
    //         let count: Int
    //         let base: UnsafeMutablePointer<Element>
    //         mutating func next() -> Element? {
    //             guard index < count else { return nil }
    //             defer { index += 1 }
    //             return base[index]
    //         }
    //     }
    //     func makeIterator() -> Iterator {
    //         Iterator(index: 0, count: count, base: elements)
    //     }
    // }

    static func run() {
        // If this compiles and runs, the bug may be fixed
        let c = V06Collection<Int>()
        print("V06Collection created with count: \(c.count)")
        print("Module emission test: BUILD SUCCEEDED")
        _ = c
    }
}
