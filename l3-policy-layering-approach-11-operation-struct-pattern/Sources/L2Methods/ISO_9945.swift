@_exported public import L1Defs

// L2 spec namespace — codes the spec-literal POSIX form WITHOUT REGARD to
// any downstream layer. The struct's init IS the syscall ("operation
// struct" pattern, mirroring rule-law-us-nv where `NRS 77.310.1.init(...)`
// IS the statute evaluation, not a method on a separate data type).
public enum ISO_9945 {}
extension ISO_9945 { public enum Kernel {} }
extension ISO_9945.Kernel { public enum File {} }

extension ISO_9945.Kernel.File {
    /// Operation struct: init IS the syscall. The same struct also carries
    /// the result fields, so the type plays both roles (operation +
    /// data-result). This mirrors the legal architecture's
    /// `\`NRS 77\`.\`310\`.\`1\`` shape.
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
