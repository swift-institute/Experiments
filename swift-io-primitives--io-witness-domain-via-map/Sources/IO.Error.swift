//
//  IO.Error — typed error domain for the generic IO witness and its
//  domain-specific compositions (e.g., Socket.IO).
//

extension IO {
    public enum Error: Swift.Error, Sendable {
        case closed
        case wouldBlock
        case refused
        case unreachable
        case platform(Int32)
    }
}
