//
// Memory.Buffer.Mutable.swift — Sendable stand-in for Memory.Buffer.Mutable.
//

extension Memory.Buffer {
    public struct Mutable: Sendable {
        public let count: Int
        public init(count: Int) { self.count = count }
    }
}
