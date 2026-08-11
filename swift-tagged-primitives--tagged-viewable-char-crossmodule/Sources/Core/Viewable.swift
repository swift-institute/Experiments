// Core module: Viewable protocol (mirrors identity-primitives)

public protocol Viewable: ~Copyable {
    associatedtype View: ~Copyable, ~Escapable
}

extension Tagged: Viewable where RawValue: Viewable & ~Copyable, Tag: ~Copyable {
    public typealias View = RawValue.View
}
