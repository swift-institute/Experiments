// MARK: - V2 Copyability Verification
//
// Test: when instantiated as W2 (Span-backed), is Cursor Copyable?
// The institute's W2 design requires ~Copyable for affine ownership.
// Bare conditional conformance inherits Copyability from Storage, which
// would make W2 inadvertently Copyable since Swift.Span<UInt8> IS Copyable.

public import Tagged_Primitives

@inlinable
public func v2_canCopyW2() {
    let bytes: [UInt8] = [1, 2, 3]
    unsafe bytes.withUnsafeBufferPointer { buf in
        let span = unsafe Swift.Span(_unsafeElements: buf)
        let cursor: CursorV2.W2<ByteDomain> = CursorV2.W2<ByteDomain>(span)
        // If this line compiles, W2 inherited Copyable from Span — BAD.
        // If it errors with "use of consumed value" or similar, W2 is ~Copyable — GOOD.
        let _copy: CursorV2.W2<ByteDomain> = cursor
        _ = _copy
    }
}

@inlinable
public func v2_canCopyW3() {
    let bytes: [UInt8] = [1, 2, 3]
    let cursor: CursorV2.W3<UInt8> = CursorV2.W3<UInt8>(bytes)
    // W3 should be Copyable — this should compile.
    let _copy: CursorV2.W3<UInt8> = cursor
    _ = _copy
}
