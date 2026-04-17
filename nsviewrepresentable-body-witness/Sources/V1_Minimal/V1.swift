// V1: Minimal — generic parameter NOT named Body
// Tests: Does NSViewRepresentable's default body coexist with a stored body
//        when there's no associated type name collision?
//
// Toolchain: Swift 6.3 (Xcode 26)
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT (MyDoc<Content> still does not conform to SwiftUI.View — the compiler unifies CustomView.Body with SwiftUI.View.Body even without name collision; conformance fails)
// Platform: macOS 26 (arm64)
// Result: REFUTED — even without name collision, the associated-type unifier still merges; NSViewRepresentable's default `body` cannot coexist with a stored `body` of the custom protocol's associated type.

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
