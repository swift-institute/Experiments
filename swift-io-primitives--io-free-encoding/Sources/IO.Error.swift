//
// IO.Error — typed error channel for Σ_IO. Cases mirror POSIX error
// names where applicable (per [API-NAME-002] spec-mirroring exception).
//

extension IO {

    public enum Error: Swift.Error, Sendable, Equatable {
        case wouldBlock
        case brokenPipe
        case closed
        case invalid(descriptor: Kernel.Descriptor)
    }
}
