// V6: Associated type named `Content` instead of `Body`
// Hypothesis: No name collision with SwiftUI.View.Body, NSViewRepresentable works

#if canImport(SwiftUI) && os(macOS)
public import SwiftUI
public import AppKit

// Protocol with Content (not Body) as associated type — matches coenttb Renderable
public protocol ContentView {
    associatedtype Content: ContentView
    var body: Content { get }
}

public struct ContentNever: ContentView {
    public typealias Content = ContentNever
    public var body: ContentNever { fatalError() }
}

public struct ContentText: ContentView {
    public typealias Content = ContentNever
    public var body: ContentNever { fatalError() }
}

// The struct has a generic parameter named Body (like HTML.Document)
// But the protocol's associated type is Content, not Body
public struct MyDoc<Body: ContentView, Head: ContentView>: ContentView {
    public typealias Content = Body
    public let head: Head
    public let body: Body
    public init(body: Body, head: Head) {
        self.body = body
        self.head = head
    }
}

// NSViewRepresentable conformance — sets SwiftUI.View.Body = Never
// ContentView.Content = Body (the generic param) — different name, no collision
extension MyDoc: NSViewRepresentable {
    public typealias NSViewType = NSView
    @MainActor public func makeNSView(context: Context) -> NSView { NSView() }
    @MainActor public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
