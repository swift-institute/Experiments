// MARK: - V3: AnyView existential opening without generic C
// Purpose: Validate that existential opening on the view type (V: Rendering.View)
//          works when the context is a concrete type (inout Rendering.Context),
//          not a generic C.
//
// Hypothesis: _openAndRender<V: Rendering.View>(_ base: V, context: inout Rendering.Context)
//             correctly opens the existential `any Rendering.View` and dispatches
//             to the concrete V._render. The C parameter on the context is not needed
//             for the existential opening to work — only V needs to be generic.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: {PENDING}
// Date: 2026-03-14

public struct AnyRenderingView: Rendering.View {
    public let base: any Rendering.View

    public init<T: Rendering.View>(_ base: T) {
        self.base = base
    }

    public init(erasing base: any Rendering.View) {
        if let anyView = base as? AnyRenderingView {
            self = anyView
        } else {
            self.base = base
        }
    }

    public typealias RenderBody = Never
    public var body: Never { fatalError() }

    public static func _render(_ view: borrowing AnyRenderingView, context: inout Rendering.Context) {
        _openAndRender(view.base, context: &context)
    }

    private static func _openAndRender<V: Rendering.View>(
        _ base: V, context: inout Rendering.Context
    ) {
        V._render(base, context: &context)
    }
}

// No builder extensions — AnyRenderingView is constructed explicitly, not via @Builder.
