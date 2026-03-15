// MARK: - Ref<T>
// Reference wrapper for mutable state capture.
// Closures capture Ref (reference type) instead of UnsafeMutablePointer.
// Avoids unsafe code while providing shared mutable access.

public final class Ref<T>: @unchecked Sendable {
    public var value: T

    public init(_ value: consuming T) {
        self.value = value
    }
}
