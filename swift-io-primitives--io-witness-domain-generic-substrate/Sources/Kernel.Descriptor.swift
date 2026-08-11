//
// Kernel.Descriptor — file/socket descriptor. Copyable for sketch simplicity.
//

extension Kernel {
    public struct Descriptor {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}
