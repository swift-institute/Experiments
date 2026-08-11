//
// Placeholder Kernel.Descriptor. Copyable for sketch simplicity — the real
// primitive is ~Copyable. Mirrors the shape used in swift-io's Kernel.Descriptor
// so the witness closures carry the same ownership annotations.
//

extension Kernel {
    public struct Descriptor {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}
