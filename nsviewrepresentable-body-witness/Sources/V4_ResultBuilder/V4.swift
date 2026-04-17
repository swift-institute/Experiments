// V4: With @resultBuilder on the custom protocol's body requirement
// Tests: Does adding a result builder attribute affect witness resolution?
//
// Toolchain: Swift 6.3 (Xcode 26)
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT (adding @resultBuilder does not affect associated-type unification; MyDoc<Body> still fails to conform to SwiftUI.View)
// Platform: macOS 26 (arm64)
// Result: REFUTED — @resultBuilder operates on call-site syntax, not on protocol witness resolution; the underlying associated-type collision remains.

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit
import CustomProtocol

public protocol BuilderView {
    associatedtype Body: BuilderView
    @CustomBuilder var body: Body { get }
}

extension CustomNever: BuilderView {}
extension CustomText: BuilderView {}

public struct MyDoc<Body: BuilderView>: BuilderView {
    public let body: Body
    public init(@CustomBuilder body: () -> Body) { self.body = body() }
}

extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
