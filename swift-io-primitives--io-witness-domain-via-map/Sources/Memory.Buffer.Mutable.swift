//
//  Memory.Buffer.Mutable — non-owning view onto a mutable byte range.
//

extension Memory.Buffer {
    public struct Mutable: Sendable {
        public let count: Int

        public init(count: Int) {
            self.count = count
        }
    }
}
