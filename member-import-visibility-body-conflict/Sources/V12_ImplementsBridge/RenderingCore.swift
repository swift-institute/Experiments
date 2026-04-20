// V12: multi-target reproduction of the real HTML.Document bridge.
// This file provides Rendering.View (~Copyable protocol with associatedtype Body)
// as a separate target, mirroring how swift-rendering-primitives publishes the
// primitive in the real ecosystem. The V12_ImplementsBridge target consumes it
// and defines the bridge type.

public enum Rendering {}

extension Rendering { public struct Context {} }

extension Rendering {
    public protocol View: ~Copyable {
        associatedtype Body: View & ~Copyable
        var body: Body { get }
        static func _render(_ view: borrowing Self, context: inout Context)
    }
}

extension Never: Rendering.View {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public static func _render(_ v: borrowing Self, context: inout Rendering.Context) {}
}
