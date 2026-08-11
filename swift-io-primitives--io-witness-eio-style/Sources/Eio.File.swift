// Eio.File — sub-capability for file I/O. Hand-written struct of closures
// (was @Witness-generated).

extension Eio {
    public struct File: Sendable {
        public let open: @Sendable (_ path: String) async throws(IO.Error) -> Kernel.Descriptor

        public init(
            open: @Sendable @escaping (_ path: String) async throws(IO.Error) -> Kernel.Descriptor
        ) {
            self.open = open
        }
    }
}

extension Eio.File {
    public static func unimplemented() -> Eio.File {
        Eio.File(open: { _ in fatalError("Eio.File.open unimplemented") })
    }
}
