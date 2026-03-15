// MARK: - Minimal HTML context for test assertions

public final class HTMLState {
    public var bytes: [UInt8] = []
    var tagStack: [String] = []

    public init() {}

    public var string: String {
        String(validating: bytes, as: UTF8.self) ?? ""
    }
}

extension Rendering.Context {
    public static func html(state: HTMLState) -> Self {
        .init(
            text: { state.bytes.append(contentsOf: $0.utf8) },
            lineBreak: { state.bytes.append(contentsOf: "<br>".utf8) },
            pushBlock: { role, _ in
                let tag: String
                switch role {
                case .heading(let level): tag = "h\(level)"
                case .paragraph: tag = "p"
                case nil: tag = "div"
                }
                state.bytes.append(contentsOf: "<\(tag)>".utf8)
                state.tagStack.append(tag)
            },
            popBlock: {
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushInline: { role, _ in
                let tag: String
                switch role {
                case .emphasis: tag = "em"
                case .strong: tag = "strong"
                case nil: tag = "span"
                }
                state.bytes.append(contentsOf: "<\(tag)>".utf8)
                state.tagStack.append(tag)
            },
            popInline: {
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushList: { kind, _ in
                let tag = kind == .ordered ? "ol" : "ul"
                state.bytes.append(contentsOf: "<\(tag)>".utf8)
                state.tagStack.append(tag)
            },
            popList: {
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushItem: {
                state.bytes.append(contentsOf: "<li>".utf8)
                state.tagStack.append("li")
            },
            popItem: {
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushLink: { dest in
                state.bytes.append(contentsOf: "<a href=\"\(dest)\">".utf8)
                state.tagStack.append("a")
            },
            popLink: {
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            },
            pushElement: { tagName, _ in
                state.bytes.append(contentsOf: "<\(tagName)>".utf8)
                state.tagStack.append(tagName)
            },
            popElement: { _ in
                if let tag = state.tagStack.popLast() {
                    state.bytes.append(contentsOf: "</\(tag)>".utf8)
                }
            }
        )
    }
}
