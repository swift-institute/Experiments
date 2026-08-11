//
// Typed error for I/O operations. Nested under IO per [API-ERR-002].
// Single-case placeholder kept in the spirit of the original sketch.
//

extension IO {
    public enum Error: Swift.Error {
        case failed
    }
}
