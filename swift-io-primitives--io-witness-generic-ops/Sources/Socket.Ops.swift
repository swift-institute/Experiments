extension Socket {
    public struct Ops {
        public let accept:  (borrowing Kernel.Descriptor) async throws(IO<Socket.Ops>.Error) -> Kernel.Descriptor
        public let connect: (borrowing Kernel.Descriptor, UInt32) async throws(IO<Socket.Ops>.Error) -> Void
        public let read:    (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO<Socket.Ops>.Error) -> Int
        public let write:   (borrowing Kernel.Descriptor, Memory.Buffer)         async throws(IO<Socket.Ops>.Error) -> Int
        public let close:   (consuming Kernel.Descriptor) async -> Void

        public init(
            accept:  @escaping (borrowing Kernel.Descriptor) async throws(IO<Socket.Ops>.Error) -> Kernel.Descriptor,
            connect: @escaping (borrowing Kernel.Descriptor, UInt32) async throws(IO<Socket.Ops>.Error) -> Void,
            read:    @escaping (borrowing Kernel.Descriptor, Memory.Buffer.Mutable) async throws(IO<Socket.Ops>.Error) -> Int,
            write:   @escaping (borrowing Kernel.Descriptor, Memory.Buffer)         async throws(IO<Socket.Ops>.Error) -> Int,
            close:   @escaping (consuming Kernel.Descriptor) async -> Void
        ) {
            self.accept  = accept
            self.connect = connect
            self.read    = read
            self.write   = write
            self.close   = close
        }
    }
}
