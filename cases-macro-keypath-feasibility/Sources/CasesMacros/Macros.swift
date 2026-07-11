@_exported import CasesRuntime

/// Generates a per-case witness (`Cases`), a `static var cases` accessor, and an
/// `is(_:)` predicate keyed by a `Case.Path` keypath, plus a `CaseAnalyzable`
/// conformance enabling depth composition of nested `@Cases` enums.
///
/// ```swift
/// @Cases enum Route {
///     case home
///     case detail(Int)
/// }
/// route.is(\.detail)                       // depth-1 predicate
/// Route.cases[keyPath: \.detail].embed(7)  // .detail(7)
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: CaseAnalyzable, names: arbitrary)
public macro Cases() =
    #externalMacro(module: "CasesMacrosImplementation", type: "CasesMacro")

/// Coexistence stand-in for @Dual: generates a separate `Prisms` witness and a
/// `DualLikeMarker` conformance. Used only to prove @Cases coexists with another
/// member+extension macro on the same enum.
@attached(member, names: arbitrary)
@attached(extension, conformances: DualLikeMarker, names: arbitrary)
public macro DualLike() =
    #externalMacro(module: "CasesMacrosImplementation", type: "DualLikeMacro")
