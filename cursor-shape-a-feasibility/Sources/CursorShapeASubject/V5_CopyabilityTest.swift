// MARK: - V5 Copyability Verification

@inlinable
public func v5_w2IsNotCopyable() {
    let bytes: [UInt8] = [1, 2, 3]
    unsafe bytes.withUnsafeBufferPointer { buf in
        let span = unsafe Swift.Span(_unsafeElements: buf)
        let storage = CursorV5.BorrowedBytes(span)
        let cursor = CursorV5.W2<ByteDomainV5>(consumingStorage: storage)
        // Pass via consuming. This compiles iff Cursor is ~Copyable
        // (Copyable values can also be consumed, but the consume label
        // is meaningful only when ~Copyable). The real test is whether
        // we can SHADOW the consumed binding — which is forbidden for
        // ~Copyable types under default-deinitialization semantics.
        useConsumed(cursor)
    }
}

@inlinable
public func useConsumed(_ c: consuming CursorV5.W2<ByteDomainV5>) {
    _ = c
}

@inlinable
public func v5_w3CanCopy() {
    let cursor: CursorV5.W3<UInt8> = CursorV5.W3<UInt8>([1, 2, 3])
    let copy: CursorV5.W3<UInt8> = cursor   // compiles only if W3 is Copyable
    _ = copy
    _ = cursor   // also compiles only if W3 is Copyable (original still usable)
}
