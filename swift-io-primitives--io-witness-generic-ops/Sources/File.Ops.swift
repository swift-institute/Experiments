extension File {
    public struct Ops {
        public let seek:   (borrowing Kernel.Descriptor, Int64) throws(IO<File.Ops>.Error) -> Int64
        public let pread:  (borrowing Kernel.Descriptor, Memory.Buffer.Mutable, Int64) async throws(IO<File.Ops>.Error) -> Int
        public let pwrite: (borrowing Kernel.Descriptor, Memory.Buffer, Int64)         async throws(IO<File.Ops>.Error) -> Int
        public let fsync:  (borrowing Kernel.Descriptor) async throws(IO<File.Ops>.Error) -> Void
        public let close:  (consuming Kernel.Descriptor) async -> Void

        public init(
            seek:   @escaping (borrowing Kernel.Descriptor, Int64) throws(IO<File.Ops>.Error) -> Int64,
            pread:  @escaping (borrowing Kernel.Descriptor, Memory.Buffer.Mutable, Int64) async throws(IO<File.Ops>.Error) -> Int,
            pwrite: @escaping (borrowing Kernel.Descriptor, Memory.Buffer, Int64)         async throws(IO<File.Ops>.Error) -> Int,
            fsync:  @escaping (borrowing Kernel.Descriptor) async throws(IO<File.Ops>.Error) -> Void,
            close:  @escaping (consuming Kernel.Descriptor) async -> Void
        ) {
            self.seek   = seek
            self.pread  = pread
            self.pwrite = pwrite
            self.fsync  = fsync
            self.close  = close
        }
    }
}
