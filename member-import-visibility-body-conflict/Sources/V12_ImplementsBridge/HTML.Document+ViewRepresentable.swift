// SwiftUI bridge conformances — split into a separate file to match the
// real swift-html-rendering HTML.Document+ViewRepresentable.swift layout.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import WebKit

extension HTML.Document: SwiftUI.View where Body: HTML.View, Head: HTML.View {}

extension HTML.Document: SwiftUI.NSViewRepresentable where Body: HTML.View, Head: HTML.View {
    public typealias NSViewType = WKWebView
    @MainActor public func makeNSView(context: NSViewRepresentableContext<Self>) -> WKWebView { WKWebView() }
    @MainActor public func updateNSView(_ view: WKWebView, context: NSViewRepresentableContext<Self>) {}
}
#endif
