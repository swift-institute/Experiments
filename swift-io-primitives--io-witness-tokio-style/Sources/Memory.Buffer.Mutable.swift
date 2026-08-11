//
// Placeholder Memory.Buffer.Mutable (mutable byte buffer). Nested under
// Memory.Buffer per [API-NAME-001] — "Mutable" is a variant label, not a
// sibling domain.
//

extension Memory.Buffer {
    public struct Mutable {
        public let count: Int

        public init(count: Int) {
            self.count = count
        }
    }
}
