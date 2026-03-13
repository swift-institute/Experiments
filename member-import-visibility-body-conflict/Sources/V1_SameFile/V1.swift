// V1: public import SwiftUI in SAME FILE as stored `body` property
// Tests: Does having SwiftUI visible in the same file as the stored body cause a conflict?

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

public struct MyDoc<Body: CustomView>: CustomView {
    public let body: Body
    public init(body: Body) { self.body = body }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
