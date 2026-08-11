// Closure gap investigation: What works and what doesn't in Swift 6.2.4?

struct DepView: ~Escapable {
    let count: Int

    @_lifetime(borrow source)
    init(source: borrowing [Int]) {
        self.count = source.count
    }
}

// V4-DEP-A: Simple closure with dependent ~Escapable value
func withDepView_Simple<T>(_ array: [Int], _ body: (DepView) -> T) -> T {
    let view = DepView(source: array)
    return body(view)
}

// V4-DEP-B: Closure with inout dependent value
func withDepView_Inout<T>(_ array: [Int], _ body: (inout DepView) -> T) -> T {
    var view = DepView(source: array)
    return body(&view)
}

// V4-DEP-C: Span directly to closure (the canonical test)
func withSpan_Direct<T>(_ array: [Int], _ body: (Span<Int>) -> T) -> T {
    let span = array.span
    return body(span)
}

// V4-DEP-D: inout Span to closure
func withSpan_Inout<T>(_ array: [Int], _ body: (inout Span<Int>) -> T) -> T {
    var span = array.span
    return body(&span)
}

// V4-DEP-E: Create dependent value inside closure and pass to another
func nested_Dependent<T>(_ array: [Int], _ body: (DepView) -> T) -> T {
    return body(DepView(source: array))
}

func runClosureGapTests() {
    let array = [10, 20, 30]

    let a = withDepView_Simple(array) { $0.count }
    print("  V4-DEP-A: Simple closure with dependent value — result = \(a)")

    let b = withDepView_Inout(array) { $0.count }
    print("  V4-DEP-B: inout closure with dependent value — result = \(b)")

    let c = withSpan_Direct(array) { $0.count }
    print("  V4-DEP-C: Span directly to closure — result = \(c)")

    let d = withSpan_Inout(array) { $0.count }
    print("  V4-DEP-D: inout Span to closure — result = \(d)")

    let e = nested_Dependent(array) { $0.count }
    print("  V4-DEP-E: Nested dependent creation — result = \(e)")
}
