// V2: Both protocols have associatedtype Body, stored property satisfies CustomView.body
// Generic parameter NOT named Body but stored property IS named body
// Tests: Can the compiler disambiguate two `Body` associated types?

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

public struct MyDoc<Content: CustomView>: CustomView {
    // CustomView.Body is satisfied by Content (via typealias)
    // SwiftUI.View.Body should be satisfied by NSViewRepresentable's default
    public typealias Body = Content
    public let body: Content  // satisfies CustomView.body
    public init(body: Content) { self.body = body }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
