// EscapableArmSupport.swift
// Empirical verification of `~Escapable` arm support across Either's
// functor surface. Each variant compiles iff the corresponding shape
// is supported on the current toolchain.
//
// Toolchains verified 2026-05-09:
//   - Swift 6.3.1 (Xcode 26.4 default) — all PASS variants compile
//   - Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`) — same
//   - Swift 6.4-dev/Embedded — same (built via -enable-experimental-feature Embedded)
//
// Status: CONFIRMED. The variants below are the verified working shapes
// codified in `Sources/Either Primitives/`. The "would fail" comment blocks
// document Gap A — closure-parameter lifetime dependencies for ~Escapable
// closure inputs/outputs are not yet ready (see
// `swift-institute/Research/nonescapable-ecosystem-state.md` §5).

public import Either_Primitives

// MARK: - Test fixtures

public struct NEResource: ~Escapable {
    public let id: Int
    @_lifetime(immortal)
    public init(_ id: Int) { self.id = id }
}

// MARK: - V1: swapped admits both arms ~Escapable (CONFIRMED)

@_lifetime(copy lhs, copy rhs)
public func v1_swapBothNE(
    _ lhs: consuming NEResource,
    _ rhs: consuming NEResource
) -> Either<NEResource, NEResource> {
    let either: Either<NEResource, NEResource> = .left(lhs)
    let flipped = either.swapped()  // instance form — generic inference clean
    let _ = rhs
    return flipped
}

// MARK: - V2: value(of:) admits ~Escapable Right (CONFIRMED)

@_lifetime(copy r)
public func v2_extractNERight(_ r: consuming NEResource) -> NEResource {
    let e: Either<Never, NEResource> = .right(r)
    return value(of: e)
}

// MARK: - V3: value(of:) admits ~Escapable Left (CONFIRMED)

@_lifetime(copy l)
public func v3_extractNELeft(_ l: consuming NEResource) -> NEResource {
    let e: Either<NEResource, Never> = .left(l)
    return value(of: e)
}

// MARK: - V4: map(right:) admits ~Escapable Left (un-transformed arm) (CONFIRMED)

@_lifetime(copy lhs)
public func v4_mapRightNELeft(
    _ lhs: consuming NEResource,
    _ rhs: Int
) -> Either<NEResource, String> {
    let either: Either<NEResource, Int> = .right(rhs)
    let _ = lhs  // demonstrate the constraint allows ~Escapable Left
    return either.map(right: { String($0) })
}

// MARK: - V5: map(left:) admits ~Escapable Right (un-transformed arm) (CONFIRMED)

@_lifetime(copy rhs)
public func v5_mapLeftNERight(
    _ lhs: Int,
    _ rhs: consuming NEResource
) -> Either<String, NEResource> {
    let either: Either<Int, NEResource> = .right(rhs)
    return either.map(left: { String($0) })
}

// MARK: - BLOCKED: flatMap with both arms ~Escapable (Gap A)
//
// The closure returns its own Either with independent lifetime; result
// can't be tied to `either` via `@_lifetime(copy either)`. Diagnostic:
//
//   error: lifetime-dependent value escapes its scope
//
// Verified on 2026-05-07-a nightly. flatMap stays Escapable-only on both
// arms in the shipped surface.

// MARK: - BLOCKED: map(left:right:) with both arms ~Escapable (Gap A)
//
// Same shape as flatMap — both arms are closure-transformed; can't
// guarantee result lifetime. Diagnostic same as above. The shipped
// `map(left:right:)` requires both arms Escapable.

// MARK: - BLOCKED: Either<Never, T>.value property accessor for ~Copyable T
//
// `consuming get` on a property over a generic ~Copyable enum payload
// is structurally rejected on Swift 6.4-dev nightly 2026-05-07-a even
// with `@_owned` + UnderscoreOwned experimental feature:
//
//   error: noncopyable 'X' cannot be consumed when captured by an
//   escaping closure or borrowed by a non-Escapable type
//
// Free function `value(of:)` is the working extraction path today.
// See `swift-institute/Research/noncopyable-property-extract-via-underscore-owned.md`.
