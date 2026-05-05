@_exported public import L1Defs

// L2 spec namespace — codes the spec-literal form WITHOUT REGARD to any
// downstream layer. Just the natural shape iso-9945 would have if it
// existed in isolation.
public enum ISO_9945 {}

extension ISO_9945 {
    public enum Kernel {}
}

extension ISO_9945.Kernel {
    public enum File {}
}

extension ISO_9945.Kernel.File {
    // The struct lives at L2 because POSIX `struct stat` is a POSIX-defined
    // shape. Fields mirror the POSIX spec literally.
    public struct Stats: Sendable, Equatable {
        public let size: Int64
        public let permissions: UInt16
        public init(size: Int64, permissions: UInt16) {
            self.size = size
            self.permissions = permissions
        }
    }
}

extension ISO_9945.Kernel.File.Stats {
    // Spec-literal `fstat(2)`. No retry, no policy. Just the syscall.
    public static func get() throws(FooError) -> ISO_9945.Kernel.File.Stats {
        return ISO_9945.Kernel.File.Stats(size: 1024, permissions: 0o644)
    }
}
