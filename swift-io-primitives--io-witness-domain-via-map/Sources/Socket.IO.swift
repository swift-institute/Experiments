//
//  Socket.IO — socket-domain capability built from IO via .map.
//
//  Hand-written struct of closures (was @Witness-generated). Constructed from
//  a generic IO by `Socket.IO.make(from:)`, which captures the IO inside the
//  closures and calls `io.ready` + a raw syscall stand-in per operation. No
//  SPI, no protocol, no existential.
//

extension Socket {
    public struct IO {
        // Peer address is returned alongside the accepted descriptor so callers
        // do not need a follow-up getpeername call.
        //
        // NOTE: `io_witness_domain_via_map.IO.Error` is module-qualified to
        // disambiguate the top-level `IO` from the enclosing `Socket.IO`. Per
        // `feedback_module_disambiguation_not_rename.md`, we disambiguate via
        // module qualification instead of renaming the error or the witness.
        public let accept:   (_ on: borrowing Kernel.Descriptor) async throws(io_witness_domain_via_map.IO.Error) -> (Kernel.Descriptor, Socket.Address)
        public let connect:  (_ fd: borrowing Kernel.Descriptor, _ to: Socket.Address) async throws(io_witness_domain_via_map.IO.Error) -> Void
        public let shutdown: (_ fd: borrowing Kernel.Descriptor) throws(io_witness_domain_via_map.IO.Error) -> Void

        public init(
            accept:   @escaping (_ on: borrowing Kernel.Descriptor) async throws(io_witness_domain_via_map.IO.Error) -> (Kernel.Descriptor, Socket.Address),
            connect:  @escaping (_ fd: borrowing Kernel.Descriptor, _ to: Socket.Address) async throws(io_witness_domain_via_map.IO.Error) -> Void,
            shutdown: @escaping (_ fd: borrowing Kernel.Descriptor) throws(io_witness_domain_via_map.IO.Error) -> Void
        ) {
            self.accept = accept
            self.connect = connect
            self.shutdown = shutdown
        }
    }
}

extension Socket.IO {
    /// Stand-in for a raw accept syscall. In a real implementation this calls
    /// `Kernel.Socket.Accept.accept(listener)`.
    static func simulateAccept(
        listener: borrowing Kernel.Descriptor
    ) -> Swift.Result<(Kernel.Descriptor, Socket.Address), io_witness_domain_via_map.IO.Error> {
        .failure(.wouldBlock)
    }

    /// Build a Socket.IO from an IO. Strategy polymorphism is preserved — the
    /// same builder works for blocking / events / completions substrates,
    /// because `io.ready` has strategy-specific semantics (no-op /
    /// register-then-wait / IORING_OP_POLL_ADD) and the post-ready syscall
    /// runs on the caller's pinned executor per the shared-executor pattern.
    public static func make(from io: sending io_witness_domain_via_map.IO) -> sending Socket.IO {
        io.map { io in
            Socket.IO(
                accept: { (listener: borrowing Kernel.Descriptor) async throws(io_witness_domain_via_map.IO.Error) -> (Kernel.Descriptor, Socket.Address) in
                    // 1. Wait for readiness (strategy-specific).
                    try await io.ready(listener, .read)
                    // 2. Sync accept syscall (runs on caller's pinned executor).
                    switch Socket.IO.simulateAccept(listener: listener) {
                    case .success(let pair): return pair
                    case .failure(let e):    throw e
                    }
                },
                connect: { (fd: borrowing Kernel.Descriptor, to: Socket.Address) async throws(io_witness_domain_via_map.IO.Error) -> Void in
                    // A real impl: may require io.ready(.write) for non-blocking connect.
                    throw io_witness_domain_via_map.IO.Error.refused
                },
                shutdown: { (fd: borrowing Kernel.Descriptor) throws(io_witness_domain_via_map.IO.Error) -> Void in
                    // A real impl: calls Kernel.Socket.Shutdown.shutdown(fd, how: .both).
                }
            )
        }
    }
}
