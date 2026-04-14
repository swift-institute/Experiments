// Rendering: a peer module declaring its own `View` protocol with an
// associated type named `Body`. Exists so V8 can attempt to
// disambiguate with the `Rendering::View` / `SwiftUI::View` module
// selector syntax introduced by SE-0491.
//
// `View` is declared at module top level so SE-0491's `Rendering::View`
// resolves correctly. (Module selectors look up at module scope, not
// inside nested namespaces.) This is purely a test-fixture concession;
// production code should follow the Nest.Name convention with
// `extension Rendering { public protocol View {} }`.

public protocol View {
    associatedtype Body: View
    var body: Body { get }
}

public struct RenderingNever: View {
    public typealias Body = RenderingNever
    public var body: RenderingNever { fatalError() }
    public init() {}
}
