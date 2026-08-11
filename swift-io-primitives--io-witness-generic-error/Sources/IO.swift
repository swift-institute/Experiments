public struct IO<LeafError: Error> {
    public let read:  (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(LeafError) -> Int
    public let write: (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)         async throws(LeafError) -> Int
    public let close: (_ descriptor: consuming Kernel.Descriptor) async -> Void

    public init(
        read:  @escaping (_ from: borrowing Kernel.Descriptor, _ into: Memory.Buffer.Mutable) async throws(LeafError) -> Int,
        write: @escaping (_ to:   borrowing Kernel.Descriptor, _ from: Memory.Buffer)         async throws(LeafError) -> Int,
        close: @escaping (_ descriptor: consuming Kernel.Descriptor) async -> Void
    ) {
        self.read = read
        self.write = write
        self.close = close
    }
}

extension IO {
    public func mapError<NewError: Swift.Error>(
        _ transform: @escaping (LeafError) -> NewError
    ) -> IO<NewError> {
        IO<NewError>(
            read: { (fd, buf) async throws(NewError) in
                do throws(LeafError) {
                    return try await self.read(fd, buf)
                } catch {
                    throw transform(error)
                }
            },
            write: { (fd, buf) async throws(NewError) in
                do throws(LeafError) {
                    return try await self.write(fd, buf)
                } catch {
                    throw transform(error)
                }
            },
            close: self.close
        )
    }
}
