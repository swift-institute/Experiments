// MARK: - V4: Tee Transform
// Purpose: Validate that two ~Copyable witness contexts can be consumed and
//          their closures combined into a single context that duplicates
//          operations to both targets.
//
// Hypothesis: Rendering.Context.tee(consuming a, consuming b) compiles.
//             The resulting context calls both a's and b's closures for each operation.
//             One render pass produces output in both targets.
//
// This is structurally impossible with the protocol (monomorphic C in _render<C>).
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: {PENDING}
// Date: 2026-03-14

extension Rendering.Context {
    /// Tee transform: duplicates every operation to two consumed base contexts.
    /// Both base contexts are consumed — their closures are moved into the new context.
    /// ~Copyable enforces that neither base survives independently.
    public static func tee(
        _ a: consuming Rendering.Context,
        _ b: consuming Rendering.Context
    ) -> Rendering.Context {
        let aText = a.text;                 let bText = b.text
        let aLineBreak = a.lineBreak;       let bLineBreak = b.lineBreak
        let aPushBlock = a.pushBlock;       let bPushBlock = b.pushBlock
        let aPopBlock = a.popBlock;         let bPopBlock = b.popBlock
        let aPushInline = a.pushInline;     let bPushInline = b.pushInline
        let aPopInline = a.popInline;       let bPopInline = b.popInline
        let aPushList = a.pushList;         let bPushList = b.pushList
        let aPopList = a.popList;           let bPopList = b.popList
        let aPushItem = a.pushItem;         let bPushItem = b.pushItem
        let aPopItem = a.popItem;           let bPopItem = b.popItem
        let aPushLink = a.pushLink;         let bPushLink = b.pushLink
        let aPopLink = a.popLink;           let bPopLink = b.popLink
        let aPushElement = a.pushElement;   let bPushElement = b.pushElement
        let aPopElement = a.popElement;     let bPopElement = b.popElement

        return .init(
            text: { content in aText(content); bText(content) },
            lineBreak: { aLineBreak(); bLineBreak() },
            pushBlock: { role, style in aPushBlock(role, style); bPushBlock(role, style) },
            popBlock: { aPopBlock(); bPopBlock() },
            pushInline: { role, style in aPushInline(role, style); bPushInline(role, style) },
            popInline: { aPopInline(); bPopInline() },
            pushList: { kind, start in aPushList(kind, start); bPushList(kind, start) },
            popList: { aPopList(); bPopList() },
            pushItem: { aPushItem(); bPushItem() },
            popItem: { aPopItem(); bPopItem() },
            pushLink: { dest in aPushLink(dest); bPushLink(dest) },
            popLink: { aPopLink(); bPopLink() },
            pushElement: { tag, isBlock in aPushElement(tag, isBlock); bPushElement(tag, isBlock) },
            popElement: { isBlock in aPopElement(isBlock); bPopElement(isBlock) }
        )
    }
}
