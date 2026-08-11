// MARK: - Variant 4: Property.Consume — explicit consume() with type-changing return
//
// Purpose: Test whether `Property.Consume<Element>` (which has `consume() -> Base?`
//   for explicit base extraction) can host a type-changing transformation that
//   returns `Pair<NewFirst, Second>`.
//
// Hypothesis: PARTIAL — Property.Consume requires `Base: Copyable`, so it does
//   not help the ~Copyable tier. The PairLike bridge is still needed for
//   binding Second. If both compose, we get the call-site shape we want for
//   the Copyable tier.
//
// Toolchain: Swift 6.3.1 (Apple swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Result: REFUTED
// Diagnostic: <unknown>:0: error: 'self' is borrowed and cannot be consumed
//   AND main.swift:61:18: error: 'p.map' is borrowed and cannot be consumed
//   AND main.swift:66:19: error: 'q.map' is borrowed and cannot be consumed
//   The `var map` accessor uses `_read { yield Property<Map>.Consume(self) }`
//   per the canonical Stack pattern. For nominally-Copyable Stack, the
//   yield-via-implicit-copy works. For nominally-~Copyable Pair, it does not —
//   the yielded View is borrowed, and `var consumer = p.map` cannot then
//   call `consumer.first { ... }` because the consume() inside the method
//   body runs against a borrowed View.
// Command: swift build --target variant-4-property-consume
// Date: 2026-05-08

import Pair_Primitives
import Property_Primitives

protocol PairLike {
    associatedtype First
    associatedtype Second
    var first: First { get }
    var second: Second { get }
}

extension Pair: PairLike where First: Copyable, Second: Copyable {}

extension Pair where First: Copyable, Second: Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Pair<First, Second>>
}

extension Pair where First: Copyable, Second: Copyable {
    enum Map {}

    var map: Property<Map>.Consume<First> {
        _read { yield Property<Map>.Consume(self) }
    }
}

extension Property.Consume
where Base: PairLike,
      Element == Base.First
{
    mutating func first<NewFirst, E: Error>(
        _ transform: (Element) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Base.Second>? {
        guard let pair = consume() else { return nil }
        return try Pair<NewFirst, Base.Second>(transform(pair.first), pair.second)
    }

    mutating func second<NewSecond, E: Error>(
        _ transform: (Base.Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<Element, NewSecond>? {
        guard let pair = consume() else { return nil }
        return try Pair<Element, NewSecond>(pair.first, transform(pair.second))
    }
}

let p = Pair("hello", 42)
var consumer = p.map
let upper: Pair<String, Int>? = try? consumer.first { $0.uppercased() }
print("V4 first transform: \(upper.map { "Pair(\($0.first), \($0.second))" } ?? "nil")")

let q = Pair(7, "answer")
var consumer2 = q.map
let widened: Pair<Int, String>? = try? consumer2.second { $0.uppercased() }
print("V4 second transform: \(widened.map { "Pair(\($0.first), \($0.second))" } ?? "nil")")
