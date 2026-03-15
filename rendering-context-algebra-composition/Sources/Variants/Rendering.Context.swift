// MARK: - Rendering.Context (Witness Struct)
// A Σ-algebra for the rendering signature.
// Product of interpretation functions, one per operation symbol.

extension Rendering {
    public struct Context: ~Copyable {
        // --- Leaf operations ---
        public var text: (String) -> Void
        public var lineBreak: () -> Void
        public var thematicBreak: () -> Void
        public var image: (_ source: String, _ alt: String) -> Void
        public var pageBreak: () -> Void

        // --- Attribute operations ---
        public var setAttribute: (_ name: String, _ value: String?) -> Void
        public var addClass: (String) -> Void
        public var writeRaw: ([UInt8]) -> Void
        public var registerStyle: (String) -> String?

        // --- Push operations ---
        public var pushBlock: (_ role: Semantic.Block?, _ style: Style) -> Void
        public var popBlock: () -> Void
        public var pushInline: (_ role: Semantic.Inline?, _ style: Style) -> Void
        public var popInline: () -> Void
        public var pushList: (_ kind: Semantic.List, _ start: Int?) -> Void
        public var popList: () -> Void
        public var pushItem: () -> Void
        public var popItem: () -> Void
        public var pushLink: (_ destination: String) -> Void
        public var popLink: () -> Void
        public var pushElement: (_ tagName: String, _ isBlock: Bool) -> Void
        public var popElement: (_ isBlock: Bool) -> Void
        public var pushStyle: () -> Void
        public var popStyle: () -> Void

        public init(
            text: @escaping (String) -> Void,
            lineBreak: @escaping () -> Void,
            thematicBreak: @escaping () -> Void,
            image: @escaping (_ source: String, _ alt: String) -> Void,
            pageBreak: @escaping () -> Void,
            setAttribute: @escaping (_ name: String, _ value: String?) -> Void,
            addClass: @escaping (String) -> Void,
            writeRaw: @escaping ([UInt8]) -> Void,
            registerStyle: @escaping (String) -> String?,
            pushBlock: @escaping (_ role: Semantic.Block?, _ style: Style) -> Void,
            popBlock: @escaping () -> Void,
            pushInline: @escaping (_ role: Semantic.Inline?, _ style: Style) -> Void,
            popInline: @escaping () -> Void,
            pushList: @escaping (_ kind: Semantic.List, _ start: Int?) -> Void,
            popList: @escaping () -> Void,
            pushItem: @escaping () -> Void,
            popItem: @escaping () -> Void,
            pushLink: @escaping (_ destination: String) -> Void,
            popLink: @escaping () -> Void,
            pushElement: @escaping (_ tagName: String, _ isBlock: Bool) -> Void,
            popElement: @escaping (_ isBlock: Bool) -> Void,
            pushStyle: @escaping () -> Void,
            popStyle: @escaping () -> Void
        ) {
            self.text = text
            self.lineBreak = lineBreak
            self.thematicBreak = thematicBreak
            self.image = image
            self.pageBreak = pageBreak
            self.setAttribute = setAttribute
            self.addClass = addClass
            self.writeRaw = writeRaw
            self.registerStyle = registerStyle
            self.pushBlock = pushBlock
            self.popBlock = popBlock
            self.pushInline = pushInline
            self.popInline = popInline
            self.pushList = pushList
            self.popList = popList
            self.pushItem = pushItem
            self.popItem = popItem
            self.pushLink = pushLink
            self.popLink = popLink
            self.pushElement = pushElement
            self.popElement = popElement
            self.pushStyle = pushStyle
            self.popStyle = popStyle
        }
    }
}

// MARK: - Action Interpreter

extension Rendering.Context {
    public mutating func interpret(_ action: Rendering.Action) {
        switch action {
        case .text(let content): text(content)
        case .lineBreak: lineBreak()
        case .thematicBreak: thematicBreak()
        case .image(let source, let alt): image(source, alt)
        case .pageBreak: pageBreak()
        case .attribute(let name, let value): setAttribute(name, value)
        case .class(let name): addClass(name)
        case .raw(let bytes): writeRaw(bytes)
        case .style(let decl): _ = registerStyle(decl)
        case .push(let push):
            switch push {
            case .block(let role, let style): pushBlock(role, style)
            case .inline(let role, let style): pushInline(role, style)
            case .list(let kind, let start): pushList(kind, start)
            case .item: pushItem()
            case .link(let dest): pushLink(dest)
            case .attributes: break // simplified for experiment
            case .element(let tag, let isBlock): pushElement(tag, isBlock)
            case .style: pushStyle()
            }
        case .pop(let pop):
            switch pop {
            case .block: popBlock()
            case .inline: popInline()
            case .list: popList()
            case .item: popItem()
            case .link: popLink()
            case .attributes: break
            case .element(let isBlock): popElement(isBlock)
            case .style: popStyle()
            }
        }
    }

    public mutating func interpret(_ actions: [Rendering.Action]) {
        for action in actions { interpret(action) }
    }
}
