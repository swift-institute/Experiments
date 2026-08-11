// Kernel.Descriptor — opaque placeholder for an OS file descriptor.

extension Kernel {
    public struct Descriptor: Sendable {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}
