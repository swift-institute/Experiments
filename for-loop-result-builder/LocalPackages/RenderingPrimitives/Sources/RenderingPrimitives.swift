// Layer 1: Rendering Primitives — unconstrained, domain-agnostic

public enum Rendering {}

// MARK: - Context

extension Rendering {
    public struct Context: ~Copyable {
        public var output: String = ""
        public init() {}
        public mutating func emit(_ s: String) { output += s }
    }
}

// MARK: - View protocol

extension Rendering {
    public protocol View {
        associatedtype RenderBody: Rendering.View
        @Rendering.Builder var body: RenderBody { get }
        static func _render(_ view: Self, context: inout Rendering.Context)
    }
}

extension Rendering.View {
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        RenderBody._render(view.body, context: &context)
    }
}

extension Never: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {}
}

// MARK: - Builder (unconstrained)

extension Rendering {
    @resultBuilder
    public enum Builder {
        public static func buildBlock<V>(_ v: V) -> V { v }

        public static func buildBlock<each Content>(
            _ content: repeat each Content
        ) -> Rendering._Tuple<repeat each Content> {
            Rendering._Tuple(repeat each content)
        }

        public static func buildOptional<V>(_ v: V?) -> V? { v }

        public static func buildEither<First, Second>(
            first: First
        ) -> Rendering.Conditional<First, Second> {
            .first(first)
        }

        public static func buildEither<First, Second>(
            second: Second
        ) -> Rendering.Conditional<First, Second> {
            .second(second)
        }

        public static func buildArray<V>(_ components: [V]) -> [V] {
            components
        }
    }
}

// MARK: - _Tuple

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
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        func render<V: Rendering.View>(_ v: V, _ ctx: inout Rendering.Context) {
            V._render(v, context: &ctx)
        }
        repeat render(each view.content, &context)
    }
}

// MARK: - Conditional

extension Rendering {
    public enum Conditional<First, Second> {
        case first(First)
        case second(Second)
    }
}

extension Rendering.Conditional: Rendering.View
where First: Rendering.View, Second: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        switch view {
        case .first(let f): First._render(f, context: &context)
        case .second(let s): Second._render(s, context: &context)
        }
    }
}

// MARK: - Array + Rendering.View

extension Array: Rendering.View where Element: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        for element in view {
            Element._render(element, context: &context)
        }
    }
}

// MARK: - Optional + Rendering.View

extension Optional: Rendering.View where Wrapped: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        if let view {
            Wrapped._render(view, context: &context)
        }
    }
}

// MARK: - ForEach

extension Rendering {
    public struct ForEach<Content> {
        public let content: [Content]
        public init(content: [Content]) { self.content = content }
    }
}

extension Rendering.ForEach: Rendering.View where Content: Rendering.View {
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        for element in view.content {
            Content._render(element, context: &context)
        }
    }
}
