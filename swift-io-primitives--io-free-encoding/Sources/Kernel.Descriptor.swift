//
// Kernel.Descriptor — file/socket/pipe descriptor stand-in. The production
// version in swift-kernel-primitives is `~Copyable`; this experiment
// uses a Copyable struct because the encoding question (free vs
// dictionary) is independent of the descriptor-ownership question.
//

extension Kernel {

    public struct Descriptor: Sendable, Equatable {
        public let raw: Int32

        public init(raw: Int32) {
            self.raw = raw
        }
    }
}
