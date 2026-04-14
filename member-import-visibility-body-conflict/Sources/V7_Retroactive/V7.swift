// V7: @retroactive on the NSViewRepresentable conformance
// Purpose:   Verify that `@retroactive` does NOT resolve the associated-type
//            collision between `HTML.View.Body` and `SwiftUI.View.Body`.
//            The attribute's own applicability rules reject this use because
//            both the conforming type (`HTML.Document`) and the conformance
//            itself live in the same (this) module.
// Toolchain: Swift 6.3
// Date:      2026-04-13
// Result:    REFUTED — `@retroactive` is rejected by the compiler because the
//            conforming type's module owns it; the attribute only applies when
//            a conformance is declared outside both the protocol's module and
//            the conforming type's module. The same-name `Body` associated
//            type merge remains unsolvable either way.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit

// Self-contained mirror of the `HTML.View` / `HTML.Document` surface used
// in the coenttb case — associated type named `Body`, generic parameters
// named `Body` and `Head`.
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

// Attempted fix: add `@retroactive` to the cross-module conformance.
// Expected diagnostic: `@retroactive` only applies when the conformance is
// declared outside both the protocol's module and the conforming type's
// module. `HTML.Document` lives in THIS module, so `@retroactive` is rejected.
extension HTML.Document: @retroactive NSViewRepresentable
where Body: HTML.View, Head: HTML.View {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
