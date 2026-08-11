//
// Placeholder Memory.Buffer (immutable byte buffer). The real primitive lives
// in swift-memory-primitives; this sketch carries only the API surface needed
// to exercise the split-witness shape.
//

extension Memory {
    public struct Buffer {
        public let count: Int

        public init(count: Int) {
            self.count = count
        }
    }
}
