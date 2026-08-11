// IO.Error — shared error type for all I/O capabilities in this sketch.

extension IO {
    public enum Error: Swift.Error, Sendable {
        case failed
    }
}
