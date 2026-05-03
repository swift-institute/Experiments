public enum Kernel {}
extension Kernel { public enum File {} }

public enum FooError: Error, Sendable, Equatable {
    case interrupted
    case failed
}
