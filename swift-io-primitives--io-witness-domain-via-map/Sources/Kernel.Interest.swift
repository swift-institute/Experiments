//
//  Kernel.Interest — readiness interest (read / write).
//

extension Kernel {
    public enum Interest: Sendable {
        case read
        case write
    }
}
