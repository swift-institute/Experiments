// Shared FakeHandle simulates a Win32 HANDLE on macOS. The experiment is
// about namespace shape, not Win32 semantics — every variant uses the same
// handle stand-in so the typed L3 wrapper has a uniform parameter type.

public struct FakeHandle: Equatable, Sendable {
    public let value: UInt
    public init(_ value: UInt) { self.value = value }
    public static let invalid = FakeHandle(0)
}
