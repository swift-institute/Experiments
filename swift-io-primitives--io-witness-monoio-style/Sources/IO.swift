//
// IO witness in monoio's "rental" shape: the closure consumes the buffer for
// the duration of the kernel operation and returns it alongside the byte
// count. Callers re-bind the buffer from the tuple on every invocation.
//
// Stored closures are non-underscored; Swift's closure-property call-as-method
// synthesis makes `io.read(fd, consume buf)` directly invoke the closure.
//

public struct IO {
    public let read:  (borrowing Kernel.Descriptor, consuming Memory.Buffer) async throws(Error) -> (Memory.Buffer, Int)
    public let write: (borrowing Kernel.Descriptor, consuming Memory.Buffer) async throws(Error) -> (Memory.Buffer, Int)

    public init(
        read:  @escaping (borrowing Kernel.Descriptor, consuming Memory.Buffer) async throws(Error) -> (Memory.Buffer, Int),
        write: @escaping (borrowing Kernel.Descriptor, consuming Memory.Buffer) async throws(Error) -> (Memory.Buffer, Int)
    ) {
        self.read = read
        self.write = write
    }
}
