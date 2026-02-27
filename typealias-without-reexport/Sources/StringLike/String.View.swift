// Simulates String_Primitives.String.View (simplified, ~Copyable only)

extension String {
    @safe
    public struct View: ~Copyable {
        @usableFromInline
        internal let _byte: String.Char

        @inlinable
        internal init(_ byte: String.Char) {
            self._byte = byte
        }

        public var firstByte: String.Char { _byte }
    }

    public borrowing func view() -> View {
        View(unsafe _storage.withUnsafeBufferPointer { unsafe $0.baseAddress!.pointee })
    }
}
