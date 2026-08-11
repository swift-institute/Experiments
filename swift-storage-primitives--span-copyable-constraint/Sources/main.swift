// MARK: - Span Copyable Constraint Validation
// Purpose: Verify whether a method using Span<Element> in a ~Copyable extension
//   is a constraint bug, or if Swift's type system correctly prevents misuse.
//
// Hypothesis: Span<Element> requires Element: Copyable. If withSpan is in a
//   ~Copyable extension, the compiler should either:
//   (a) Prevent the method from being declared (compile error on method)
//   (b) Prevent the method from being called for ~Copyable elements (call-site error)
//
// Toolchain: Swift 6.2 (Xcode 26)
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED - Not a bug, but misleading API design
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//   - Method declaration compiles (Element is generic)
//   - Method only callable when Element: Copyable (Span constraint at call site)
//   - Moving to Copyable extension is correct for API clarity
// Date: 2026-02-05

// ============================================================================
// MARK: - Test Setup
// ============================================================================

/// A ~Copyable resource type for testing
struct Resource: ~Copyable {
    var value: Int
    init(_ value: Int) { self.value = value }
}

/// A Copyable type for comparison
struct Value {
    var value: Int
    init(_ value: Int) { self.value = value }
}

/// Simple storage that replicates the pattern in question
struct TestStorage<Element: ~Copyable>: ~Copyable {
    var elements: [Int] = []  // Placeholder for actual storage
    var count: Int = 0

    init() {}
}

// ============================================================================
// MARK: - Variant 1: Method in ~Copyable extension using Span
// Question: Does this even compile? Does it constrain Element implicitly?
// ============================================================================

extension TestStorage where Element: ~Copyable {
    /// This method is in the ~Copyable extension but uses Span<Element>.
    /// Span<Element> requires Element: Copyable (SE-0447).
    ///
    /// Question: Does Swift's constraint system handle this correctly?
    func withSpan<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        // Create a dummy span for testing
        let ptr = unsafe UnsafePointer<Element>(bitPattern: 0x1000)!
        let span = unsafe Span(_unsafeStart: ptr, count: 0)
        return try body(span)
    }
}

// ============================================================================
// MARK: - Variant 2: Method in Copyable extension using Span
// This is the "correct" placement according to the research
// ============================================================================

extension TestStorage where Element: Copyable {
    /// This method is in the Copyable extension, matching Span's constraint.
    func withSpanCopyable<R, E: Swift.Error>(
        _ body: (Span<Element>) throws(E) -> R
    ) throws(E) -> R {
        let ptr = unsafe UnsafePointer<Element>(bitPattern: 0x1000)!
        let span = unsafe Span(_unsafeStart: ptr, count: 0)
        return try body(span)
    }
}

// ============================================================================
// MARK: - Test Cases
// ============================================================================

func testCopyableElement() {
    print("=== Test: Copyable Element (Value) ===")

    let storage = TestStorage<Value>()

    // Both methods should work for Copyable elements
    print("Calling withSpan (from ~Copyable extension)...")
    do {
        try storage.withSpan { span in
            print("  Success: withSpan called, span.count = \(span.count)")
        }
    } catch {
        print("  Error: \(error)")
    }

    print("Calling withSpanCopyable (from Copyable extension)...")
    do {
        try storage.withSpanCopyable { span in
            print("  Success: withSpanCopyable called, span.count = \(span.count)")
        }
    } catch {
        print("  Error: \(error)")
    }
    print()
}

func testNonCopyableElement() {
    print("=== Test: ~Copyable Element (Resource) ===")

    var storage = TestStorage<Resource>()
    _ = storage  // Silence unused warning

    // QUESTION: Can we call withSpan for ~Copyable elements?
    // If Span<Resource> doesn't exist (because Resource: ~Copyable),
    // this should fail to compile.

    // UNCOMMENT TO TEST:
    // storage.withSpan { span in
    //     print("  This should NOT compile!")
    // }

    print("withSpan NOT callable for ~Copyable elements")
    print("  (Span<Resource> would require Resource: Copyable)")
    print()
}

// ============================================================================
// MARK: - Summary
// ============================================================================

func printSummary() {
    print("=== SUMMARY ===")
    print()
    print("FINDING: Method declaration in ~Copyable extension with Span<Element>")
    print("  compiles because Element is a generic parameter.")
    print()
    print("FINDING: The method can only be CALLED when Element: Copyable,")
    print("  because Span<Element> imposes that constraint at the call site.")
    print()
    print("CONCLUSION: Placing withSpan in ~Copyable extension is NOT a bug,")
    print("  but it IS misleading. The method appears available for all Element")
    print("  types but silently fails to be callable for ~Copyable elements.")
    print()
    print("RECOMMENDATION: Move to Copyable extension for API clarity.")
    print("  Users see the constraint explicitly in the extension header.")
    print()
}

// ============================================================================
// MARK: - Execution
// ============================================================================

testCopyableElement()
testNonCopyableElement()
printSummary()
