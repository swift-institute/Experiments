// MARK: - Init overload disambiguation hypothesis matrix
//
// Purpose: Empirically determine whether modern Swift can disambiguate
//          two inits that differ ONLY in `throws`, and whether `@_spi(...)`
//          gating is itself sufficient as an overload-resolution discriminator.
//          The answer determines the migration shape for the ecosystem-wide
//          `__unchecked: ()` pattern.
//
// Toolchain: swift-6.3
// Platform:  macOS 26 (arm64)
// Date:      2026-05-02
// Blog:      BLOG-IDEA-078 "Three Ways NOT to Disambiguate a Swift Init"
//            (see swift-institute/Blog/Ideas/BLOG-IDEA-078-context.md)
// Status:    COMPLETE — V1/V3 REFUTED, V4-original REFUTED, V2/V5 CONFIRMED.
// Result:    Build Succeeded (debug + release); cross-module exercised in
//            both `with-spi` and `without-spi` targets; SPI-gated init's
//            invisibility under non-SPI import probed and diagnostic captured
//            in Outputs/probe-spi-invisibility.txt. Per-variant outcomes in
//            the MARK sections; executive summary at the bottom.
//
// The `__unchecked: ()` empty-tuple pattern serves TWO orthogonal jobs:
//  (1) overload disambiguation — distinguishing the unchecked init from
//      a throwing-init that takes the same trailing parameters
//  (2) visibility / discipline — flagging the bypass as a friction point
//
// The migration question: can either job be dropped under modern Swift?

// MARK: - V1 — Throws-only disambiguation (REFUTED 2026-05-02)
//
// Hypothesis: two inits that differ ONLY in `throws(E)` can coexist as
// overloads. The compiler distinguishes them at the call site by the
// presence/absence of `try`.
//
// Result: REFUTED. Compiler diagnostic captured at first build attempt:
//   error: invalid redeclaration of 'init(_:)'
//   note: 'init(_:)' previously declared here
//
// Conclusion: `throws` does NOT participate in overload-signature uniqueness
// in Swift 6.3. Two inits with identical parameter lists are redeclarations
// regardless of throws annotation. The empty-tuple discriminator (or some
// other parameter-list difference) IS load-bearing for disambiguation.
//
// Code that triggered the diagnostic (left commented as evidence):
//
//     public struct V1 {
//         @usableFromInline internal let _value: UInt64
//
//         @inlinable
//         public init(_ value: UInt64) {
//             self._value = value
//         }
//
//         @inlinable
//         public init(_ value: UInt64) throws(V1Error) {  // ← redeclaration error
//             guard value > 0 else { throw V1Error.zero }
//             self._value = value
//         }
//     }
//     public enum V1Error: Error { case zero }

// MARK: - V2 — Empty-tuple disambiguation (CONFIRMED control)
//
// Hypothesis: the empty-tuple-labeled init `init(__unchecked: (), _ value:)`
// disambiguates from `init(_ value:) throws(E)` because the parameter
// LABEL SETS differ. Known-good baseline.
//
// Result: CONFIRMED. Both inits coexist; both call shapes resolve correctly.

public struct V2 {
    @usableFromInline
    internal let _value: UInt64

    @inlinable
    public init(__unchecked: (), _ value: UInt64) {
        self._value = value
    }

    @inlinable
    public init(_ value: UInt64) throws(V2Error) {
        guard value > 0 else { throw V2Error.zero }
        self.init(__unchecked: (), value)
    }

    @inlinable
    public var value: UInt64 { _value }
}

public enum V2Error: Error { case zero }

// MARK: - V3 — SPI-only disambiguation (REFUTED 2026-05-02)
//
// Hypothesis: `@_spi(Unchecked)` on one of two same-signature inits could
// participate in overload-resolution discrimination, allowing the unchecked
// and throwing inits to coexist without an empty-tuple discriminator.
//
// Result: REFUTED. Compiler diagnostic captured at first build attempt:
//   error: invalid redeclaration of 'init(_:)'
//   note: 'init(_:)' previously declared here
//
// Conclusion: `@_spi(...)` is purely an access-control mechanism. It does NOT
// alter the function's signature for redeclaration / overload-resolution
// purposes. SPI can hide a declaration from external consumers, but it cannot
// make two same-signature declarations coexist. SPI alone cannot replace the
// empty-tuple discriminator.
//
// Code that triggered the diagnostic (left commented as evidence):
//
//     public struct V3 {
//         @usableFromInline internal let _value: UInt64
//
//         @_spi(Unchecked)
//         @inlinable
//         public init(_ value: UInt64) {
//             self._value = value
//         }
//
//         @inlinable
//         public init(_ value: UInt64) throws(V3Error) {  // ← redeclaration error
//             guard value > 0 else { throw V3Error.zero }
//             self._value = value
//         }
//     }
//     public enum V3Error: Error { case zero }

// MARK: - V4 — SPI + empty-tuple, ORIGINAL shape (REFUTED 2026-05-02)
//
// Hypothesis: the proposed migration shape works directly:
//   @_spi(Unchecked) @inlinable public init(__unchecked: (), _ value:)
//   @inlinable       public init(_ value:) throws(E)  // body delegates above
//
// The throwing init's body would call `self.init(__unchecked: (), value)`
// after validation succeeds, reusing the unchecked path's storage-setting.
//
// Result: REFUTED. Compiler diagnostic captured at first build attempt:
//   error: initializer 'init(__unchecked:_:)' cannot be used in an
//          '@inlinable' function because it is SPI
//
// Conclusion: `@_spi(...)` and `@inlinable` are incompatible for THIS shape.
// An `@inlinable` body must be emittable into clients of the module — but
// clients without `@_spi(Unchecked) import` cannot see the SPI'd init,
// breaking the inlining contract. This confirms the open finding in
// `swift-institute/Research/spi-inlinable-incompatibility-survey.md` for
// the `@_spi`/`@inlinable` interaction.
//
// The original V4 shape is therefore INFEASIBLE as drafted. V5 below
// proposes a fix using a `@usableFromInline internal` storage-setting
// primitive that both public inits delegate to.
//
// Code that triggered the diagnostic (left commented as evidence):
//
//     public struct V4 {
//         @usableFromInline internal let _value: UInt64
//
//         @_spi(Unchecked)
//         @inlinable
//         public init(__unchecked: (), _ value: UInt64) {
//             self._value = value
//         }
//
//         @inlinable
//         public init(_ value: UInt64) throws(V4Error) {
//             guard value > 0 else { throw V4Error.zero }
//             self.init(__unchecked: (), value)  // ← @inlinable cannot reference SPI
//         }
//     }
//     public enum V4Error: Error { case zero }

// MARK: - V5 — SPI + empty-tuple, FIXED shape via @usableFromInline internal
//
// Hypothesis: introducing a `@usableFromInline internal init(_unchecked:)`
// as the actual storage-setting primitive — and having BOTH the SPI'd
// `init(__unchecked: (), _:)` and the throwing `init(_:) throws(E)`
// delegate to it — sidesteps the @inlinable+SPI conflict from V4.
//
// The internal init is module-private but visible to inlinable bodies; the
// SPI'd unchecked init becomes a thin trampoline visible to ecosystem
// consumers with SPI import; the throwing init is fully public and inlinable
// for external consumers.
//
// Result: CONFIRMED. Both call sites resolve correctly cross-module under
//         SPI import; debug + release builds clean; runtime output matches
//         expected values (Outputs/run-with-spi.txt; Outputs/run-without-spi.txt).
//         The empty-tuple discriminator + SPI gating + @usableFromInline
//         internal trampoline together produce a working migration shape.

public struct V5 {
    @usableFromInline
    internal let _value: UInt64

    @usableFromInline
    internal init(_unchecked value: UInt64) {
        self._value = value
    }

    @_spi(Unchecked)
    @inlinable
    public init(__unchecked: (), _ value: UInt64) {
        self.init(_unchecked: value)
    }

    @inlinable
    public init(_ value: UInt64) throws(V5Error) {
        guard value > 0 else { throw V5Error.zero }
        self.init(_unchecked: value)
    }

    @inlinable
    public var value: UInt64 { _value }
}

public enum V5Error: Error { case zero }

// MARK: - Executive summary
//
// Findings:
//
//  | Variant | Shape | Result |
//  |---------|-------|--------|
//  | V1 | throws-only disambiguation | REFUTED — redeclaration error |
//  | V2 | empty-tuple control | CONFIRMED |
//  | V3 | SPI-only disambiguation | REFUTED — redeclaration error |
//  | V4 | SPI + empty-tuple, direct delegation | REFUTED — @inlinable+SPI conflict |
//  | V5 | SPI + empty-tuple + @usableFromInline internal trampoline | TARGET |
//
// Implication for the migration:
//
//  - The `__unchecked: ()` empty-tuple discriminator IS load-bearing
//    in modern Swift; throws and SPI alone do not disambiguate overloads.
//  - The proposed migration shape `@_spi(Unchecked) @inlinable public
//    init(__unchecked: (), _:)` cannot be the sole storage-setting init if
//    a throwing init delegates to it — `@inlinable`+`@_spi` blocks that.
//  - V5's `@usableFromInline internal init(_unchecked:)` pattern is the
//    minimum viable shape: ONE storage-setting primitive (internal) +
//    TWO public surfaces (SPI'd unchecked, plain throwing) that delegate
//    to it. The migration cascade must adopt this three-layer shape, NOT
//    the two-layer shape in the original handoff plan.
