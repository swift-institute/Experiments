// V3: Generic parameter named Body (mirrors HTML.Document<Body, Head>)
// Tests: Does the generic parameter name `Body` collide with SwiftUI.View.Body?

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

public struct MyDoc<Body: CustomView>: CustomView {
    // Body is the generic parameter, also the associated type for CustomView
    // SwiftUI.View.Body should be provided by NSViewRepresentable
    public let body: Body
    public init(body: Body) { self.body = body }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
