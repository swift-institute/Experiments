// MARK: - V2: Witness (Closure-Based)
// Dynamic dispatch via stored closures — optimizer cannot see through them.
// Each method call is an indirect function pointer invocation.

public struct ContextWitness: ~Copyable {
    public var text: (String) -> Void
    public var pushBlock: (String?) -> Void
    public var popBlock: () -> Void
    public var pushElement: (String) -> Void
    public var popElement: () -> Void
    public var setAttribute: (String, String?) -> Void
    public var registerStyle: (String) -> String?

    public init(
        text: @escaping (String) -> Void,
        pushBlock: @escaping (String?) -> Void,
        popBlock: @escaping () -> Void,
        pushElement: @escaping (String) -> Void,
        popElement: @escaping () -> Void,
        setAttribute: @escaping (String, String?) -> Void,
        registerStyle: @escaping (String) -> String?
    ) {
        self.text = text
        self.pushBlock = pushBlock
        self.popBlock = popBlock
        self.pushElement = pushElement
        self.popElement = popElement
        self.setAttribute = setAttribute
        self.registerStyle = registerStyle
    }
}

extension ContextWitness {
    public static func html(
        buffer: UnsafeMutablePointer<ContiguousArray<UInt8>>
    ) -> Self {
        .init(
            text: { content in
                buffer.pointee.append(contentsOf: content.utf8)
            },
            pushBlock: { role in
                if let role {
                    buffer.pointee.append(contentsOf: "<div class=\"".utf8)
                    buffer.pointee.append(contentsOf: role.utf8)
                    buffer.pointee.append(contentsOf: "\">".utf8)
                } else {
                    buffer.pointee.append(contentsOf: "<div>".utf8)
                }
            },
            popBlock: {
                buffer.pointee.append(contentsOf: "</div>".utf8)
            },
            pushElement: { tagName in
                buffer.pointee.append(contentsOf: "<".utf8)
                buffer.pointee.append(contentsOf: tagName.utf8)
                buffer.pointee.append(contentsOf: ">".utf8)
            },
            popElement: {
                buffer.pointee.append(contentsOf: "</p>".utf8)
            },
            setAttribute: { name, value in
                if let value {
                    buffer.pointee.append(contentsOf: " ".utf8)
                    buffer.pointee.append(contentsOf: name.utf8)
                    buffer.pointee.append(contentsOf: "=\"".utf8)
                    buffer.pointee.append(contentsOf: value.utf8)
                    buffer.pointee.append(contentsOf: "\"".utf8)
                }
            },
            registerStyle: { _ in
                "s\(buffer.pointee.count)"
            }
        )
    }
}

@inline(never)
public func renderViaWitness(elements: Int, witness: inout ContextWitness) {
    for i in 0..<elements {
        witness.pushBlock("paragraph")
        witness.pushElement("p")
        _ = witness.registerStyle("line-height: 1.5")
        witness.text("Element \(i)")
        witness.popElement()
        witness.popBlock()
    }
}
