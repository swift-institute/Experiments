// V11: `@_implements` as the escape hatch for same-named associated types
// Purpose:   Verify that `@_implements(Protocol, Name)` on a typealias
//            lets a single type satisfy two protocols' same-named associated
//            type requirements with different concrete bindings. Mirrors the
//            Rendering.View + SwiftUI.View collision described in the blog,
//            using the exact Rendering.View shape (~Copyable protocol,
//            SuppressedAssociatedTypes) rather than a simplified stand-in.
// Toolchain: Swift 6.3.1 (baseline feature — always on)
// Date:      2026-04-20
// Result:    CONFIRMED — compiles in debug, release, and
//            release-with-whole-module-optimization. Witness-table dispatch
//            resolves `Self.Body` to the generic parameter for the custom
//            protocol and to `Never` for SwiftUI.View independently.
//
// Relationship to other variants:
// - V6  (Content rename)             : works, but requires renaming the custom
//                                      protocol's associated type.
// - V9  (wrapper)                    : works, but taxes every call site.
// - V10 (Rendered namespace rename)  : works, but rename is paid ecosystem-wide.
// - V11 (this)                       : works, no rename anywhere; `@_implements`
//                                      is paid at the one bridge type only.
//
// This is the variant the blog recommends as the preferred fix when you own
// the conforming type but want to keep idiomatic names on both protocols.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import WebKit

// MARK: - Custom rendering protocol (stand-in for Rendering.View)
//
// Uses `~Copyable` + `SuppressedAssociatedTypes` to match the exact shape of
// the real Rendering.View in swift-rendering-primitives. The associated type
// is named `Body` — the idiomatic choice that collides with SwiftUI.View.Body.

public protocol CustomView: ~Copyable {
    associatedtype Body: CustomView & ~Copyable
    var body: Body { get }
}

extension Never: CustomView {
    public typealias Body = Never
    public var body: Never { fatalError() }
}

public struct CustomLeaf: CustomView {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init() {}
}

// MARK: - Bridge type
//
// A document type that bridges CustomView to SwiftUI.View via
// NSViewRepresentable. Both protocols declare `associatedtype Body`. Without
// `@_implements`, the two requirements unify into one binding and the
// conformance is unsatisfiable. The @_implements stamp tells the compiler:
// "for CustomView's Body requirement, use _CustomBody (which resolves to the
// generic parameter Body)". SwiftUI.View.Body = Never is satisfied
// independently by NSViewRepresentable's makeNSView / updateNSView witnesses.

public struct MyDoc<Body: CustomView & Copyable, Head: CustomView & Copyable>: CustomView {
    @_implements(CustomView, Body)
    public typealias _CustomBody = Body

    public let head: Head
    public let body: Body

    public init(head: Head, body: Body) {
        self.head = head
        self.body = body
    }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = WKWebView
    @MainActor public func makeNSView(context: Context) -> WKWebView { WKWebView() }
    @MainActor public func updateNSView(_ view: WKWebView, context: Context) {}
}

// MARK: - Dispatch proof
//
// The two `Self.Body` lookups must resolve to different concrete types for
// the same value. This function pair, called on the same MyDoc value, is
// the minimal demonstration that the witness tables bind independently.

public func customBodyTypeName<T: CustomView>(_ x: borrowing T) -> String {
    String(describing: T.Body.self)
}

public func swiftUIBodyTypeName<T: NSViewRepresentable>(_ x: T) -> String {
    String(describing: T.Body.self)
}
#endif
