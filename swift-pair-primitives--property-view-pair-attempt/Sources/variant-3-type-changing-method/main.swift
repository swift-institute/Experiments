// MARK: - Variant 3: Type-changing method on PairLike-bridged View
//
// Purpose: Test whether a consuming method on a Property.Typed View can return
//   a Pair with a different First-type. This is the call-site shape we want:
//   `pair.map.first { $0.uppercased() }` returning `Pair<NewFirst, Second>`.
//
// Hypothesis: CONFIRMED for the Copyable tier — Property.Typed owns Base after
//   `init(_:)`; a consuming method on the View can read `base.first` /
//   `base.second` (copying them for Copyable elements) and construct a fresh
//   `Pair<NewFirst, Base.Second>`. The View is consumed in the process.
//
// Toolchain: Swift 6.3.1 (Apple swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Result: REFUTED
// Diagnostic: <unknown>:0: error: 'self' is borrowed and cannot be consumed
//   (SIL-level diagnostic, no source location). The `var map` accessor's
//   `consuming get` cannot consume `self` because Pair is nominally
//   `~Copyable` even when conditionally Copyable; the implicit copy that
//   makes the README's Stack pattern work for nominally-Copyable Stack
//   does not fire for nominally-~Copyable Pair.
//   Tested with both `var map: ... { Property.Typed(self) }` (default
//   borrowing get) and `consuming get { Property.Typed(self) }` — both
//   produce the same error after experimental flags `Lifetimes` /
//   `LifetimeDependence` / `SuppressedAssociatedTypes` are enabled.
// Command: swift build --target variant-3-type-changing-method
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

    var map: Property<Map>.Typed<First> {
        consuming get { Property<Map>.Typed(self) }
    }
}

extension Property.Typed
where Base: PairLike,
      Base: Copyable,
      Element == Base.First
{
    consuming func first<NewFirst, E: Error>(
        _ transform: (Element) throws(E) -> NewFirst
    ) throws(E) -> Pair<NewFirst, Base.Second> {
        try Pair<NewFirst, Base.Second>(transform(base.first), base.second)
    }

    consuming func second<NewSecond, E: Error>(
        _ transform: (Base.Second) throws(E) -> NewSecond
    ) throws(E) -> Pair<Element, NewSecond> {
        try Pair<Element, NewSecond>(base.first, transform(base.second))
    }
}

let p = Pair("hello", 42)
let upper: Pair<String, Int> = p.map.first { $0.uppercased() }
print("V3 first transform: Pair(\(upper.first), \(upper.second))")

let q = Pair(7, "answer")
let widened: Pair<Int, String> = q.map.second { $0.uppercased() }
print("V3 second transform: Pair(\(widened.first), \(widened.second))")
