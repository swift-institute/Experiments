import CasesMacros

// cases-macro-keypath-feasibility — subject enums for the @Cases spike.
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), macOS 26 / arm64, 2026-07-11
// Status: CONFIRMED — the `KeyPath<Enum.Cases, Case.Path<Enum, Value>>` shape
//         type-checks and behaves for depth-1 `.is(\.case)`, `.case(\.case)`, and
//         depth-3 `\.authenticate.api.credentials` composition. See README.md.
// Result: FEASIBLE (verdict in README.md).

// MARK: - Flat enum (part 1): 3+ cases, mixed payload / no-payload

@Cases
public enum Route: Equatable {
    case home
    case list
    case detail(Int)
    case edit(id: Int, draft: String)
}

// MARK: - 3-level nested enum (part 2): reproduces `\.authenticate.api.credentials`

@Cases
public enum AppRoute: Equatable {
    case home
    case authenticate(AuthRoute)
}

@Cases
public enum AuthRoute: Equatable {
    case login
    case api(API)
}

@Cases
public enum API: Equatable {
    case status
    case credentials(Credentials)
}

public struct Credentials: Equatable {
    public let token: String
    public init(token: String) { self.token = token }
}

// MARK: - Coexistence enum (part 3): @Cases AND @DualLike on one enum

@Cases
@DualLike
public enum CoexistRoute: Equatable {
    case alpha
    case beta(Int)
    case gamma
}
