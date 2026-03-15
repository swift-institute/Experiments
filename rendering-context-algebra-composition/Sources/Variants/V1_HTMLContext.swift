// MARK: - V1: HTML Context (Base Σ-Algebra)
// Purpose: Minimal HTML rendering context. Produces HTML bytes.
// Tests: Can a concrete context be expressed as a Rendering.Context witness?
//
// Two sub-variants:
//   V1a: UnsafeMutablePointer capture
//   V1b: Ref<T> class box capture (pointer-free)

public struct HTMLContext {
    public var bytes: [UInt8] = []
    public var styles: [String: String] = [:]
    var tagStack: [String] = []
    var styleCounter: Int = 0

    public init() {}
}

// MARK: - V1a: Pointer-based factory

extension Rendering.Context {
    public static func html(pointer: UnsafeMutablePointer<HTMLContext>) -> Self {
        .init(
            text: { content in
                pointer.pointee.bytes.append(contentsOf: content.utf8)
            },
            lineBreak: {
                pointer.pointee.bytes.append(contentsOf: "<br>".utf8)
            },
            thematicBreak: {
                pointer.pointee.bytes.append(contentsOf: "<hr>".utf8)
            },
            image: { source, alt in
                pointer.pointee.bytes.append(contentsOf: "<img src=\"\(source)\" alt=\"\(alt)\">".utf8)
            },
            pageBreak: {},
            setAttribute: { name, value in
                // simplified: append as data attribute
                if let value {
                    pointer.pointee.bytes.append(contentsOf: " \(name)=\"\(value)\"".utf8)
                }
            },
            addClass: { name in
                pointer.pointee.bytes.append(contentsOf: " class=\"\(name)\"".utf8)
            },
            writeRaw: { bytes in
                pointer.pointee.bytes.append(contentsOf: bytes)
            },
            registerStyle: { declaration in
                let name = "c\(pointer.pointee.styleCounter)"
                pointer.pointee.styleCounter += 1
                pointer.pointee.styles[name] = declaration
                return name
            },
            pushBlock: { role, style in
                let tag: String
                switch role {
                case .heading(let level): tag = "h\(level)"
                case .paragraph: tag = "p"
                case .blockquote: tag = "blockquote"
                case .pre: tag = "pre"
                case nil: tag = "div"
                }
                pointer.pointee.bytes.append(contentsOf: "<\(tag)>".utf8)
                pointer.pointee.tagStack.append(tag)
            },
            popBlock: {
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushInline: { role, style in
                let tag: String
                switch role {
                case .emphasis: tag = "em"
                case .strong: tag = "strong"
                case .code: tag = "code"
                case nil: tag = "span"
                }
                pointer.pointee.bytes.append(contentsOf: "<\(tag)>".utf8)
                pointer.pointee.tagStack.append(tag)
            },
            popInline: {
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushList: { kind, start in
                let tag = kind == .ordered ? "ol" : "ul"
                pointer.pointee.bytes.append(contentsOf: "<\(tag)>".utf8)
                pointer.pointee.tagStack.append(tag)
            },
            popList: {
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushItem: {
                pointer.pointee.bytes.append(contentsOf: "<li>".utf8)
                pointer.pointee.tagStack.append("li")
            },
            popItem: {
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushLink: { destination in
                pointer.pointee.bytes.append(contentsOf: "<a href=\"\(destination)\">".utf8)
                pointer.pointee.tagStack.append("a")
            },
            popLink: {
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushElement: { tagName, isBlock in
                pointer.pointee.bytes.append(contentsOf: "<\(tagName)>".utf8)
                pointer.pointee.tagStack.append(tagName)
            },
            popElement: { _ in
                if let tag = pointer.pointee.tagStack.popLast() {
                    pointer.pointee.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushStyle: {},
            popStyle: {}
        )
    }
}

// MARK: - V1b: Ref-based factory (pointer-free)

extension Rendering.Context {
    public static func html(ref: Ref<HTMLContext>) -> Self {
        .init(
            text: { ref.value.bytes.append(contentsOf: $0.utf8) },
            lineBreak: { ref.value.bytes.append(contentsOf: "<br>".utf8) },
            thematicBreak: { ref.value.bytes.append(contentsOf: "<hr>".utf8) },
            image: { source, alt in
                ref.value.bytes.append(contentsOf: "<img src=\"\(source)\" alt=\"\(alt)\">".utf8)
            },
            pageBreak: {},
            setAttribute: { name, value in
                if let value {
                    ref.value.bytes.append(contentsOf: " \(name)=\"\(value)\"".utf8)
                }
            },
            addClass: { name in
                ref.value.bytes.append(contentsOf: " class=\"\(name)\"".utf8)
            },
            writeRaw: { ref.value.bytes.append(contentsOf: $0) },
            registerStyle: { declaration in
                let name = "c\(ref.value.styleCounter)"
                ref.value.styleCounter += 1
                ref.value.styles[name] = declaration
                return name
            },
            pushBlock: { role, style in
                let tag: String
                switch role {
                case .heading(let level): tag = "h\(level)"
                case .paragraph: tag = "p"
                case .blockquote: tag = "blockquote"
                case .pre: tag = "pre"
                case nil: tag = "div"
                }
                ref.value.bytes.append(contentsOf: "<\(tag)>".utf8)
                ref.value.tagStack.append(tag)
            },
            popBlock: {
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushInline: { role, style in
                let tag: String
                switch role {
                case .emphasis: tag = "em"
                case .strong: tag = "strong"
                case .code: tag = "code"
                case nil: tag = "span"
                }
                ref.value.bytes.append(contentsOf: "<\(tag)>".utf8)
                ref.value.tagStack.append(tag)
            },
            popInline: {
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushList: { kind, start in
                let tag = kind == .ordered ? "ol" : "ul"
                ref.value.bytes.append(contentsOf: "<\(tag)>".utf8)
                ref.value.tagStack.append(tag)
            },
            popList: {
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushItem: {
                ref.value.bytes.append(contentsOf: "<li>".utf8)
                ref.value.tagStack.append("li")
            },
            popItem: {
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushLink: { destination in
                ref.value.bytes.append(contentsOf: "<a href=\"\(destination)\">".utf8)
                ref.value.tagStack.append("a")
            },
            popLink: {
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushElement: { tagName, isBlock in
                ref.value.bytes.append(contentsOf: "<\(tagName)>".utf8)
                ref.value.tagStack.append(tagName)
            },
            popElement: { _ in
                if let tag = ref.value.tagStack.popLast() {
                    ref.value.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushStyle: {},
            popStyle: {}
        )
    }
}
