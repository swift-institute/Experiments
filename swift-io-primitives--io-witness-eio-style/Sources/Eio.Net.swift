// Eio.Net — sub-capability for network I/O. Hand-written struct of closures
// (was @Witness-generated). Removed the macro dependency to keep this
// experiment in isolation at L1.

extension Eio {
    public struct Net: Sendable {
        public let connect: @Sendable (_ host: String, _ port: UInt16) async throws(IO.Error) -> Kernel.Descriptor

        public init(
            connect: @Sendable @escaping (_ host: String, _ port: UInt16) async throws(IO.Error) -> Kernel.Descriptor
        ) {
            self.connect = connect
        }
    }
}

extension Eio.Net {
    public static func unimplemented() -> Eio.Net {
        Eio.Net(connect: { _, _ in fatalError("Eio.Net.connect unimplemented") })
    }
}
