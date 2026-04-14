// V9: wrapper-property escape hatch
// Purpose:   Verify that routing around the `Body` collision by NOT conforming
//            `HTML.Document` to `SwiftUI.View` at all — and instead exposing a
//            `.swiftUIView` property whose returned wrapper struct carries the
//            `NSViewRepresentable` conformance — compiles. The cost: every
//            call site that wants SwiftUI interop grows a ceremonial
//            `.swiftUIView` suffix.
// Toolchain: Swift 6.3
// Date:      2026-04-13
// Result:    CONFIRMED — this variant compiles cleanly. The collision is
//            avoided because `HTML.Document` itself never conforms to
//            `SwiftUI.View`; only `HTMLDocumentSwiftUIWrapper` does, and it
//            has no conflicting associated type. The ergonomic tax (one
//            suffix per call site) is the price.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
public import WebKit

// Self-contained mirror of the `HTML.View` / `HTML.Document` surface — same
// shape as the coenttb case that V1–V5 and V7–V8 cannot make compile.
public enum HTML {}

extension HTML {
    public protocol View {
        associatedtype Body: HTML.View
        var body: Body { get }
    }
}

extension HTML {
    public struct Never: HTML.View {
        public typealias Body = HTML.Never
        public var body: HTML.Never { fatalError() }
        public init() {}
    }
}

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

// Escape hatch: a computed property that produces a wrapper value which
// itself conforms to `NSViewRepresentable`. `HTML.Document` remains free of
// any `SwiftUI.View` conformance, so there is no `Body` associated-type
// merge to resolve.
//
// Note: the wrapper's generic parameters are intentionally renamed away
// from `Body` / `Head`. A generic parameter named `Body` on a type that
// conforms to `NSViewRepresentable` would shadow the protocol's inherited
// `typealias Body = Never` default and re-introduce the collision this
// variant is meant to avoid.
extension HTML.Document {
    @MainActor
    public var swiftUIView: some SwiftUI.View {
        HTMLDocumentSwiftUIWrapper(document: self)
    }
}

private struct HTMLDocumentSwiftUIWrapper<DocBody: HTML.View, DocHead: HTML.View>: NSViewRepresentable {
    let document: HTML.Document<DocBody, DocHead>
    typealias NSViewType = WKWebView
    @MainActor func makeNSView(context: Context) -> WKWebView { fatalError() }
    @MainActor func updateNSView(_ view: WKWebView, context: Context) {}
}
#endif
