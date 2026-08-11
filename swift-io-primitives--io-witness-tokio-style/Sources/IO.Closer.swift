//
// IO.Closer — the third independently substitutable capability: consuming a
// descriptor to close it. No error channel — closure semantics in Tokio's
// split model are infallible.
//
// Hand-written struct of closures (was @Witness-generated).
//

extension IO {
    public struct Closer {
        public let close: (_ fd: consuming Kernel.Descriptor) async -> Void

        public init(
            close: @escaping (_ fd: consuming Kernel.Descriptor) async -> Void
        ) {
            self.close = close
        }
    }
}

extension IO.Closer {
    public static func unimplemented() -> IO.Closer {
        IO.Closer(close: { _ in fatalError("IO.Closer.close unimplemented") })
    }
}
