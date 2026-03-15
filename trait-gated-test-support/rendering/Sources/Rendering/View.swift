// Simulates HTML.View from swift-html-rendering
public protocol View {
    var body: String { get }
}

public struct Text: View {
    public let content: String
    public init(_ content: String) { self.content = content }
    public var body: String { "<p>\(content)</p>" }
}
