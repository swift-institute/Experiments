// MARK: - V3: Observing Transformer (Middleware)
// Purpose: Validate that transformers can add observation/logging
//          without modifying the base context's behavior.
//
// Hypothesis: An observation transformer wraps each closure with
//             before/after callbacks, matching the @Witness Observe pattern.

extension Rendering.Context {
    /// Middleware endomorphism: logs every operation as a Rendering.Action.
    /// The base context is consumed; operations are forwarded with logging.
    public consuming func observing(
        log: Ref<[Rendering.Action]>
    ) -> Rendering.Context {
        let baseText = self.text
        let baseLineBreak = self.lineBreak
        let baseThematicBreak = self.thematicBreak
        let baseImage = self.image
        let basePageBreak = self.pageBreak
        let baseSetAttribute = self.setAttribute
        let baseAddClass = self.addClass
        let baseWriteRaw = self.writeRaw
        let baseRegisterStyle = self.registerStyle
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        let basePushInline = self.pushInline
        let basePopInline = self.popInline
        let basePushList = self.pushList
        let basePopList = self.popList
        let basePushItem = self.pushItem
        let basePopItem = self.popItem
        let basePushLink = self.pushLink
        let basePopLink = self.popLink
        let basePushElement = self.pushElement
        let basePopElement = self.popElement
        let basePushStyle = self.pushStyle
        let basePopStyle = self.popStyle

        return Rendering.Context(
            text: { content in
                log.value.append(.text(content))
                baseText(content)
            },
            lineBreak: {
                log.value.append(.lineBreak)
                baseLineBreak()
            },
            thematicBreak: {
                log.value.append(.thematicBreak)
                baseThematicBreak()
            },
            image: { source, alt in
                log.value.append(.image(source: source, alt: alt))
                baseImage(source, alt)
            },
            pageBreak: {
                log.value.append(.pageBreak)
                basePageBreak()
            },
            setAttribute: { name, value in
                log.value.append(.attribute(set: name, value: value))
                baseSetAttribute(name, value)
            },
            addClass: { name in
                log.value.append(.class(add: name))
                baseAddClass(name)
            },
            writeRaw: { bytes in
                log.value.append(.raw(bytes))
                baseWriteRaw(bytes)
            },
            registerStyle: { declaration in
                log.value.append(.style(register: declaration))
                return baseRegisterStyle(declaration)
            },
            pushBlock: { role, style in
                log.value.append(.push(.block(role: role, style: style)))
                basePushBlock(role, style)
            },
            popBlock: {
                log.value.append(.pop(.block))
                basePopBlock()
            },
            pushInline: { role, style in
                log.value.append(.push(.inline(role: role, style: style)))
                basePushInline(role, style)
            },
            popInline: {
                log.value.append(.pop(.inline))
                basePopInline()
            },
            pushList: { kind, start in
                log.value.append(.push(.list(kind: kind, start: start)))
                basePushList(kind, start)
            },
            popList: {
                log.value.append(.pop(.list))
                basePopList()
            },
            pushItem: {
                log.value.append(.push(.item))
                basePushItem()
            },
            popItem: {
                log.value.append(.pop(.item))
                basePopItem()
            },
            pushLink: { destination in
                log.value.append(.push(.link(destination: destination)))
                basePushLink(destination)
            },
            popLink: {
                log.value.append(.pop(.link))
                basePopLink()
            },
            pushElement: { tagName, isBlock in
                log.value.append(.push(.element(tagName: tagName, isBlock: isBlock)))
                basePushElement(tagName, isBlock)
            },
            popElement: { isBlock in
                log.value.append(.pop(.element(isBlock: isBlock)))
                basePopElement(isBlock)
            },
            pushStyle: {
                log.value.append(.push(.style))
                basePushStyle()
            },
            popStyle: {
                log.value.append(.pop(.style))
                basePopStyle()
            }
        )
    }
}
