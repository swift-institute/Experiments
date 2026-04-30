// V12: The HTML.Document bridge shape — two-`@_implements`-stamps pattern.
//
// Purpose:   Demonstrate the production-recommended two-stamp pattern for
//            bridging a type through two protocols whose same-named
//            associated type requirements would otherwise unify. Mirrors
//            the real swift-html-rendering HTML.Document shape as closely
//            as this minimal form allows.
//
// Relationship to V11: V11 is the minimal single-stamp case — it works,
// and proves the @_implements mechanism. V12 shows the shape the real
// production bridge actually uses. In real swift-html-rendering, a
// single stamp was insufficient and produced "multiple matching types
// named 'Body'"; the fix was adding a second stamp for SwiftUI.View.
// This minimal V12 reproduction does NOT itself trigger the single-stamp
// failure — the real package has additional context (many more HTML
// element conformances, @HTML.Builder result-builder plumbing, specific
// import graph) that the minimal form omits. Treat V12 as a receipt for
// "two stamps compile cleanly," and treat the real HTML.Document.swift
// on GitHub as the receipt for "single stamp fails in that context."
//
// Toolchain: Swift 6.3.1
// Status: SUPERSEDED 2026-04-30 — HTML.Document<Body, Head> View conformance surface changed; experiment requires re-targeting against current HTML/View shape
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT (deep API drift; SUPERSEDED per [META-007])
// Date:      2026-04-20
// Result:    CONFIRMED — two-stamp version compiles in debug and release.
//            Applied pattern at swift-html-rendering HTML.Document.swift.

#if canImport(SwiftUI) && os(macOS)
internal import SwiftUI

// MARK: - L3 namespace with an ambient `Body` type (like WHATWG_HTML.Body,
// the <body> HTML element struct). Its presence in the enclosing scope is
// part of what makes the conformance resolver see multiple candidates.

public enum HTML {
    public struct Body {
        public init() {}
    }
}

extension HTML {
    public protocol View: Rendering.View where Body: HTML.View {
        var body: Body { get }
    }
}

extension Never: HTML.View {}

extension HTML {
    public protocol DocumentProtocol: HTML.View {
        associatedtype Head: HTML.View
        var head: Head { get }
    }
}

// MARK: - The bridge type
//
// Generic parameter named `Body` — the SwiftUI-familiar spelling. The type
// must conform to HTML.DocumentProtocol (→ HTML.View → Rendering.View) AND
// to NSViewRepresentable (→ SwiftUI.View, constrained `where Self.Body ==
// Never`). Both protocols declare `associatedtype Body`; Swift unifies them.

extension HTML {
    public struct Document<Body: HTML.View, Head: HTML.View>: HTML.DocumentProtocol {
        // TWO STAMPS — the production pattern.
        // One stamp per protocol pins each Body binding independently.
        @_implements(Rendering.View, Body)
        public typealias _RenderingBody = Body

        @_implements(SwiftUI.View, Body)
        public typealias _SwiftUIBody = Never

        public let head: Head
        public let body: Body

        public init(head: Head, body: Body) {
            self.head = head
            self.body = body
        }

        public static func _render(_ v: borrowing Self, context: inout Rendering.Context) {}
    }
}

#endif
