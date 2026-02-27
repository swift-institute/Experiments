// Simulates String_Primitives.String
// A top-level `String` type that would shadow Swift.String if @_exported

@safe
public struct String: ~Copyable, @unchecked Sendable {
    public typealias Char = UInt8

    @usableFromInline
    internal var _storage: [Char]

    public init(ascii literal: StaticString) {
        var bytes: [Char] = []
        let count = literal.utf8CodeUnitCount
        let start = unsafe literal.utf8Start
        for i in 0..<count {
            bytes.append(unsafe start[i])
        }
        self._storage = bytes
    }

    public var count: Int { _storage.count }

    public borrowing func withUnsafePointer<R>(
        _ body: (UnsafePointer<Char>) -> R
    ) -> R {
        unsafe _storage.withUnsafeBufferPointer { buffer in
            unsafe body(buffer.baseAddress!)
        }
    }
}
