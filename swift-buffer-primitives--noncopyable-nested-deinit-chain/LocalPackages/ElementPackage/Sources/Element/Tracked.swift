// Cross-module, cross-PACKAGE tracked element.
// Mirrors production: Element type in user code, consumed by buffer-primitives.

nonisolated(unsafe) public var deinitCount = 0

public struct Tracked: ~Copyable {
    public let id: Int
    public init(_ id: Int) { self.id = id }
    deinit { deinitCount += 1; print("  deinit Tracked(\(id))") }
}
