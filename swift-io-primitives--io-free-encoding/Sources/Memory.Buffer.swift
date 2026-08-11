//
// Memory.Buffer — read-only byte buffer stand-in. The production version
// in swift-primitives carries a base pointer + length and is `~Copyable`;
// this experiment uses just the byte count because the encoding question
// (free vs dictionary) is independent of the buffer-lifetime question.
// The ~Copyable buffer interaction is a follow-up experiment.
//

extension Memory {

    public struct Buffer: Sendable, Equatable {
        public let bytes: Int

        public init(bytes: Int) {
            self.bytes = bytes
        }
    }
}
