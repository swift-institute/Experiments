@_exported public import L1Defs

// L2 spec namespace — codes the spec-literal POSIX form WITHOUT REGARD to
// any downstream layer. Plain struct, plain `public` methods, no
// awareness of Tagged or any L3 mechanism. iso-9945 is unchanged from
// production form.
public enum ISO_9945 {}
extension ISO_9945 { public enum Kernel {} }
extension ISO_9945.Kernel { public enum File {} }

extension ISO_9945.Kernel.File {
    /// L2's struct: data + the spec-literal operation as init.
    public struct Stats: Sendable, Equatable {
        public let size: Int64
        public let permissions: UInt16

        /// Spec-literal `fstat(2)`. No retry, no policy. Just the syscall.
        ///
        /// Simulation: `descriptor == -1` returns EINTR; any other value
        /// succeeds with size=1024, perms=0o644.
        public init(descriptor: Int32) throws(FooError) {
            if descriptor == -1 {
                throw FooError.interrupted
            }
            self.size = 1024
            self.permissions = 0o644
        }
    }
}
