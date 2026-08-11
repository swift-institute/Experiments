// EscapableBlocked.swift
// Empirical record that Product cannot admit `~Escapable` (or `~Copyable`)
// arms in current Swift due to parameter-pack syntax limitations.
//
// Toolchains verified 2026-05-09:
//   - Swift 6.3.1 (Xcode 26.4 default)
//   - Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`)
//
// Status: BLOCKED. Product remains Copyable + Escapable on all arms.
// Track Swift Evolution for parameter-pack noncopyable / nonescapable
// support; revisit when:
//
//   1. `each T: ~Copyable` admitted by parameter-pack syntax
//   2. `each T: ~Escapable` admitted by parameter-pack syntax
//   3. Lifetime-annotation propagation through pack-expanded expressions
//
// None of these have a public Swift Evolution proposal as of 2026-05-09.

public import Product_Primitives

// MARK: - V1: Product type-level ~Copyable upgrade — BLOCKED
//
// Attempting to declare `Product<each Element: ~Copyable>` produces (on
// Swift 6.4-dev nightly 2026-05-07-a):
//
//   error: type 'each Element' required to be 'Copyable' but is marked
//   with '~Copyable'
//
// (Verified empirically; the diagnostic is at the `~Copyable`
// suppression in the each-pack constraint position.) Pack syntax does
// not yet admit suppressions on `each` requirements.

// MARK: - V2: Product type-level ~Escapable upgrade — BLOCKED
//
// Same root cause: pack syntax does not admit `each T: ~Escapable`.

// MARK: - V3: Free function `swapped(_:)` ~Escapable extension — BLOCKED
//
// `swapped(_:)` is a free function on `Product<First, Second>` (binary,
// non-pack). However, the Product TYPE itself requires First and Second
// to be Copyable + Escapable, so adding `~Copyable & ~Escapable` to the
// function's generic constraints fails at the call site:
//
//   error: 'NEResource' does not conform to 'Escapable'
//
// Until Product's type-level constraint is upgraded (gated on items 1-2
// above), the binary `swapped` cannot admit ~Escapable arms.

// MARK: - V4: Existing Product API on Copyable+Escapable arms — CONFIRMED

public func v4_constructAndOperate() -> Int {
    let triple = Product(1, "hi", true)
    let mapped = try? triple.map(
        { $0 + 10 },
        { $0.uppercased() },
        { !$0 }
    )
    return mapped?.values.0 ?? -1
}

// MARK: - Notes
//
// - The cohort siblings `swift-pair-primitives` and `swift-either-primitives`
//   DID admit ~Escapable arms (see their respective Research/escapable-arm-support.md
//   notes). Product's deferral is specific to its parameter-pack-based shape.
//
// - The institute conformances on Product (`Product+Equation.Protocol.swift`
//   etc.) use `where repeat each Element: Equation.Protocol` — also constrained
//   by pack syntax, so admitting ~Escapable conformers requires the same upstream
//   compiler progress.
