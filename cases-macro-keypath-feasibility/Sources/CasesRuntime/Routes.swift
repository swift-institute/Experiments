// MARK: - `.case(\.case)` combinators
//
// A routing DSL passes a case-path keypath literal to a `.case(...)` combinator.
// The hard part: a *leading-dot* keypath literal `\.list` carries no root type of
// its own — the root `Root.Cases` must be supplied by the combinator's context.
//
// `Routes<Root>` pins `Root` via its generic parameter (mirrors how a real
// `OneOf`/builder fixes the route type), so `Routes<Route>.case(\.list)`
// type-checks: `\.list` resolves against the now-concrete `Route.Cases`.
//
// `makeCase` is the free-function form: `Root` is pinned by the result-type
// annotation instead. Both are the realistic shapes; a *fully unpinned*
// `makeCase(\.list)` cannot infer `Root` from the literal alone — see README.

public enum Routes<Root: CaseAnalyzable> {
    public static func `case`<Value>(
        _ keyPath: KeyPath<Root.Cases, Case.Path<Root, Value>>
    ) -> Case.Path<Root, Value> {
        Root.cases[keyPath: keyPath]
    }
}

public func makeCase<Root: CaseAnalyzable, Value>(
    _ keyPath: KeyPath<Root.Cases, Case.Path<Root, Value>>
) -> Case.Path<Root, Value> {
    Root.cases[keyPath: keyPath]
}
