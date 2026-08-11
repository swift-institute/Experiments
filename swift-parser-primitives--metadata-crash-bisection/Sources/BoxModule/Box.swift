// No protocol. Just a plain generic struct.
public struct Box<A, B>: Sendable where A: Sendable, B: Sendable {
    public let a: A
    public let b: B
    @inlinable
    public init(_ a: A, _ b: B) {
        self.a = a
        self.b = b
    }
}
