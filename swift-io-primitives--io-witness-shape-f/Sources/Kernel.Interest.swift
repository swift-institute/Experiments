//
// Kernel.Interest.swift — stand-in for Kernel.Interest (readiness direction).
//

extension Kernel {
    public enum Interest: Sendable {
        case read
        case write
    }
}
