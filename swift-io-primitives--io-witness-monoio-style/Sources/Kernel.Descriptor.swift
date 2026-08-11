//
// A kernel file descriptor. Borrowed across IO calls; the descriptor lifetime
// is owned by the caller, not the witness.
//

extension Kernel {
    public struct Descriptor: Sendable {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}
