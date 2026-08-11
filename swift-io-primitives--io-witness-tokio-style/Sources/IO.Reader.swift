//
// IO.Reader — the read half of the Tokio-style split. One independently
// substitutable capability: reading bytes from a descriptor into a mutable
// buffer. Mirrors Tokio's `AsyncRead`.
//
// Hand-written struct of closures (was @Witness-generated). Removed the
// macro dependency to keep this experiment in isolation at L1.
//

extension IO {
    public struct Reader {
        public let read: (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int

        public init(
            read: @escaping (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
        ) {
            self.read = read
        }
    }
}

extension IO.Reader {
    public static func unimplemented() -> IO.Reader {
        IO.Reader(read: { _, _ in fatalError("IO.Reader.read unimplemented") })
    }
}
