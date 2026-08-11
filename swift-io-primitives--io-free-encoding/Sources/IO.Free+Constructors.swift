//
// IO.Free smart constructors — lift each Σ_IO operation into IO.Free
// at its result type. Each constructor is a one-liner that wraps the
// op constructor with a `.pure(result)` continuation.
//

extension IO.Free where Value == Int {

    public static func read(
        from descriptor: Kernel.Descriptor,
        into buffer: Memory.Buffer.Mutable
    ) -> IO.Free<Int, Failure> {
        .readOp(from: descriptor, into: buffer) { bytes in .pure(bytes) }
    }

    public static func write(
        to descriptor: Kernel.Descriptor,
        from buffer: Memory.Buffer
    ) -> IO.Free<Int, Failure> {
        .writeOp(to: descriptor, from: buffer) { bytes in .pure(bytes) }
    }
}

extension IO.Free where Value == Void {

    public static func close(
        _ descriptor: Kernel.Descriptor
    ) -> IO.Free<Void, Failure> {
        .closeOp(descriptor: descriptor) { .pure(()) }
    }

    public static func ready(
        from descriptor: Kernel.Descriptor,
        interest: Kernel.Event.Interest
    ) -> IO.Free<Void, Failure> {
        .readyOp(from: descriptor, interest: interest) { .pure(()) }
    }
}
