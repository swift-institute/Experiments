// MARK: - Rendering.Context witness struct
// Minimal version with the operations needed to validate migration blockers.

public import Property_Primitives

extension Rendering {
    public struct Context: ~Copyable {
        public var text: (String) -> Void
        public var lineBreak: () -> Void
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

        public init(
            text: @escaping (String) -> Void,
            lineBreak: @escaping () -> Void,
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
            popElement: @escaping (_ isBlock: Bool) -> Void
        ) {
            self.text = text
            self.lineBreak = lineBreak
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
        }
    }
}

// MARK: - Property.View push/pop accessors (V2: concrete type constraint)

extension Rendering.Context {
    public var push: Property<Rendering.Push, Rendering.Context>.View {
        mutating _read {
            yield unsafe Property<Rendering.Push, Rendering.Context>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Rendering.Push, Rendering.Context>.View(&self)
            yield &view
        }
    }

    public var pop: Property<Rendering.Pop, Rendering.Context>.View {
        mutating _read {
            yield unsafe Property<Rendering.Pop, Rendering.Context>.View(&self)
        }
        mutating _modify {
            var view = unsafe Property<Rendering.Pop, Rendering.Context>.View(&self)
            yield &view
        }
    }
}

extension Property.View where Tag == Rendering.Push, Base == Rendering.Context {
    @inlinable
    public func block(role: Rendering.Semantic.Block?, style: Rendering.Style) {
        unsafe base.pointee.pushBlock(role, style)
    }

    @inlinable
    public func inline(role: Rendering.Semantic.Inline?, style: Rendering.Style) {
        unsafe base.pointee.pushInline(role, style)
    }

    @inlinable
    public func list(kind: Rendering.Semantic.List, start: Int?) {
        unsafe base.pointee.pushList(kind, start)
    }

    @inlinable
    public func item() {
        unsafe base.pointee.pushItem()
    }

    @inlinable
    public func link(_ destination: String) {
        unsafe base.pointee.pushLink(destination)
    }

    @inlinable
    public func element(tagName: String, block isBlock: Bool) {
        unsafe base.pointee.pushElement(tagName, isBlock)
    }
}

extension Property.View where Tag == Rendering.Pop, Base == Rendering.Context {
    @inlinable
    public func block() {
        unsafe base.pointee.popBlock()
    }

    @inlinable
    public func inline() {
        unsafe base.pointee.popInline()
    }

    @inlinable
    public func list() {
        unsafe base.pointee.popList()
    }

    @inlinable
    public func item() {
        unsafe base.pointee.popItem()
    }

    @inlinable
    public func link() {
        unsafe base.pointee.popLink()
    }

    @inlinable
    public func element(block isBlock: Bool) {
        unsafe base.pointee.popElement(isBlock)
    }
}
