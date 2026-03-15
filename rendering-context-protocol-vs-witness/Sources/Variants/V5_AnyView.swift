// MARK: - V5: AnyView Existential (Current Path)
// Type-erased views dispatched via existential protocol.
// Overhead: existential box allocation + witness table dispatch.

public protocol AnyRenderable {
    func render(context: inout HTMLContext)
}

public struct ParagraphView: AnyRenderable {
    public let text: String
    public let index: Int

    public init(text: String, index: Int) {
        self.text = text
        self.index = index
    }

    public func render(context: inout HTMLContext) {
        context.pushBlock(role: "paragraph")
        context.pushElement(tagName: "p")
        _ = context.registerStyle(declaration: "line-height: 1.5")
        context.text(text)
        context.popElement()
        context.popBlock()
    }
}

@inline(never)
public func renderViaAnyView(elements: Int, context: inout HTMLContext) {
    var views: [any AnyRenderable] = []
    for i in 0..<elements {
        views.append(ParagraphView(text: "Element \(i)", index: i))
    }
    for view in views {
        view.render(context: &context)
    }
}
