// V1: Minimal — generic parameter NOT named Body
// Tests: Does NSViewRepresentable's default body coexist with a stored body
//        when there's no associated type name collision?

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

public struct MyDoc<Content: CustomView>: CustomView {
    public typealias Body = Content
    public let body: Content
    public init(body: Content) { self.body = body }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
