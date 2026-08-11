// EscapableArmSupport.swift
// Empirical verification that Pair admits `~Escapable` arms across the
// functor surface after the type-level upgrade landed in
// `Sources/Pair Primitives/Pair.swift`.
//
// Toolchains verified 2026-05-09:
//   - Swift 6.3.1 (Xcode 26.4 default)
//   - Swift 6.4-dev nightly 2026-05-07-a (`org.swift.64202605071a`)
//   - Swift 6.4-dev/Embedded
//
// Status: CONFIRMED. The variants below are the verified working shapes
// codified in `Sources/Pair Primitives/`. The "would fail" comment block
// documents Gap A — closure-parameter lifetime dependencies for full
// ~Escapable closure inputs/outputs are not yet ready.
//
// Type-level upgrade landed: Pair is now
// `Pair<First: ~Copyable & ~Escapable, Second: ~Copyable & ~Escapable>:
// ~Copyable, ~Escapable`. Conditional Copyable / Escapable / Sendable
// extensions explicitly state the orthogonal axis.

public import Pair_Primitives

// MARK: - Test fixtures

public struct NEResource: ~Escapable {
    public let id: Int
    @_lifetime(immortal)
    public init(_ id: Int) { self.id = id }
}

// MARK: - V1: type-level construction with ~Escapable arms (CONFIRMED)

@_lifetime(copy a, copy b)
public func v1_constructPairNE(
    _ a: consuming NEResource,
    _ b: consuming NEResource
) -> Pair<NEResource, NEResource> {
    Pair(a, b)
}

// MARK: - V2: swapped admits both arms ~Escapable (CONFIRMED)

@_lifetime(copy a, copy b)
public func v2_swapPairNE(
    _ a: consuming NEResource,
    _ b: consuming NEResource
) -> Pair<NEResource, NEResource> {
    let p = Pair(a, b)
    return p.swapped()
}

// MARK: - V3: apply admits both arms ~Escapable (CONFIRMED)

public func v3_applyPairNE(
    _ a: consuming NEResource,
    _ b: consuming NEResource
) -> Int {
    let p = Pair(a, b)
    return p.apply { lhs, rhs in
        lhs.id + rhs.id
    }
}

// MARK: - V4: map(first:) admits ~Escapable Second (un-transformed arm) (CONFIRMED)

@_lifetime(copy second)
public func v4_mapFirstNESecond(
    _ first: Int,
    _ second: consuming NEResource
) -> Pair<String, NEResource> {
    let p = Pair(first, second)
    return p.map(first: { String($0) })
}

// MARK: - V5: map(second:) admits ~Escapable First (un-transformed arm) (CONFIRMED)

@_lifetime(copy first)
public func v5_mapSecondNEFirst(
    _ first: consuming NEResource,
    _ second: Int
) -> Pair<NEResource, String> {
    let p = Pair(first, second)
    return p.map(second: { String($0) })
}

// MARK: - BLOCKED: map(first:second:) with both arms ~Escapable (Gap A)
//
// Closure-bearing on both arms hits the same Gap A as Either's
// map(left:right:). The shipped `Pair.map(_:first:second:)` requires
// both arms Escapable.
//
//     error: lifetime-dependent value escapes its scope

// MARK: - BLOCKED: stdlib Equatable/Hashable/Comparable conformances on ~Escapable arms
//
// Stdlib protocols themselves require Escapable. The diagnostic on a
// hypothetical `Pair<NEResource, NEResource>: Equatable` extension is:
//
//     error: composition cannot contain '~Escapable' when another
//     member requires 'Escapable'
//
// The institute `Equation.Protocol` / `Hash.Protocol` / `Comparison.Protocol`
// conformances DO admit ~Escapable arms (after the upstream protocol
// upgrade in swift-equation/hash/comparison-primitives 3495e50 / 0e5708e
// / a4fd209) — those satisfy the SE-0499 typealias to stdlib on Swift 6.4+
// only when both arms are Copyable + Escapable.
