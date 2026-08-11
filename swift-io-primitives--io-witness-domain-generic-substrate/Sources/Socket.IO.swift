//
// Socket.IO<Substrate> — domain witness generic over the IO substrate it consumes.
//
// Without protocols, `Substrate` is opaque. We cannot write `substrate.ready(...)`.
// We must ALSO store a projection that exposes substrate ops — which defeats
// the purpose of making Substrate generic: you may as well take the projection
// closures directly and drop the generic parameter. This is the REDUNDANT-with-map
// pattern this experiment demonstrates.
//
// Note: inside `Socket.IO`, the unqualified name `IO` resolves to the enclosing
// `Socket.IO` type and shadows the top-level `IO` struct. We disambiguate via
// module qualification: `io_witness_domain_generic_substrate.IO`.
//

extension Socket {
    public struct IO<Substrate> {
        public let substrate: Substrate
        public let accept: (borrowing Substrate, borrowing Kernel.Descriptor) async throws(io_witness_domain_generic_substrate.IO.Error) -> Kernel.Descriptor

        public init(
            substrate: sending Substrate,
            accept: @escaping (borrowing Substrate, borrowing Kernel.Descriptor) async throws(io_witness_domain_generic_substrate.IO.Error) -> Kernel.Descriptor
        ) {
            self.substrate = substrate
            self.accept = accept
        }
    }
}

extension Socket.IO {
    public func accept(on listener: borrowing Kernel.Descriptor) async throws(io_witness_domain_generic_substrate.IO.Error) -> Kernel.Descriptor {
        try await self.accept(substrate, listener)
    }
}

// Specialization to IO substrate (common case).
extension Socket.IO where Substrate == io_witness_domain_generic_substrate.IO {
    public static func on(_ io: sending io_witness_domain_generic_substrate.IO) -> sending Socket.IO<io_witness_domain_generic_substrate.IO> {
        Socket.IO<io_witness_domain_generic_substrate.IO>(
            substrate: io,
            accept: { (substrate: borrowing io_witness_domain_generic_substrate.IO, listener: borrowing Kernel.Descriptor) async throws(io_witness_domain_generic_substrate.IO.Error) -> Kernel.Descriptor in
                // Use the substrate via the explicit closure-stored projection.
                try await substrate.ready(listener, .read)
                // simulated syscall
                return Kernel.Descriptor(raw: -1)
            }
        )
    }
}
