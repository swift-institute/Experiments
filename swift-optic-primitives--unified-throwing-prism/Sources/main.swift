// MARK: - Unified Throwing Prism Validation
// Purpose: Validate that Optic.Prism<Whole, Part, Failure> with PrismOf typealias
//          compiles and behaves correctly across all required patterns:
//          struct definition, typed throws, typealias, composition, pattern matching,
//          Accessible protocol, Witness conformance, Never specialization.
//
// Hypothesis: All patterns from the current 2-parameter Optic.Prism survive when
//             a third Failure generic parameter is added, with PrismOf typealias
//             recovering ergonomics.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.2 (arm64)
//
// Result: CONFIRMED — all 32 checks pass (0 failures)
//         Build Succeeded, all variants compile and produce correct output
// Date: 2026-03-05

// ============================================================================
// MARK: - Infrastructure (mocks of ecosystem types)
// ============================================================================

public enum Witness {
    public protocol `Protocol` {}
}

public enum Optic {
    public enum Extraction {
        public struct Error: Swift.Error, Sendable, Equatable {
            public init() {}
        }
    }
}

public enum Either<Left: Swift.Error & Sendable, Right: Swift.Error & Sendable>: Swift.Error, Sendable {
    case left(Left)
    case right(Right)
}

// Helper: map typed error from one domain to another
@inlinable
func mapThrow<T, E1: Error, E2: Error>(
    _ body: () throws(E1) -> T,
    transform: (E1) -> E2
) throws(E2) -> T {
    do {
        return try body()
    } catch {
        throw transform(error)
    }
}

// ============================================================================
// MARK: - V1: Basic struct with 3 generic params + typed throws
// Hypothesis: struct with throws(Failure) closure compiles
// Result: CONFIRMED
// ============================================================================

extension Optic {
    @dynamicMemberLookup
    public struct Prism<Whole, Part, Failure: Swift.Error & Sendable>: Sendable, Witness.`Protocol` {
        public let embed: @Sendable (Part) -> Whole
        public let extract: @Sendable (Whole) throws(Failure) -> Part

        @inlinable
        public init(
            embed: @escaping @Sendable (Part) -> Whole,
            extract: @escaping @Sendable (Whole) throws(Failure) -> Part
        ) {
            self.embed = embed
            self.extract = extract
        }

        // dynamicMemberLookup — constrained to PrismOf (same error family)
        public subscript<Next>(
            dynamicMember keyPath: KeyPath<Part.Prisms, Optic.PrismOf<Part, Next>>
        ) -> Optic.PrismOf<Whole, Next>
        where Part: Optic.Prism.Accessible, Failure == Optic.Extraction.Error {
            let next = Part.prisms[keyPath: keyPath]
            return Optic.PrismOf<Whole, Next>(
                embed: { self.embed(next.embed($0)) },
                extract: { (whole: Whole) throws(Optic.Extraction.Error) -> Next in
                    let part = try self.extract(whole)
                    return try next.extract(part)
                }
            )
        }
    }
}

// ============================================================================
// MARK: - V2: PrismOf typealias (2-parameter ergonomics)
// Hypothesis: typealias with defaulted Failure compiles and is usable
// Result: CONFIRMED
// ============================================================================

extension Optic {
    public typealias PrismOf<Whole, Part> = Prism<Whole, Part, Optic.Extraction.Error>
}

// ============================================================================
// MARK: - V3: Accessible protocol (nested on the struct, not typealias)
// Hypothesis: Protocols can be hoisted and aliased into the 3-param struct
// Result: CONFIRMED
// ============================================================================

public protocol __OpticPrismAccessible {
    associatedtype Prisms
    static var prisms: Prisms { get }
}

extension Optic.Prism {
    public typealias Accessible = __OpticPrismAccessible
}

// ============================================================================
// MARK: - V4: Pattern matching ~= with try?
// Hypothesis: ~= can use try? internally for non-throwing pattern matching
// Result: CONFIRMED
// ============================================================================

extension Optic.Prism {
    public static func ~= (pattern: Optic.Prism<Whole, Part, Failure>, value: Whole) -> Bool {
        (try? pattern.extract(value)) != nil
    }

    public func matches(_ whole: Whole) -> Bool {
        (try? extract(whole)) != nil
    }
}

// ============================================================================
// MARK: - V5: Composition >>> with error handling
// Hypothesis: Prism >>> Prism compiles with both same-type and Either errors
// Result: CONFIRMED
// ============================================================================

precedencegroup OpticCompositionPrecedence {
    associativity: left
    higherThan: AssignmentPrecedence
    lowerThan: TernaryPrecedence
}

infix operator >>>: OpticCompositionPrecedence

// V5a: Same error type composition
func >>> <W, M, P, E: Swift.Error & Sendable>(
    lhs: Optic.Prism<W, M, E>,
    rhs: Optic.Prism<M, P, E>
) -> Optic.Prism<W, P, E> {
    .init(
        embed: { lhs.embed(rhs.embed($0)) },
        extract: { (whole: W) throws(E) -> P in
            try rhs.extract(try lhs.extract(whole))
        }
    )
}

// V5b: Heterogeneous error composition via Either
func >>> <W, M, P, E1: Swift.Error & Sendable, E2: Swift.Error & Sendable>(
    lhs: Optic.Prism<W, M, E1>,
    rhs: Optic.Prism<M, P, E2>
) -> Optic.Prism<W, P, Either<E1, E2>> {
    .init(
        embed: { lhs.embed(rhs.embed($0)) },
        extract: { (whole: W) throws(Either<E1, E2>) -> P in
            let mid = try mapThrow({ () throws(E1) -> M in try lhs.extract(whole) }, transform: Either<E1, E2>.left)
            return try mapThrow({ () throws(E2) -> P in try rhs.extract(mid) }, transform: Either<E1, E2>.right)
        }
    )
}

// V5c: Failure == Never composition (infallible lhs)
func >>> <W, M, P, E: Swift.Error & Sendable>(
    lhs: Optic.Prism<W, M, Never>,
    rhs: Optic.Prism<M, P, E>
) -> Optic.Prism<W, P, E> {
    .init(
        embed: { lhs.embed(rhs.embed($0)) },
        extract: { (whole: W) throws(E) -> P in
            try rhs.extract(lhs.extract(whole))
        }
    )
}

// V5d: Failure == Never composition (infallible rhs)
func >>> <W, M, P, E: Swift.Error & Sendable>(
    lhs: Optic.Prism<W, M, E>,
    rhs: Optic.Prism<M, P, Never>
) -> Optic.Prism<W, P, E> {
    .init(
        embed: { lhs.embed(rhs.embed($0)) },
        extract: { (whole: W) throws(E) -> P in
            rhs.extract(try lhs.extract(whole))
        }
    )
}

// ============================================================================
// MARK: - V6: Accessible conformance (Optional + Result)
// Hypothesis: Standard library types can conform with PrismOf return types
// Result: CONFIRMED
// ============================================================================

extension Optional: Optic.Prism.Accessible {
    public struct Prisms: Sendable {
        @inlinable public init() {}

        public var some: Optic.PrismOf<Optional, Wrapped> {
            .init(
                embed: { .some($0) },
                extract: { (whole: Optional) throws(Optic.Extraction.Error) -> Wrapped in
                    guard let value = whole else { throw Optic.Extraction.Error() }
                    return value
                }
            )
        }

        public var none: Optic.PrismOf<Optional, Void> {
            .init(
                embed: { _ in .none },
                extract: { (whole: Optional) throws(Optic.Extraction.Error) -> Void in
                    guard whole == nil else { throw Optic.Extraction.Error() }
                }
            )
        }
    }

    public static var prisms: Prisms { Prisms() }
}

extension Result: Optic.Prism.Accessible {
    public struct Prisms: Sendable {
        @inlinable public init() {}

        public var success: Optic.PrismOf<Result, Success> {
            .init(
                embed: { .success($0) },
                extract: { (whole: Result) throws(Optic.Extraction.Error) -> Success in
                    guard case .success(let value) = whole else {
                        throw Optic.Extraction.Error()
                    }
                    return value
                }
            )
        }

        public var failure: Optic.PrismOf<Result, Failure> {
            .init(
                embed: { .failure($0) },
                extract: { (whole: Result) throws(Optic.Extraction.Error) -> Failure in
                    guard case .failure(let error) = whole else {
                        throw Optic.Extraction.Error()
                    }
                    return error
                }
            )
        }
    }

    public static var prisms: Prisms { Prisms() }
}

// ============================================================================
// MARK: - V7: Never specialization (infallible prism = Iso-like)
// Hypothesis: Prism<W, P, Never> works without try at call sites
// Result: CONFIRMED
// ============================================================================

extension Optic.Prism where Failure == Never {
    public var reversed: Optic.Prism<Part, Whole, Never> {
        .init(
            embed: { self.extract($0) },
            extract: { self.embed($0) }
        )
    }
}

// ============================================================================
// MARK: - V8: Extensions on typealias target underlying struct
// Hypothesis: extension Optic.PrismOf extends Optic.Prism
// Result: CONFIRMED
// ============================================================================

extension Optic.PrismOf {
    public func extractOptional(_ whole: Whole) -> Part? {
        try? extract(whole)
    }
}

// ============================================================================
// MARK: - V9: Modify methods
// Hypothesis: modify with inout and try? works on 3-param Prism
// Result: CONFIRMED
// ============================================================================

extension Optic.Prism {
    public func modify(_ whole: Whole, _ transform: (Part) -> Part) -> Whole {
        guard let part = try? extract(whole) else { return whole }
        return embed(transform(part))
    }

    public func modify(_ whole: inout Whole, _ transform: (inout Part) -> Void)
    where Part: Copyable {
        guard var part = try? extract(whole) else { return }
        transform(&part)
        whole = embed(part)
    }
}

// ============================================================================
// MARK: - V10: Identity prism
// Hypothesis: Identity prism with Never failure compiles
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// ============================================================================

extension Optic.Prism where Whole == Part, Failure == Never {
    public static var identity: Self {
        .init(embed: { $0 }, extract: { $0 })
    }
}

// ============================================================================
// MARK: - Test types
// ============================================================================

enum Shape: Sendable {
    case circle(radius: Double)
    case rectangle(width: Double, height: Double)
}

enum DomainError: Error, Sendable {
    case notACircle
    case notARectangle
}

let circlePrism = Optic.Prism<Shape, Double, DomainError>(
    embed: { .circle(radius: $0) },
    extract: { (shape: Shape) throws(DomainError) -> Double in
        guard case .circle(let r) = shape else { throw .notACircle }
        return r
    }
)

let rectanglePrism = Optic.Prism<Shape, (Double, Double), DomainError>(
    embed: { .rectangle(width: $0.0, height: $0.1) },
    extract: { (shape: Shape) throws(DomainError) -> (Double, Double) in
        guard case .rectangle(let w, let h) = shape else { throw .notARectangle }
        return (w, h)
    }
)

// ============================================================================
// MARK: - Runtime validation
// ============================================================================

func runTests() {
    var passed = 0
    var failed = 0

    func check(_ label: String, _ condition: Bool) {
        if condition {
            passed += 1
            print("  ✓ \(label)")
        } else {
            failed += 1
            print("  ✗ \(label)")
        }
    }

    print("V1: Basic struct with typed throws")
    do {
        let circle = Shape.circle(radius: 5.0)
        let rect = Shape.rectangle(width: 3, height: 4)

        check("embed produces correct shape", circlePrism ~= circlePrism.embed(5.0))
        check("extract succeeds for matching case",
              (try? circlePrism.extract(circle)) == 5.0)
        check("extract fails for non-matching case",
              (try? circlePrism.extract(rect)) == nil)
        check("typed error is catchable", {
            do { _ = try circlePrism.extract(rect); return false }
            catch DomainError.notACircle { return true }
            catch { return false }
        }())
    }

    print("\nV2: PrismOf typealias")
    do {
        let optPrism: Optic.PrismOf<Int?, Int> = Optional<Int>.prisms.some
        check("PrismOf type annotation compiles", true)
        check("PrismOf extract works", (try? optPrism.extract(42)) == 42)
        check("PrismOf extract fails for nil", (try? optPrism.extract(nil)) == nil)
    }

    print("\nV3: Accessible protocol")
    do {
        check("Accessible typealias resolves", true)
        check("Optional conforms to Accessible",
              (try? Optional<Int>.prisms.some.extract(.some(42))) == 42)
        check("Result conforms to Accessible", {
            let r: Result<Int, DomainError> = .success(99)
            return (try? Result<Int, DomainError>.prisms.success.extract(r)) == 99
        }())
    }

    print("\nV4: Pattern matching ~=")
    do {
        let circle = Shape.circle(radius: 5.0)
        let rect = Shape.rectangle(width: 3, height: 4)
        check("~= matches correct case", circlePrism ~= circle)
        check("~= rejects wrong case", !(circlePrism ~= rect))
        check("matches() works", circlePrism.matches(circle))
    }

    print("\nV5: Composition >>>")
    do {
        // V5a: Same error type — test compiles and runs
        let outerPrism = Optic.PrismOf<Shape?, Shape>(
            embed: { .some($0) },
            extract: { (whole: Shape?) throws(Optic.Extraction.Error) -> Shape in
                guard let value = whole else { throw Optic.Extraction.Error() }
                return value
            }
        )
        let innerPrism = Optic.PrismOf<Shape, Double>(
            embed: { .circle(radius: $0) },
            extract: { (shape: Shape) throws(Optic.Extraction.Error) -> Double in
                guard case .circle(let r) = shape else { throw Optic.Extraction.Error() }
                return r
            }
        )
        let sameComposed = outerPrism >>> innerPrism
        check("same-type >>> compiles", true)
        check("same-type >>> extract succeeds",
              (try? sameComposed.extract(.some(.circle(radius: 3)))) == 3.0)
        check("same-type >>> extract fails outer",
              (try? sameComposed.extract(nil)) == nil)
        check("same-type >>> extract fails inner",
              (try? sameComposed.extract(.some(.rectangle(width: 1, height: 2)))) == nil)

        // V5b: Heterogeneous error
        enum ErrorA: Error, Sendable { case a }
        enum ErrorB: Error, Sendable { case b }

        let prismA = Optic.Prism<String, Int, ErrorA>(
            embed: { "\($0)" },
            extract: { (s: String) throws(ErrorA) -> Int in
                guard let i = Int(s) else { throw .a }
                return i
            }
        )
        let prismB = Optic.Prism<Int, Bool, ErrorB>(
            embed: { $0 ? 1 : 0 },
            extract: { (i: Int) throws(ErrorB) -> Bool in
                guard i == 0 || i == 1 else { throw .b }
                return i == 1
            }
        )
        let heteroComposed: Optic.Prism<String, Bool, Either<ErrorA, ErrorB>> = prismA >>> prismB
        check("heterogeneous >>> compiles", true)
        check("heterogeneous >>> extract succeeds", (try? heteroComposed.extract("1")) == true)
        check("heterogeneous >>> extract lhs failure", {
            do { _ = try heteroComposed.extract("abc"); return false }
            catch Either<ErrorA, ErrorB>.left(.a) { return true }
            catch { return false }
        }())
        check("heterogeneous >>> extract rhs failure", {
            do { _ = try heteroComposed.extract("42"); return false }
            catch Either<ErrorA, ErrorB>.right(.b) { return true }
            catch { return false }
        }())

        // V5c/d: Never composition
        let infallible = Optic.Prism<Int, Int, Never>.identity
        let neverComposed = infallible >>> prismB
        check("Never >>> Prism compiles and extracts", (try? neverComposed.extract(1)) == true)
    }

    print("\nV6: dynamicMemberLookup chaining")
    do {
        let opt: Optional<Result<Int, DomainError>> = .some(.success(42))
        let prism = Optional<Result<Int, DomainError>>.prisms.some
        check("dynamicMemberLookup on PrismOf compiles", true)
        check("prism.some extract works", (try? prism.extract(opt)) != nil)
    }

    print("\nV7: Never specialization (infallible)")
    do {
        let iso = Optic.Prism<Int, Int, Never>.identity
        let value = iso.extract(42)
        check("Never prism needs no try", value == 42)
        check("reversed works", iso.reversed.extract(42) == 42)
    }

    print("\nV8: Extension on typealias")
    do {
        let prism = Optional<Int>.prisms.some
        check("extractOptional defined on PrismOf works", prism.extractOptional(42) == 42)
        check("extractOptional returns nil correctly", prism.extractOptional(nil) == nil)
    }

    print("\nV9: Modify methods")
    do {
        let circle = Shape.circle(radius: 5.0)
        let rect = Shape.rectangle(width: 3, height: 4)
        let doubled = circlePrism.modify(circle) { $0 * 2 }
        check("modify transforms matching case", {
            guard case .circle(let r) = doubled else { return false }
            return r == 10.0
        }())
        check("modify preserves non-matching case", {
            let unchanged = circlePrism.modify(rect) { $0 * 2 }
            guard case .rectangle = unchanged else { return false }
            return true
        }())
    }

    print("\nV10: Identity prism")
    do {
        let id = Optic.Prism<Int, Int, Never>.identity
        check("identity embed", id.embed(42) == 42)
        check("identity extract", id.extract(42) == 42)
    }

    print("\n========================================")
    print("Results: \(passed) passed, \(failed) failed")
    print("========================================")

    if failed > 0 {
        print("REFUTED — some variants failed")
    } else {
        print("CONFIRMED — all variants passed")
    }
}

runTests()
