// MARK: - Shared Infrastructure
// Protocol and concrete context used by V1, V3, V4, V5.
// V2 (witness) provides its own dispatch but produces identical byte output.

public protocol ContextProtocol {
    mutating func text(_ content: String)
    mutating func pushBlock(role: String?)
    mutating func popBlock()
    mutating func pushElement(tagName: String)
    mutating func popElement()
    mutating func setAttribute(name: String, value: String?)
    mutating func registerStyle(declaration: String) -> String?
}

public struct HTMLContext: ContextProtocol, Sendable {
    public var bytes: ContiguousArray<UInt8> = []

    public init() {}

    @inline(__always)
    public mutating func text(_ content: String) {
        bytes.append(contentsOf: content.utf8)
    }

    @inline(__always)
    public mutating func pushBlock(role: String?) {
        if let role {
            bytes.append(contentsOf: "<div class=\"".utf8)
            bytes.append(contentsOf: role.utf8)
            bytes.append(contentsOf: "\">".utf8)
        } else {
            bytes.append(contentsOf: "<div>".utf8)
        }
    }

    @inline(__always)
    public mutating func popBlock() {
        bytes.append(contentsOf: "</div>".utf8)
    }

    @inline(__always)
    public mutating func pushElement(tagName: String) {
        bytes.append(contentsOf: "<".utf8)
        bytes.append(contentsOf: tagName.utf8)
        bytes.append(contentsOf: ">".utf8)
    }

    @inline(__always)
    public mutating func popElement() {
        bytes.append(contentsOf: "</p>".utf8)
    }

    @inline(__always)
    public mutating func setAttribute(name: String, value: String?) {
        if let value {
            bytes.append(contentsOf: " ".utf8)
            bytes.append(contentsOf: name.utf8)
            bytes.append(contentsOf: "=\"".utf8)
            bytes.append(contentsOf: value.utf8)
            bytes.append(contentsOf: "\"".utf8)
        }
    }

    @inline(__always)
    public mutating func registerStyle(declaration: String) -> String? {
        "s\(bytes.count)"
    }
}
