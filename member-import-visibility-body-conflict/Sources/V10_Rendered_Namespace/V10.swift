// V10: Render namespace + `associatedtype Rendered` — the blog's recommended fix
// Purpose:   Verify that the specific rename recommended in
//            Blog/Draft/associated-type-trap-final.md — protocol namespace
//            `Rendering → Render`, associated type `Body → Rendered` —
//            resolves the unification collision with SwiftUI.View.Body.
//            Unlike V6 (which renames to `Content`, a name SwiftUI itself
//            uses on ForEach/Group/ViewModifier), V10 uses `Rendered`,
//            which appears in no Apple framework protocol's associated
//            type. The associated-type anchor unifier matches simple
//            identifiers at the protocol declaration site; `Rendered`
//            and `Body` are different simple identifiers and cannot
//            merge.
// Toolchain: Swift 6.3
// Date:      2026-04-15
// Result:    CONFIRMED — MyDoc<Body, Head> conforms to both Render.View
//            (via associatedtype Rendered = Body) and NSViewRepresentable
//            (which sets SwiftUI.View.Body = Never through the
//            makeNSView/updateNSView witnesses) without the unification
//            error V1–V5 produce. The generic parameter named `Body` is
//            a type-scope identifier, not an associated type, so it does
//            not participate in anchor unification.
//
// Relationship to V6: V6 proves the mechanism (a distinct associated type
// name resolves the collision). V10 proves the specific recommendation
// the blog post makes — `Rendered` as the chosen name and `Render` as
// the protocol namespace. V6's `Content` name is rejected by the blog at
// line 236 ("Picking another popular word just moves the trap") because
// SwiftUI already uses `Content`; V10 uses a name that does not.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit

// Render namespace — the blog's recommended protocol namespace
// (Rendering → Render), per [API-NAME-001] Nest.Name pattern.
public enum Render {}

extension Render {
    // Render.View with `associatedtype Rendered` — the critical rename
    // from `Body`. The self-refinement constraint (`Rendered: Render.View`)
    // mirrors the Rendering.View → Rendering.View pattern in the blog's
    // original failing code, so V10 is a true apples-to-apples test of
    // the rename.
    public protocol View {
        associatedtype Rendered: Render.View
        var body: Rendered { get }
    }
}

// Struct with a generic parameter named `Body` — matching the blog's
// HTML.Document<Body: HTML.View, Head: HTML.View> shape. The generic
// parameter `Body` is a type-scope identifier, not an associated type,
// and does not unify with SwiftUI.View's associated type of the same name.
public struct MyDoc<Body: Render.View, Head: Render.View>: Render.View {
    public typealias Rendered = Body
    public let head: Head
    public let body: Body

    public init(body: Body, head: Head) {
        self.body = body
        self.head = head
    }
}

// The key test: NSViewRepresentable conformance on MyDoc.
//
// - NSViewRepresentable refines SwiftUI.View with a default
//   `typealias Body = Never` supplied by the makeNSView/updateNSView
//   witnesses.
// - MyDoc's Render.View associated type is named `Rendered`, not `Body`.
// - The associated-type anchor unifier matches simple identifiers at
//   the protocol declaration site. "Rendered" and "Body" are distinct
//   identifiers → no merge → no conflicting constraint → conformance
//   compiles.
extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
