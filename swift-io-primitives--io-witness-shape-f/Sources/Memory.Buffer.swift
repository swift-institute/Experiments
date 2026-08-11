//
// Memory.Buffer.swift — Sendable stand-in for Memory.Buffer from swift-memory-primitives.
// Pointers in the real API are wrapped in a Sendable view; for this compile-only sketch
// a plain count suffices.
//

extension Memory {
    public struct Buffer: Sendable {
        public let count: Int
        public init(count: Int) { self.count = count }
    }
}
