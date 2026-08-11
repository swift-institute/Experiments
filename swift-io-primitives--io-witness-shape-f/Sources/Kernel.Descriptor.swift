//
// Kernel.Descriptor.swift — stand-in for Kernel.Descriptor from swift-kernel-primitives.
//

extension Kernel {
    public struct Descriptor: ~Copyable, Sendable {
        public let raw: Int32
        public init(raw: Int32) { self.raw = raw }
    }
}
