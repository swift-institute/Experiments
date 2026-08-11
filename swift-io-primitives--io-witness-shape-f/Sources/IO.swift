//
// IO.swift — capability witness covering pure I/O operations.
//
// Hand-written struct of closures (was @Witness-generated). Removed the
// macro dependency to keep this experiment in isolation at L1 — see
// Research/README.md.
//

public struct IO {
    public let read:  (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    public let write: (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)          async throws(IO.Error) -> Int
    public let close: (_ descriptor: consuming Kernel.Descriptor) async -> Void
    public let ready: (_ from: borrowing Kernel.Descriptor, _ interest: Kernel.Interest) async throws(IO.Error) -> Void

    public init(
        read:  @escaping (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(IO.Error) -> Int,
        write: @escaping (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)          async throws(IO.Error) -> Int,
        close: @escaping (_ descriptor: consuming Kernel.Descriptor) async -> Void,
        ready: @escaping (_ from: borrowing Kernel.Descriptor, _ interest: Kernel.Interest) async throws(IO.Error) -> Void
    ) {
        self.read = read
        self.write = write
        self.close = close
        self.ready = ready
    }
}

extension IO {
    public static func unimplemented() -> IO {
        IO(
            read:  { _, _ in fatalError("IO.read unimplemented") },
            write: { _, _ in fatalError("IO.write unimplemented") },
            close: { _ in fatalError("IO.close unimplemented") },
            ready: { _, _ in fatalError("IO.ready unimplemented") }
        )
    }
}
