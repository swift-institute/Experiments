// MARK: - V4: Action Enum + Protocol Interpreter (Buffer Reuse)
// Actions accumulated per element, buffer reused via removeAll(keepingCapacity:).
// Matches the proposed markdown converter design: per-element action batches.

@inline(never)
public func renderViaActionsReused(elements: Int, context: inout HTMLContext) {
    var actions: [RenderAction] = []
    actions.reserveCapacity(16)
    for i in 0..<elements {
        actions.removeAll(keepingCapacity: true)
        actions.append(.pushBlock(role: "paragraph"))
        actions.append(.pushElement(tagName: "p"))
        actions.append(.registerStyle(declaration: "line-height: 1.5"))
        actions.append(.text("Element \(i)"))
        actions.append(.popElement)
        actions.append(.popBlock)
        interpretActions(actions, context: &context)
    }
}
