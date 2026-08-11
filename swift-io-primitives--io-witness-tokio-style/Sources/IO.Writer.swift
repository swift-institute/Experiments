//
// IO.Writer — the write half of the Tokio-style split. One independently
// substitutable capability: writing bytes from a buffer to a descriptor.
// Mirrors Tokio's `AsyncWrite`.
//
// Hand-written struct of closures (was @Witness-generated).
//

extension IO {
    public struct Writer {
        public let write: (_ to: borrowing Kernel.Descriptor, _ from: Memory.Buffer) async throws(IO.Error) -> Int

        public init(
            write: @escaping (_ to: borrowing Kernel.Descriptor, _ from: Memory.Buffer) async throws(IO.Error) -> Int
        ) {
            self.write = write
        }
    }
}

extension IO.Writer {
    public static func unimplemented() -> IO.Writer {
        IO.Writer(write: { _, _ in fatalError("IO.Writer.write unimplemented") })
    }
}
