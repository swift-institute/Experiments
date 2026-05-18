// MARK: - V6: Operation surfaces via conditional extensions
//
// Tests whether peek/advance/consume can be added via where-clause-gated
// extensions on the unified Cursor type, with the surface differing per
// Storage class.
//
// Operations expected:
//   - W2 (BorrowedBytes wrapper around Span<UInt8>): peek(), advance(),
//     consume() over Span<UInt8> bytes.
//   - W3 ([Element]): peek() returning Element?, advance(), consume()
//     returning Element.
//   - W1 (Memory.Contiguous.Protocol-conforming ~Copyable Storage): dual-
//     index reader-writer surface. Skipped here — depends on Memory.
//     Contiguous.Protocol which would pull in tier-12 deps, beyond this
//     experiment's scope. The V1/V2/V5 evidence shows the type-system
//     mechanics work; W1's operation surface is the same conditional-
//     extension pattern.
//
// Hypothesis: peek/advance/consume conditional extensions compile cleanly
// for the W2 (Span-via-BorrowedBytes) and W3 ([Element]) instantiations.
//
// Toolchain: Swift 6.3.1
// Result: TBD

public import Tagged_Primitives
public import Ordinal_Primitives
public import Cardinal_Primitives

// MARK: - W2 operations (Cursor over BorrowedBytes)

extension CursorV5.Cursor
where Storage == CursorV5.BorrowedBytes, PositionTag: ~Copyable {
    @inlinable
    public var position: Tagged<PositionTag, Ordinal> { _position }

    @inlinable
    public var isAtEnd: Bool {
        Int(bitPattern: _position) >= storage.span.count
    }

    @inlinable
    public func peek() -> UInt8? {
        let p = Int(bitPattern: _position)
        guard p < storage.span.count else { return nil }
        return storage.span[p]
    }

    @inlinable
    @_lifetime(self: copy self)
    public mutating func advance() {
        precondition(Int(bitPattern: _position) < storage.span.count, "advance() past end")
        _position += .one
    }

    @inlinable
    @_lifetime(self: copy self)
    public mutating func consume() -> UInt8 {
        let p = Int(bitPattern: _position)
        precondition(p < storage.span.count, "consume() past end")
        let b = storage.span[p]
        _position += .one
        return b
    }

    // Convenience init: take Span directly, construct BorrowedBytes internally.
    @inlinable
    @_lifetime(borrow span)
    public init(_ span: borrowing Swift.Span<UInt8>) {
        self.init(consumingStorage: CursorV5.BorrowedBytes(span))
    }
}

// MARK: - W3 operations (Cursor over [Element])

extension CursorV5.Cursor where Storage == [UInt8], PositionTag == UInt8 {
    @inlinable
    public var w3_position: Tagged<UInt8, Ordinal> { _position }

    @inlinable
    public var w3_isAtEnd: Bool {
        Int(bitPattern: _position) >= storage.count
    }

    @inlinable
    public func w3_peek() -> UInt8? {
        let p = Int(bitPattern: _position)
        guard p < storage.count else { return nil }
        return storage[p]
    }

    @inlinable
    public mutating func w3_advance() {
        precondition(Int(bitPattern: _position) < storage.count, "advance() past end")
        _position += .one
    }

    @inlinable
    public mutating func w3_consume() -> UInt8 {
        let p = Int(bitPattern: _position)
        precondition(p < storage.count, "consume() past end")
        let b = storage[p]
        _position += .one
        return b
    }
}

// MARK: - V6 Verification

@inlinable
public func v6_w2_walks_a_span() {
    let bytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
    let _: UInt32 = unsafe bytes.withUnsafeBufferPointer { buf -> UInt32 in
        let span = unsafe Swift.Span(_unsafeElements: buf)
        var cursor = CursorV5.W2<ByteDomainV5>(span)
        var sum: UInt32 = 0
        while let b = cursor.peek() {
            sum &+= UInt32(b)
            cursor.advance()
        }
        return sum
    }
}

@inlinable
public func v6_w3_walks_an_array() {
    var cursor = CursorV5.W3<UInt8>([1, 2, 3, 4])
    var sum: UInt32 = 0
    while let b = cursor.w3_peek() {
        sum &+= UInt32(b)
        cursor.w3_advance()
    }
    _ = sum
}
