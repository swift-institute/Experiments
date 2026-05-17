public import Tagged_Primitives
public import Ordinal_Primitives
public import Cardinal_Primitives

extension Cursor {
    /// Borrowed read-only Span-cursor over UTF-8 bytes.
    ///
    /// Subject of the `[BENCH-011]` probe. Final shape lives at
    /// `swift-cursor-primitives` once Phase 0 passes green; this experiment
    /// vendors the same shape for measurement purposes only.
    @safe
    public struct Span<DomainTag: ~Copyable & ~Escapable>: ~Copyable, ~Escapable {
        @usableFromInline
        internal let source: Swift.Span<UInt8>

        @usableFromInline
        internal var _position: Tagged<DomainTag, Ordinal>

        @inlinable
        @_lifetime(borrow source)
        public init(_ source: borrowing Swift.Span<UInt8>) {
            self.source = copy source
            self._position = Tagged<DomainTag, Ordinal>(_unchecked: Ordinal(UInt(0)))
        }
    }
}

extension Cursor.Span {
    /// The cursor's current position within the borrowed span.
    @inlinable
    public var position: Tagged<DomainTag, Ordinal> { _position }

    /// Number of bytes remaining from the current position to the end.
    @inlinable
    public var count: Tagged<DomainTag, Cardinal> {
        Tagged<DomainTag, Cardinal>(
            _unchecked: Cardinal(UInt(bitPattern: source.count - Int(bitPattern: _position)))
        )
    }

    /// `true` if no bytes remain to read.
    @inlinable
    public var isAtEnd: Bool {
        Int(bitPattern: _position) >= source.count
    }

    /// The byte at the current position, or `nil` if at end of input.
    @inlinable
    public func peek() -> UInt8? {
        let p = Int(bitPattern: _position)
        guard p < source.count else { return nil }
        return source[p]
    }

    /// The byte `offset` positions past the current cursor, or `nil` if past
    /// the end.
    @inlinable
    public func peek(at offset: Tagged<DomainTag, Cardinal>) -> UInt8? {
        let p = Int(bitPattern: _position) &+ Int(bitPattern: offset)
        guard p >= 0 && p < source.count else { return nil }
        return source[p]
    }

    /// Advances the cursor by one byte.
    ///
    /// - Precondition: `!isAtEnd`.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func advance() {
        precondition(Int(bitPattern: _position) < source.count, "advance() past end")
        _position += .one
    }

    /// Advances the cursor by `count` bytes.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func advance(by count: Tagged<DomainTag, Cardinal>) {
        _position += count
    }

    /// Reads the byte at the current cursor and advances by one.
    ///
    /// Fused peek-then-advance. Precondition: `!isAtEnd`.
    @inlinable
    @_lifetime(self: copy self)
    public mutating func consume() -> UInt8 {
        let p = Int(bitPattern: _position)
        precondition(p < source.count, "consume() past end")
        let b = source[p]
        _position += .one
        return b
    }
}
