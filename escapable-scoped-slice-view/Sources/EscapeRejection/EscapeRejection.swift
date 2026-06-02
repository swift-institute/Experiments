// MARK: - EscapeRejection — negative controls (EXPECT: do NOT compile)
//
// A ~Escapable view is only meaningful if escaping the borrow is actually rejected. If
// this target COMPILES, the ~Escapable guarantee is vacuous and the whole shape is
// unsound. Two controls:
//
//   (1) EscapableHolder — storing the ~Escapable view in an *Escapable* struct. This is
//       the EXACT symmetric counterpart of collection-slice-escapable-index-toolchain-
//       fallout.md v1.1.0's Option-B obstruction. It MUST fail with the same family of
//       error ("non-Escapable type" in an "'Escapable'-conforming struct"), confirming
//       the doc's finding AND contrasting with ScopedSliceKit's success (a ~Escapable
//       struct holding the same fields compiles).
//
//   (2) escapeAttempt — returning the view past the borrow of `base` WITHOUT propagating
//       the lifetime. MUST be rejected (escape / missing-@_lifetime), proving the view
//       cannot outlive its base.
//
// Build with: swift build --target EscapeRejection  (EXPECT non-zero exit).
// Toolchain: probed on BOTH Apple Swift 6.3.2 and 6.5-dev.
// Status: REJECTED as required (identical on both toolchains) — the ~Escapable guarantee
//   is REAL, not vacuous.
// Result: both controls fire, verbatim, on 6.3.2 AND 6.5-dev:
//   (1) error: stored property 'slice' of 'Escapable'-conforming struct 'EscapableHolder'
//       has non-Escapable type 'ScopedSlice'  (note: consider adding '~Escapable' to
//       struct 'EscapableHolder')
//   (2) error: a function with a ~Escapable result requires '@_lifetime(...)'
//   Cmd: swift build --target EscapeRejection

import ScopedSliceKit

// (1) Storing a ~Escapable value in an Escapable struct — EXPECT REJECTED.
public struct EscapableHolder {
    public var slice: ScopedSlice
}

// (2) Returning the ~Escapable view past the borrow of `base`, unannotated — EXPECT REJECTED.
public func escapeAttempt(
    _ base: borrowing Base,
    _ lo: borrowing Cursor,
    _ hi: borrowing Cursor
) -> ScopedSlice {
    return base.slice(from: lo, upTo: hi)
}
