// V5: package import SwiftUI — tests if package visibility avoids the leak
// while still allowing package-level conformance

#if canImport(SwiftUI) && os(macOS)
package import SwiftUI
package import AppKit
import CustomProtocol

extension MyDoc: @retroactive NSViewRepresentable {
    package typealias NSViewType = NSView
    @MainActor package func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor package func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
