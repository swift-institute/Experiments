// MARK: - Deep Closure Integration Gap Investigation
// Purpose: Find the exact boundary of the closure gap in Swift 6.2.4.
// Date: 2026-02-28
// Toolchain: Apple Swift 6.2.4

// ============================================================================
// Systematic investigation: What passes and what fails?
// ============================================================================

// --- Type 1: Copyable, ~Escapable, no nested ~Escapable fields ---
struct SimpleView: ~Escapable {
    let count: Int

    @_lifetime(borrow source)
    init(source: borrowing [Int]) {
        self.count = source.count
    }
}

// --- Type 2: Copyable, ~Escapable, STORES a Span (~Escapable) ---
struct SpanHolder: ~Escapable {
    let span: Span<UInt8>

    @_lifetime(borrow source)
    init(source: borrowing [UInt8]) {
        self.span = source.span
    }
}

// --- Type 3: ~Copyable, ~Escapable, no nested ~Escapable fields ---
struct UniqueSimpleView: ~Copyable, ~Escapable {
    let count: Int

    @_lifetime(borrow source)
    init(source: borrowing [Int]) {
        self.count = source.count
    }
}

// --- Type 4: ~Copyable, ~Escapable, STORES a Span ---
struct InputView: ~Copyable, ~Escapable {
    var span: Span<UInt8>

    @_lifetime(borrow source)
    init(_ source: Span<UInt8>) {
        self.span = source
    }
}

// ============================================================================
// Test: Which types can be passed to closures?
// ============================================================================

// T1: SimpleView (Copyable, ~Escapable, no ~Escapable fields)
func withSimple<T>(_ arr: [Int], _ body: (SimpleView) -> T) -> T {
    let view = SimpleView(source: arr)
    return body(view)
}

// T2: SpanHolder (Copyable, ~Escapable, stores Span)
func withSpanHolder<T>(_ arr: [UInt8], _ body: (SpanHolder) -> T) -> T {
    let view = SpanHolder(source: arr)
    return body(view)  // Does this work or fail?
}

// T3: UniqueSimpleView (~Copyable, ~Escapable, no ~Escapable fields)
func withUnique<T>(_ arr: [Int], _ body: (consuming UniqueSimpleView) -> T) -> T {
    let view = UniqueSimpleView(source: arr)
    return body(view)  // Does this work or fail?
}

// T4: InputView (~Copyable, ~Escapable, stores Span)
// Already demonstrated: FAILS with "lifetime-dependent variable escapes its scope"

// T4b: ~Copyable, ~Escapable, stores Span — confirm it fails
// func withInput<T>(_ arr: [UInt8], _ body: (inout InputView) -> T) -> T {
//     var view = InputView(arr.span)
//     return body(&view)  // FAILS
// }

// T5: Span directly (stdlib ~Escapable type)
func withSpanDirect<T>(_ arr: [Int], _ body: (Span<Int>) -> T) -> T {
    let span = arr.span
    return body(span)
}

func runDeepClosureGapTests() {
    print("\n  === Deep Closure Gap Investigation ===")

    // T1: SimpleView — does it work?
    let t1 = withSimple([1, 2, 3]) { $0.count }
    print("  T1: SimpleView (Copyable, ~Esc, no ~Esc fields) to closure — WORKS (\(t1))")

    // T5: Span directly
    let t5 = withSpanDirect([10, 20, 30]) { $0.count }
    print("  T5: Span<Int> directly to closure — WORKS (\(t5))")

    let t2 = withSpanHolder([4, 5, 6]) { $0.span.count }
    print("  T2: SpanHolder (Copyable, ~Esc, stores Span) to closure — WORKS (\(t2))")

    let t3 = withUnique([7, 8]) { $0.count }
    print("  T3: UniqueSimpleView (~Copy, ~Esc, no ~Esc fields) to closure — WORKS (\(t3))")

    print("  T4: InputView (~Copy, ~Esc, stores Span) to closure — FAILS")
    print("")
    print("  === Closure Gap Boundary (Swift 6.2.4) ===")
    print("  Copyable + ~Escapable + no ~Esc fields  → closure OK")
    print("  Copyable + ~Escapable + stores Span     → closure OK")
    print("  ~Copyable + ~Escapable + no ~Esc fields  → closure OK")
    print("  ~Copyable + ~Escapable + stores Span     → closure FAILS")
    print("  Span<T> directly                          → closure OK")
    print("")
    print("  FINDING: The gap is specifically ~Copyable + ~Escapable + stored ~Escapable field")
}
