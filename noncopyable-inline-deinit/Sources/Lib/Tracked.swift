// MARK: - Cross-Module Tracked Element
// Purpose: ~Copyable element with deinit, defined in a SEPARATE module
// This mirrors production: Buffer types are in one module, elements in another.

/// Global deinit counter — accessible from both modules.
nonisolated(unsafe) public var deinitCount = 0

/// A ~Copyable element that tracks deinit calls.
public struct Tracked: ~Copyable {
    public let id: Int
    public init(_ id: Int) { self.id = id }
    deinit { deinitCount += 1; print("  deinit Tracked(\(id))") }
}
