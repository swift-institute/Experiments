//
// IO — concrete substrate carrying projection closures for read/write/ready/close.
//

public struct IO {
    public let read:  (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO.Error) -> Int
    public let write: (borrowing Kernel.Descriptor, Memory.Buffer)         async throws(IO.Error) -> Int
    public let ready: (borrowing Kernel.Descriptor, Kernel.Interest)       async throws(IO.Error) -> Void
    public let close: (consuming Kernel.Descriptor)                        async -> Void

    public init(
        read:  @escaping (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO.Error) -> Int,
        write: @escaping (borrowing Kernel.Descriptor, Memory.Buffer)         async throws(IO.Error) -> Int,
        ready: @escaping (borrowing Kernel.Descriptor, Kernel.Interest)       async throws(IO.Error) -> Void,
        close: @escaping (consuming Kernel.Descriptor)                        async -> Void
    ) {
        self.read = read
        self.write = write
        self.ready = ready
        self.close = close
    }
}
