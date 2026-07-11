// MARK: - DualLikeMarker
//
// Trivial marker conformance added by the coexistence `@DualLike` macro's extension.
// Stands in for @Dual's `__OpticPrismAccessible` — its only job is to prove two
// extension macros (one adding `: CaseAnalyzable`, one adding `: DualLikeMarker`)
// coexist on the same enum without conflict.

public protocol DualLikeMarker {}
