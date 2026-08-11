//
//  Memory.Buffer — non-owning view onto a read-only byte range.
//

extension Memory {
    public struct Buffer: Sendable {
        public let count: Int

        public init(count: Int) {
            self.count = count
        }
    }
}
