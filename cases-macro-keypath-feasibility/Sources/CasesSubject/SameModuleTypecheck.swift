import CasesMacros

// MARK: - Same-module type-check proof
//
// The test target exercises these call sites cross-module; this function proves
// they also resolve *in the same module the enums are declared in* (access-control
// and keypath-literal resolution can differ across a module boundary — [EXP-017]).
// Behavioral assertions live in the test target; this is compile-only.

public func casesSubjectSameModuleTypecheck() {
    // Depth-1 keypath-literal predicate.
    let route: Route = .list
    _ = route.is(\.list)
    _ = route.is(\.detail)

    // Depth-1 embed/extract via keypath literal.
    _ = Route.cases[keyPath: \.detail]

    // Depth-3 @dynamicMemberLookup composition.
    _ = AppRoute.cases[keyPath: \.authenticate.api.credentials]
    let app: AppRoute = .home
    _ = app.is(\.authenticate.api.credentials)

    // `.case(\.case)` combinator with Root pinned by the generic namespace / annotation.
    _ = Routes<Route>.case(\.list)
    _ = Routes<AppRoute>.case(\.authenticate.api.credentials)
    let _: Case.Path<Route, Int> = makeCase(\.detail)
}
