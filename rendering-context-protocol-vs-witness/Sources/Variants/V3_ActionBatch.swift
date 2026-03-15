// MARK: - V3: Action Enum + Protocol Interpreter (Batch)
// Actions accumulated for entire document, then interpreted in one pass.
// Overhead: enum allocation + switch dispatch + protocol dispatch.

public enum RenderAction: Sendable {
    case text(String)
    case pushBlock(role: String?)
    case popBlock
    case pushElement(tagName: String)
    case popElement
    case setAttribute(name: String, value: String?)
    case registerStyle(declaration: String)
}

@inline(never)
public func interpretActions<C: ContextProtocol>(
    _ actions: [RenderAction], context: inout C
) {
    for action in actions {
        switch action {
        case .text(let content):
            context.text(content)
        case .pushBlock(let role):
            context.pushBlock(role: role)
        case .popBlock:
            context.popBlock()
        case .pushElement(let tag):
            context.pushElement(tagName: tag)
        case .popElement:
            context.popElement()
        case .setAttribute(let name, let value):
            context.setAttribute(name: name, value: value)
        case .registerStyle(let decl):
            _ = context.registerStyle(declaration: decl)
        }
    }
}

@inline(never)
public func renderViaActionsBatch(elements: Int, context: inout HTMLContext) {
    var actions: [RenderAction] = []
    actions.reserveCapacity(elements * 6)
    for i in 0..<elements {
        actions.append(.pushBlock(role: "paragraph"))
        actions.append(.pushElement(tagName: "p"))
        actions.append(.registerStyle(declaration: "line-height: 1.5"))
        actions.append(.text("Element \(i)"))
        actions.append(.popElement)
        actions.append(.popBlock)
    }
    interpretActions(actions, context: &context)
}
