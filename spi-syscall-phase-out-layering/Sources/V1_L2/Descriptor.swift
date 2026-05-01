// MARK: - V1: status quo `@_spi(Syscall)` raw companion at L2
// Purpose: Baseline. L2 publishes BOTH typed (consuming Descriptor) AND raw
// (Int32 fd) forms of `Close.close`. Raw form is gated by `@_spi(Syscall)`.
// Consumers can opt in via `@_spi(Syscall) import V1_L2`.
//
// Toolchain: Apple Swift 6.3.1 (Xcode 26.4.1)
// Platform: macOS 26.0 (arm64)
//
// Result: see Outputs/V1-{debug,release,cross-module}.txt

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}
