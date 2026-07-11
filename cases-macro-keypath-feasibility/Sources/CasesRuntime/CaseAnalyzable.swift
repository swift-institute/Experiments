// MARK: - CaseAnalyzable
//
// The witness protocol an enum conforms to (macro-generated) so that `Case.Path`
// composition can reach a nested enum's own `Cases` witness during depth-3 lookup.
//
// Analogous to point-free CasePaths' `CasePathable` — but institute-native and
// carrying zero pointfreeco surface. `associatedtype Cases` is satisfied by the
// macro-generated nested `Cases` struct; `static var cases` by the generated accessor.

public protocol CaseAnalyzable {
    associatedtype Cases
    static var cases: Cases { get }
}
