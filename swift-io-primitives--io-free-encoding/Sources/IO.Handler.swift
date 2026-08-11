//
// IO.Handler<Failure> — the dictionary encoding of Σ_IO with a typed
// error channel. Each closure may throw Failure. The IO.Free
// interpreter (`IO.Free.run`) folds IO.Free<Value, Failure> against
// IO.Handler<Failure>; handler throws propagate as `throws(Failure)`
// from the interpreter.
//
// Same shape as the production swift-io `IO` witness (4 closures),
// modulo the ~Copyable Descriptor that this experiment elides for
// simplicity — see `Memory.Buffer.Mutable.swift` for the rationale.
//

extension IO {

    public struct Handler<Failure: Swift.Error & Sendable>: Sendable {

        public let read:  @Sendable (Kernel.Descriptor, Memory.Buffer.Mutable) async throws(Failure) -> Int
        public let write: @Sendable (Kernel.Descriptor, Memory.Buffer)         async throws(Failure) -> Int
        public let close: @Sendable (Kernel.Descriptor)                        async throws(Failure) -> Void
        public let ready: @Sendable (Kernel.Descriptor, Kernel.Event.Interest) async throws(Failure) -> Void

        public init(
            read:  @Sendable @escaping (Kernel.Descriptor, Memory.Buffer.Mutable) async throws(Failure) -> Int,
            write: @Sendable @escaping (Kernel.Descriptor, Memory.Buffer)         async throws(Failure) -> Int,
            close: @Sendable @escaping (Kernel.Descriptor)                        async throws(Failure) -> Void,
            ready: @Sendable @escaping (Kernel.Descriptor, Kernel.Event.Interest) async throws(Failure) -> Void
        ) {
            self.read = read
            self.write = write
            self.close = close
            self.ready = ready
        }
    }
}
