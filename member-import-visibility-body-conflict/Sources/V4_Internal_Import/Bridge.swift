// V4: internal import SwiftUI — tests if reduced visibility avoids the leak
// Expected: FAIL — public conformance requires public protocol visibility

#if canImport(SwiftUI) && os(macOS)
internal import SwiftUI
internal import AppKit
import CustomProtocol

// Note: conformance must be package or internal since SwiftUI is internal-imported
extension MyDoc: @retroactive NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
