// MARK: - V7: Cross-module + release-mode validation (per [EXP-017])
//
// Purpose: Instantiate the Shape A unified Cursor from a separate target
// (cross-module). [EXP-017] mandates cross-module + release-mode validation
// for any experiment whose CONFIRMED verdict admits production adoption.
//
// Toolchain: Swift 6.3.1
// Platform: macOS 26 / arm64e
// Result: TBD

import CursorShapeASubject

// W2 cross-module use
@inline(never)
func walkSpanCrossModule() -> UInt32 {
    let bytes: [UInt8] = [0x01, 0x02, 0x03, 0x04]
    return unsafe bytes.withUnsafeBufferPointer { buf -> UInt32 in
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

// W3 cross-module use
@inline(never)
func walkArrayCrossModule() -> UInt32 {
    var cursor = CursorV5.W3<UInt8>([10, 20, 30, 40])
    var sum: UInt32 = 0
    while let b = cursor.w3_peek() {
        sum &+= UInt32(b)
        cursor.w3_advance()
    }
    return sum
}

// V5 Copyability across module boundary: verify W3 is Copyable cross-module
@inline(never)
func w3CopyableCrossModule() {
    let cursor: CursorV5.W3<UInt8> = CursorV5.W3<UInt8>([1, 2, 3])
    let copy: CursorV5.W3<UInt8> = cursor   // requires Copyable
    _ = copy
    _ = cursor
}

let w2Result = walkSpanCrossModule()
let w3Result = walkArrayCrossModule()
w3CopyableCrossModule()

print("[V7 cross-module] W2 sum: \(w2Result), W3 sum: \(w3Result)")
