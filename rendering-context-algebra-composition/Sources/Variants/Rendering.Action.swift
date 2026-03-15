// MARK: - Rendering.Action
// The free Σ-algebra over the rendering signature.
// Each case corresponds to one operation in the Rendering.Context witness.
// Nested Push/Pop enums mirror the push/pop accessor structure per [API-NAME-001].

public enum Rendering {
    public enum Semantic {
        public enum Block: Sendable { case heading(level: Int), paragraph, blockquote, pre }
        public enum Inline: Sendable { case emphasis, strong, code }
        public enum List: Sendable { case ordered, unordered }
    }

    public struct Style: Sendable {
        public static let empty = Style()
    }
}

extension Rendering {
    public enum Action: Sendable {
        // Grouped operations (mirror push/pop accessors)
        case push(Push)
        case pop(Pop)

        // Leaf operations
        case text(String)
        case lineBreak
        case thematicBreak
        case image(source: String, alt: String)
        case pageBreak

        // Attribute operations
        case attribute(set: String, value: String?)
        case `class`(add: String)
        case raw([UInt8])
        case style(register: String)
    }
}

extension Rendering.Action {
    public enum Push: Sendable {
        case block(role: Rendering.Semantic.Block?, style: Rendering.Style)
        case inline(role: Rendering.Semantic.Inline?, style: Rendering.Style)
        case list(kind: Rendering.Semantic.List, start: Int?)
        case item
        case link(destination: String)
        case attributes
        case element(tagName: String, isBlock: Bool)
        case style
    }

    public enum Pop: Sendable {
        case block
        case inline
        case list
        case item
        case link
        case attributes
        case element(isBlock: Bool)
        case style
    }
}
