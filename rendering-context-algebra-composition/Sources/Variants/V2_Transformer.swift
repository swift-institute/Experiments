// MARK: - V2: Context Transformer (Algebra Endomorphism)
// Purpose: Validate that Rendering.Context can be consumed and rewrapped
//          with additional stateful logic — the algebra composition pattern.
//
// Hypothesis: A `consuming` method on ~Copyable Rendering.Context can wrap
//             each closure with transformer logic, producing a new context.
//
// The transformer is an endofunction on Alg(Σ):
//   transform: (Rendering.Context, inout S) → Rendering.Context
// where S is the transformer's state.

// MARK: - HTML Transformer State (simulates PDF.HTML.State)

public struct HTMLTransformState {
    public struct Heading {
        public var level: Int
        public var text: String = ""
    }

    public var activeHeading: Heading? = nil
    public var headings: [(level: Int, text: String)] = []
    public var elementDepth: Int = 0

    public init() {}
}

// MARK: - V2a: Transformer via consuming method + Ref (pointer-free)

extension Rendering.Context {
    /// Algebra endomorphism: decorates a base context with HTML semantic understanding.
    /// The base context is consumed; its closures are moved into the new context's closures.
    ///
    /// Categorically: an endofunction on Alg(Σ) parameterized by state S.
    public consuming func html(state: Ref<HTMLTransformState>) -> Rendering.Context {
        // Capture the base context's closures
        let baseText = self.text
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        let basePushElement = self.pushElement
        let basePopElement = self.popElement

        // Forward unchanged operations
        let baseLineBreak = self.lineBreak
        let baseThematicBreak = self.thematicBreak
        let baseImage = self.image
        let basePageBreak = self.pageBreak
        let baseSetAttribute = self.setAttribute
        let baseAddClass = self.addClass
        let baseWriteRaw = self.writeRaw
        let baseRegisterStyle = self.registerStyle
        let basePushInline = self.pushInline
        let basePopInline = self.popInline
        let basePushList = self.pushList
        let basePopList = self.popList
        let basePushItem = self.pushItem
        let basePopItem = self.popItem
        let basePushLink = self.pushLink
        let basePopLink = self.popLink
        let basePushStyle = self.pushStyle
        let basePopStyle = self.popStyle

        return Rendering.Context(
            text: { content in
                // Stateful enrichment: accumulate heading text
                if state.value.activeHeading != nil {
                    state.value.activeHeading!.text += content
                }
                baseText(content)
            },
            lineBreak: baseLineBreak,
            thematicBreak: baseThematicBreak,
            image: baseImage,
            pageBreak: basePageBreak,
            setAttribute: baseSetAttribute,
            addClass: baseAddClass,
            writeRaw: baseWriteRaw,
            registerStyle: baseRegisterStyle,
            pushBlock: { role, style in
                // Stateful enrichment: start heading tracking
                if case .heading(let level) = role {
                    state.value.activeHeading = .init(level: level)
                }
                basePushBlock(role, style)
            },
            popBlock: {
                // Stateful enrichment: finalize heading
                if let heading = state.value.activeHeading {
                    state.value.headings.append((level: heading.level, text: heading.text))
                    state.value.activeHeading = nil
                }
                basePopBlock()
            },
            pushInline: basePushInline,
            popInline: basePopInline,
            pushList: basePushList,
            popList: basePopList,
            pushItem: basePushItem,
            popItem: basePopItem,
            pushLink: basePushLink,
            popLink: basePopLink,
            pushElement: { tagName, isBlock in
                state.value.elementDepth += 1
                basePushElement(tagName, isBlock)
            },
            popElement: { isBlock in
                state.value.elementDepth -= 1
                basePopElement(isBlock)
            },
            pushStyle: basePushStyle,
            popStyle: basePopStyle
        )
    }
}

// MARK: - V2b: Transformer via consuming method + UnsafeMutablePointer

extension Rendering.Context {
    public consuming func html(state: UnsafeMutablePointer<HTMLTransformState>) -> Rendering.Context {
        let baseText = self.text
        let basePushBlock = self.pushBlock
        let basePopBlock = self.popBlock
        let basePushElement = self.pushElement
        let basePopElement = self.popElement

        let baseLineBreak = self.lineBreak
        let baseThematicBreak = self.thematicBreak
        let baseImage = self.image
        let basePageBreak = self.pageBreak
        let baseSetAttribute = self.setAttribute
        let baseAddClass = self.addClass
        let baseWriteRaw = self.writeRaw
        let baseRegisterStyle = self.registerStyle
        let basePushInline = self.pushInline
        let basePopInline = self.popInline
        let basePushList = self.pushList
        let basePopList = self.popList
        let basePushItem = self.pushItem
        let basePopItem = self.popItem
        let basePushLink = self.pushLink
        let basePopLink = self.popLink
        let basePushStyle = self.pushStyle
        let basePopStyle = self.popStyle

        return Rendering.Context(
            text: { content in
                if state.pointee.activeHeading != nil {
                    state.pointee.activeHeading!.text += content
                }
                baseText(content)
            },
            lineBreak: baseLineBreak,
            thematicBreak: baseThematicBreak,
            image: baseImage,
            pageBreak: basePageBreak,
            setAttribute: baseSetAttribute,
            addClass: baseAddClass,
            writeRaw: baseWriteRaw,
            registerStyle: baseRegisterStyle,
            pushBlock: { role, style in
                if case .heading(let level) = role {
                    state.pointee.activeHeading = .init(level: level)
                }
                basePushBlock(role, style)
            },
            popBlock: {
                if let heading = state.pointee.activeHeading {
                    state.pointee.headings.append((level: heading.level, text: heading.text))
                    state.pointee.activeHeading = nil
                }
                basePopBlock()
            },
            pushInline: basePushInline,
            popInline: basePopInline,
            pushList: basePushList,
            popList: basePopList,
            pushItem: basePushItem,
            popItem: basePopItem,
            pushLink: basePushLink,
            popLink: basePopLink,
            pushElement: { tagName, isBlock in
                state.pointee.elementDepth += 1
                basePushElement(tagName, isBlock)
            },
            popElement: { isBlock in
                state.pointee.elementDepth -= 1
                basePopElement(isBlock)
            },
            pushStyle: basePushStyle,
            popStyle: basePopStyle
        )
    }
}
