//
// Memory.Buffer.Mutable — writable byte buffer stand-in. The production
// version in swift-primitives carries a base pointer + capacity and is
// `~Copyable`; this experiment uses just the capacity for the same
// reason as `Memory.Buffer`.
//

extension Memory.Buffer {

    public struct Mutable: Sendable, Equatable {
        public let capacity: Int

        public init(capacity: Int) {
            self.capacity = capacity
        }
    }
}
