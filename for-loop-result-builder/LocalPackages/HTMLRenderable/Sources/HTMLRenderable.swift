// Layer 3: HTML domain — refines Rendering.View

public import RenderingPrimitives

public enum HTML {}

// MARK: - HTML.View protocol

extension HTML {
    public protocol View: Rendering.View where RenderBody: HTML.View {
        @HTML.Builder var body: RenderBody { get }
    }
}

extension HTML {
    public typealias Builder = Rendering.Builder
}

// MARK: - Domain conformances (conditional, cross-module)

extension Rendering._Tuple: HTML.View where repeat each Content: HTML.View {}
extension Rendering.Conditional: HTML.View where First: HTML.View, Second: HTML.View {}
extension Array: HTML.View where Element: HTML.View {}
extension Optional: HTML.View where Wrapped: HTML.View {}
extension Rendering.ForEach: HTML.View where Content: HTML.View {}
extension Never: HTML.View {}

// MARK: - Concrete leaf types

public struct Text: HTML.View {
    public let value: String
    public init(value: String) { self.value = value }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit(view.value)
    }
}

public struct Div<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) {
        self.content = content()
    }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<div>")
        Content._render(view.content, context: &context)
        context.emit("</div>")
    }
}

public struct Span<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) {
        self.content = content()
    }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<span>")
        Content._render(view.content, context: &context)
        context.emit("</span>")
    }
}

// MARK: - Table types (match real generic depth)

public struct Table<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<table>")
        Content._render(view.content, context: &context)
        context.emit("</table>")
    }
}

public struct TableBody<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<tbody>")
        Content._render(view.content, context: &context)
        context.emit("</tbody>")
    }
}

public struct TableRow<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<tr>")
        Content._render(view.content, context: &context)
        context.emit("</tr>")
    }
}

public struct TableDataCell<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<td>")
        Content._render(view.content, context: &context)
        context.emit("</td>")
    }
}

public struct Section<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<section>")
        Content._render(view.content, context: &context)
        context.emit("</section>")
    }
}

public struct H3<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<h3>")
        Content._render(view.content, context: &context)
        context.emit("</h3>")
    }
}

public struct Paragraph<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<p>")
        Content._render(view.content, context: &context)
        context.emit("</p>")
    }
}

public struct Strong<Content: HTML.View>: HTML.View {
    public let content: Content
    public init(@HTML.Builder content: () -> Content) { self.content = content() }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<strong>")
        Content._render(view.content, context: &context)
        context.emit("</strong>")
    }
}

// CSS modifier wrapper — adds a layer of generic nesting per modifier
public struct CSSModified<Content: HTML.View>: HTML.View {
    public let content: Content
    public let style: String
    public init(_ content: Content, style: String) {
        self.content = content
        self.style = style
    }
    public typealias RenderBody = Never
    public var body: Never { fatalError() }
    public static func _render(_ view: Self, context: inout Rendering.Context) {
        context.emit("<div style=\"\(view.style)\">")
        Content._render(view.content, context: &context)
        context.emit("</div>")
    }
}

extension HTML.View {
    public func css(_ style: String) -> CSSModified<Self> {
        CSSModified(self, style: style)
    }
}

// MARK: - Render helper

public func render<V: HTML.View>(_ view: V) -> String {
    var ctx = Rendering.Context()
    V._render(view, context: &ctx)
    return ctx.output
}
