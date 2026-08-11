//
// IO.Error.swift — typed error domain for IO operations.
//

extension IO {
    public enum Error: Swift.Error, Sendable {
        case closed
        case wouldBlock
        case platform(Int32)
    }
}
