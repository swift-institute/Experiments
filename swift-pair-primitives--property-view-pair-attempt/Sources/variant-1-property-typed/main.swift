// MARK: - Variant 1: Property.Typed<Element> with two-generic where-clause
//
// Purpose: Test whether `Property.Typed<Element>` can host an extension whose
//   where-clause binds BOTH `First` (as `Element`) AND `Second` as free type
//   variables on `Pair<First, Second>`.
//
// Hypothesis: REFUTED — `Property.Typed` carries one free generic (`Element`).
//   `Second` cannot appear in the extension where-clause as a free variable;
//   Swift extensions cannot introduce additional generic parameters.
//
// Toolchain: Swift 6.3.1 (Apple swiftlang-6.3.1.1.2)
// Platform: macOS 26 (arm64)
// Result: REFUTED
// Diagnostic: error: cannot find type 'Second' in scope
//   at main.swift:36:29 (and main.swift:38:7) — the where-clause cannot
//   introduce `Second` as a free generic; Property.Typed has only `Element`
//   in its generic signature.
// Command: swift build --target variant-1-property-typed
// Date: 2026-05-08

import Pair_Primitives
import Property_Primitives

extension Pair where First: Copyable, Second: Copyable {
    typealias Property<Tag> = Property_Primitives.Property<Tag, Pair<First, Second>>
}

extension Pair where First: Copyable, Second: Copyable {
    enum Map {}

    var map: Property<Map>.Typed<First> {
        Property<Map>.Typed(self)
    }
}

// Attempt: declare a where-clause binding both Element (= First) and a free Second.
// Expected: compile error — `Second` is not in scope as a generic parameter on
// `Property.Typed`'s extension.
extension Property.Typed
where Tag == Pair<Element, Second>.Map,
      Base == Pair<Element, Second>,
      Element: Copyable,
      Second: Copyable
{
    var firstValue: Element {
        base.first
    }
}

let p = Pair("hello", 42)
print("V1 firstValue: \(p.map.firstValue)")
