public protocol CustomView {
    associatedtype Body: CustomView
    var body: Body { get }
}

public struct CustomNever: CustomView {
    public typealias Body = CustomNever
    public var body: CustomNever { fatalError() }
}

@resultBuilder
public struct CustomBuilder {
    public static func buildBlock() -> CustomNever { CustomNever() }
    public static func buildBlock<C: CustomView>(_ component: C) -> C { component }
}

public struct CustomText: CustomView {
    public let text: String
    public init(_ text: String) { self.text = text }
    public typealias Body = CustomNever
    public var body: CustomNever { fatalError() }
}
