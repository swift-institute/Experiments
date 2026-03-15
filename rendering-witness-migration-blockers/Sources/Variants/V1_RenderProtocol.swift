// MARK: - V1: _render as non-generic protocol requirement
// Purpose: Validate that Rendering.View can use a concrete Rendering.Context
//          (not generic C) in its _render protocol requirement, and that the
//          default body-based implementation dispatches correctly through
//          the view hierarchy.
//
// Hypothesis: static func _render(_ view: borrowing Self, context: inout Rendering.Context)
//             works as a protocol requirement. The default implementation
//             RenderBody._render(view.body, context: &context) compiles and
//             dispatches correctly for composite views, leaf views, and
//             existential (AnyView) views.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: {PENDING}
// Date: 2026-03-14

// MARK: - Rendering.View protocol with concrete context

extension Rendering {
    public protocol View: ~Copyable {
        associatedtype RenderBody: View & ~Copyable
        @Rendering.Builder var body: RenderBody { get }

        static func _render(_ view: borrowing Self, context: inout Rendering.Context)
    }

    @resultBuilder
    public enum Builder {
        public static func buildBlock<V>(_ v: V) -> V { v }

        public static func buildBlock<each Content>(
            _ content: repeat each Content
        ) -> Rendering._Tuple<repeat each Content> {
            Rendering._Tuple(repeat each content)
        }

        public static func buildOptional<V>(_ v: V?) -> V? { v }

        public static func buildArray<V>(_ components: [V]) -> [V] {
            components
        }
    }
}

// MARK: - Default _render (composite views delegate to body)

extension Rendering.View where RenderBody: Rendering.View {
    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        RenderBody._render(view.body, context: &context)
    }
}

// MARK: - Never conformance (leaf sentinel)

extension Never: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Never, context: inout Rendering.Context) {}
}

// MARK: - _Tuple (variadic flat composition)

extension Rendering {
    public struct _Tuple<each Content> {
        public let content: (repeat each Content)

        public init(_ content: repeat each Content) {
            self.content = (repeat each content)
        }
    }
}

extension Rendering._Tuple: Rendering.View where repeat each Content: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        func render<V: Rendering.View>(_ v: V, _ ctx: inout Rendering.Context) {
            V._render(v, context: &ctx)
        }
        repeat render(each view.content, &context)
    }
}

// MARK: - Optional conformance

extension Optional: Rendering.View where Wrapped: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        switch copy view {
        case .some(let wrapped):
            Wrapped._render(wrapped, context: &context)
        case .none:
            break
        }
    }
}

// MARK: - Array conformance

extension Array: Rendering.View where Element: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        for element in copy view {
            Element._render(element, context: &context)
        }
    }
}

// MARK: - Concrete leaf view (like HTML.Text)

public struct TextLeaf: Rendering.View {
    public let content: String
    public init(_ content: String) { self.content = content }

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        context.text(view.content)
    }
}

// MARK: - Concrete composite view (like a Paragraph wrapper)

public struct Paragraph<Content: Rendering.View>: Rendering.View {
    public let content: Content
    public init(@Rendering.Builder _ content: () -> Content) {
        self.content = content()
    }

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing Self, context: inout Rendering.Context) {
        context.push.block(role: .paragraph, style: .empty)
        Content._render(view.content, context: &context)
        context.pop.block()
    }
}

// MARK: - Body-based composite view (uses default _render)

public struct Article: Rendering.View {
    let title: String
    let body_text: String

    public init(title: String, body: String) {
        self.title = title
        self.body_text = body
    }

    public var body: some Rendering.View {
        Paragraph { TextLeaf(title) }
        Paragraph { TextLeaf(body_text) }
    }
}
