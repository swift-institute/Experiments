// V8: SE-0491 module selectors on the conformance list
// Purpose:   Verify that the `Module::Name` module-selector syntax introduced
//            by SE-0491 (Swift 6.3) does NOT resolve the merged `Body`
//            associated type. The natural attempt — listing both protocols
//            with explicit module qualification — compiles past parsing but
//            still fails at conformance checking with the same unification
//            error V1–V5 produce.
// Toolchain: Swift 6.3 (experimental feature `ModuleSelector` enabled)
// Date:      2026-04-13
// Result:    REFUTED — `Rendering::View, SwiftUI::View` is accepted
//            syntactically, but the conformance checker still hits the
//            unified-`Body` constraint and emits the same "type does not
//            conform" diagnostic as V1–V5. Module selectors disambiguate
//            top-level name lookup, not associated type merging.
//
//            Note: the more specific `module_selector_dependent_member_type_not_allowed`
//            diagnostic fires only on dependent-member access like
//            `SwiftUI::View.Body`, not in conformance lists. V8 tests the
//            natural workaround attempt; the dependent-member form is a
//            separate (and even less useful) syntax position.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
public import Rendering

// Self-contained mirror of the `HTML.View` / `HTML.Document` surface. The
// local `HTML.View` protocol refines `Rendering.View`, so `HTML.Document`
// already conforms to `Rendering.View` through `HTML.View`. The conformance
// block below attempts to disambiguate its two `View` sources — the local
// `Rendering::View` and `SwiftUI::View` — by naming each with an explicit
// module selector.
public enum HTML {}

extension HTML {
    public protocol View: Rendering.View where Body: HTML.View {}
}

// Note: `Rendering.View` here refers to the top-level `View` protocol
// in the `Rendering` module. SE-0491's `Rendering::View` syntax will
// resolve to the same protocol via module selector lookup.

extension HTML {
    public struct Document<Body: HTML.View, Head: HTML.View>: HTML.View {
        public let head: Head
        public let body: Body
        public init(body: Body, head: Head) {
            self.body = body
            self.head = head
        }
    }
}

// Attempted fix: disambiguate with SE-0491 module selectors on each protocol
// name. Expected diagnostic: module selectors are rejected on dependent
// member types because same-named associated types are merged rather than
// shadowed.
extension HTML.Document: Rendering::View, SwiftUI::View
where Body: HTML.View, Head: HTML.View {}
#endif
