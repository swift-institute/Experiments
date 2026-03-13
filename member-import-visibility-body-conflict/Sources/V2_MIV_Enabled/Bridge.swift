// V2: SwiftUI bridge in a DIFFERENT file, MemberImportVisibility ON
// Expected: public import SwiftUI leaks to Type.swift, causing body conflict

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
