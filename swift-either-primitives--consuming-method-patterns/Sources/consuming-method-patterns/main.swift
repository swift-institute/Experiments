// MARK: - Consuming Method Patterns for ~Copyable Either Arms
//
// Purpose: Verify that swift-either-primitives can ship `consuming` variants
//          of its functor methods on `where Left, Right: ~Copyable` extensions,
//          allowing ~Copyable arms to flow through map / fold / swap / flatMap
//          without copying.
//
// Hypothesis: The seven `consuming` method shapes (map right, map left,
//             map both, swapped, fold, flatMap right, flatMap left) compile,
//             link, and execute correctly on `~Copyable` Either arms. The
//             `consuming Self` + `switch consume self` + `consume payload`
//             pattern is sufficient.
//
// Toolchain: Apple Swift 6.3.1 (default)
// Platform:  macOS 15+ (arm64)
//
// Result: CONFIRMED — all 7 consuming variants compile, link, and execute
//                     correctly on `~Copyable` Either arms in debug AND
//                     release mode. Cross-module shape verified: the
//                     `ConsumingMethodPatterns` library declares the
//                     consuming methods as extensions on `Either where
//                     Left: ~Copyable, Right: ~Copyable`; the executable
//                     target imports the library and uses them on
//                     `Either<Resource, Resource>` / `Either<Resource,
//                     OtherResource>` where Resource is a `~Copyable`
//                     stored type. Output:
//
//                     V1: right from-id-7
//                     V2: left left-id-11
//                     V3: right R42
//                     V4: left orig
//                     V5: 6
//                     V6: right positive-5
//                     V7: left err-404
//
//                     Build receipts: Outputs/build.txt (debug),
//                     Outputs/release-mode-pass.txt (release),
//                     Outputs/cross-module-pass.txt (cross-module),
//                     Outputs/run.txt (runtime).
//
// Implication: swift-either-primitives can ship `consuming` variants of
//              its functor methods on `where Left: ~Copyable, Right: ~Copyable`
//              extensions in the main target. The `consuming Self` +
//              `switch consume self` + `consume payload` pattern is
//              sufficient. No FIXME-prefixing needed (unlike stdlib
//              Result.swift's `_consumingMap` / `_borrowingMap`).
//
// Date: 2026-05-08
//
// Status: SUPERSEDED 2026-05-09 — the seven verified consuming variants
//         have been promoted to the main target as overloads of
//         `Either.map(right:)` / `map(left:)` / `map(left:right:)` /
//         `swapped()` / `fold(left:right:)` / `flatMap(right:)` /
//         `flatMap(left:)` on `where Left: ~Copyable, Right: ~Copyable`.
//         Per [API-NAME-002] the institute keyword-adjective prohibition
//         on `consuming*` method names — `consumingMap` etc. would be
//         forbidden — so promotion went via overloading the existing
//         non-consuming names with `consuming Self` + `consuming` arg
//         modifiers. Swift overload resolution prefers the more-specific
//         (Copyable) extension when arms are Copyable; the consuming
//         overload fires only on `~Copyable` arms.
//
//         The experiment is retained as the empirical-validation record
//         of the seven shapes per [EXP-008] (Active → Superseded).

import ConsumingMethodPatterns
import Either_Primitives

// MARK: - ~Copyable test resource

struct Resource: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

struct OtherResource: ~Copyable {
    let label: String
    init(_ label: String) { self.label = label }
}

// MARK: - V1: consuming map(right:) on ~Copyable arms

func runV1() {
    let either: Either<Resource, Resource> = .right(Resource(7))
    let mapped = either.consumingMap(right: { (resource: consuming Resource) -> OtherResource in
        OtherResource("from-id-\(resource.id)")
    })
    switch mapped {
    case .left(let resource):
        print("V1 unexpected left: \(resource.id)")
    case .right(let other):
        print("V1: right \(other.label)")
    }
}

// MARK: - V2: consuming map(left:) on ~Copyable arms

func runV2() {
    let either: Either<Resource, Resource> = .left(Resource(11))
    let mapped = either.consumingMap(left: { (resource: consuming Resource) -> OtherResource in
        OtherResource("left-id-\(resource.id)")
    })
    switch mapped {
    case .left(let other):
        print("V2: left \(other.label)")
    case .right(let resource):
        print("V2 unexpected right: \(resource.id)")
    }
}

// MARK: - V3: consuming map(left:right:) on ~Copyable arms

func runV3() {
    let either: Either<Resource, Resource> = .right(Resource(42))
    let mapped = either.consumingMap(
        left: { (l: consuming Resource) -> OtherResource in OtherResource("L\(l.id)") },
        right: { (r: consuming Resource) -> OtherResource in OtherResource("R\(r.id)") }
    )
    switch mapped {
    case .left(let other):
        print("V3 unexpected left: \(other.label)")
    case .right(let other):
        print("V3: right \(other.label)")
    }
}

// MARK: - V4: consuming swapped() on ~Copyable arms

func runV4() {
    let either: Either<Resource, OtherResource> = .right(OtherResource("orig"))
    let swapped = either.consumingSwapped()
    switch swapped {
    case .left(let other):
        print("V4: left \(other.label)")
    case .right(let resource):
        print("V4 unexpected right: \(resource.id)")
    }
}

// MARK: - V5: consuming fold(left:right:) on ~Copyable arms

func runV5() {
    let either: Either<Resource, OtherResource> = .right(OtherResource("folded"))
    let result = either.consumingFold(
        left:  { (r: consuming Resource) -> Int in r.id },
        right: { (o: consuming OtherResource) -> Int in o.label.count }
    )
    print("V5: \(result)")
}

// MARK: - V6: consuming flatMap(right:) on ~Copyable arms

func runV6() {
    let either: Either<Resource, Resource> = .right(Resource(5))
    let chained = either.consumingFlatMap(right: { (r: consuming Resource) -> Either<Resource, OtherResource> in
        r.id > 0 ? .right(OtherResource("positive-\(r.id)")) : .left(Resource(-1))
    })
    switch chained {
    case .left(let resource):
        print("V6 unexpected left: \(resource.id)")
    case .right(let other):
        print("V6: right \(other.label)")
    }
}

// MARK: - V7: consuming flatMap(left:) on ~Copyable arms

func runV7() {
    let either: Either<Resource, Resource> = .left(Resource(404))
    let chained = either.consumingFlatMap(left: { (l: consuming Resource) -> Either<OtherResource, Resource> in
        .left(OtherResource("err-\(l.id)"))
    })
    switch chained {
    case .left(let other):
        print("V7: left \(other.label)")
    case .right(let resource):
        print("V7 unexpected right: \(resource.id)")
    }
}

// MARK: - Run

runV1()
runV2()
runV3()
runV4()
runV5()
runV6()
runV7()
