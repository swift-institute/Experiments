// MARK: - V1: Protocol Baseline
// Generic specialization — compiler resolves dispatch at compile time.
// In release, all context method calls are devirtualized and inlined.

@inline(never)
public func renderViaProtocol<C: ContextProtocol>(elements: Int, context: inout C) {
    for i in 0..<elements {
        context.pushBlock(role: "paragraph")
        context.pushElement(tagName: "p")
        _ = context.registerStyle(declaration: "line-height: 1.5")
        context.text("Element \(i)")
        context.popElement()
        context.popBlock()
    }
}
