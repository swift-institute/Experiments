//
// IO.Duplex — bundle of the three independently-substitutable witnesses for
// consumers that need bidirectional I/O (read + write + close) on a single
// endpoint. "Duplex" captures the semantic of bidirectional I/O; "Bundle"
// would describe the implementation rather than the concept.
//

extension IO {
    public struct Duplex {
        public let reader: IO.Reader
        public let writer: IO.Writer
        public let closer: IO.Closer

        public init(reader: IO.Reader, writer: IO.Writer, closer: IO.Closer) {
            self.reader = reader
            self.writer = writer
            self.closer = closer
        }
    }
}
