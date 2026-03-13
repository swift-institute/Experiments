public protocol CustomView {
    associatedtype Body: CustomView
    var body: Body { get }
}

public struct CustomNever: CustomView {
    public typealias Body = CustomNever
    public var body: CustomNever { fatalError() }
}
