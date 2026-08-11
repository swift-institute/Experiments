// MARK: - Variant 2: PairLike protocol bridge (Copyable tier, Property.Typed)
//
// Purpose: Test whether adding a `PairLike` protocol with Copyable associated
//   types `First` and `Second` lets a `Property.Typed<Element>` extension
//   reach the second component (`Base.Second`) via the protocol.
//
// Hypothesis: PARTIAL — the bridge unblocks the where-clause binding for the
//   Copyable tier (Swift 6.3 forbids `~Copyable` associated types without
//   the `SuppressedAssociatedTypes` experimental feature, so the ~Copyable
//   tier is doubly-blocked). Even with the bridge, the type-changing
//   transform is still blocked (V3 tests).
//
// Toolchain: Swift 6.3.1 (Apple swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Result: CONFIRMED (partial)
// Output: V2 firstType: String / V2 secondType: Int
// Caveat: Works for the Copyable tier with a simple PairLike protocol
//   (associated types First, Second). The ~Copyable tier requires
//   `~Copyable` associated types which need the SuppressedAssociatedTypes
//   experimental feature (a feature gap, not just an architectural cost).
//   Even with this bridge, type-changing transforms remain blocked (V3-V5).
// Command: swift build --target variant-2-pairlike-bridge && swift run variant-2-pairlike-bridge
// Date: 2026-05-08
// Cross-reference: matches `swift-property-primitives/Research/case-study-dictionary-primitives-migration-failure.md`
//   §4.2.1 "Protocol Witness (types in Tag) — Works — Requires marker protocols on all tags"

import Pair_Primitives
import Property_Primitives

protocol PairLike {
    associatedtype First
    associatedtype Second
}

extension Pair: PairLike where First: Copyable, Second: Copyable {}

extension Pair where First: Copyable, Second: Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Pair<First, Second>>
}

extension Pair where First: Copyable, Second: Copyable {
    enum Map {}

    var map: Property<Map>.Typed<First> {
        Property<Map>.Typed(self)
    }
}

// PairLike-bridged extension: bind Element to Base.First; reach Base.Second.
extension Property.Typed
where Base: PairLike,
      Base: Copyable,
      Element == Base.First
{
    var firstType: Any.Type {
        Element.self
    }

    var secondType: Any.Type {
        Base.Second.self
    }
}

let p = Pair("hello", 42)
print("V2 firstType: \(p.map.firstType)")
print("V2 secondType: \(p.map.secondType)")
