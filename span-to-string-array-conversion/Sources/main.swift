// MARK: - Span-to-String and Span-to-Array Conversion
// Purpose: Find the best available syntax for converting Span<UInt8> to String
//          and Span<T> to Array<T> without closure-based withUnsafeBufferPointer.
//
// Hypothesis: Swift 6.2 may provide direct conversion paths that avoid closures.
//
// Toolchain: Apple Swift 6.2.4
// Platform: macOS 26 (arm64)
//
// Result: PENDING
// Date: 2026-03-19

// Helper: create a Span from a known buffer
func withTestSpan<R>(_ bytes: [UInt8], _ body: (Span<UInt8>) -> R) -> R {
    bytes.withUnsafeBufferPointer { buffer in
        let span = Span(_unsafeStart: buffer.baseAddress!, count: buffer.count)
        return body(span)
    }
}

// ============================================================
// PART A: Span<UInt8> → String
// ============================================================

// MARK: - V1: Current pattern (the one we want to eliminate)
func v1_withUnsafeBufferPointer() {
    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
        span.withUnsafeBufferPointer { buffer in
            String(decoding: buffer, as: UTF8.self)
        }
    }
    assert(result == "Hello")
    print("V1 CONFIRMED: span.withUnsafeBufferPointer { String(decoding:as:) }")
}

// MARK: - V2: String(decoding: span, as: UTF8.self) — direct
// Does String.init(decoding:as:) accept Span?
// Span is not Sequence/Collection, so this likely fails.
//func v2_directDecoding() {
//    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
//        String(decoding: span, as: UTF8.self)
//    }
//    assert(result == "Hello")
//    print("V2 CONFIRMED: String(decoding: span, as: UTF8.self)")
//}

// MARK: - V3: UTF8Span path
// UTF8Span.init(validating: Span<UInt8>) exists in stdlib
// Then String(utf8Span) or String(copying: utf8Span)?
func v3_utf8Span() {
    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
        let utf8 = try! UTF8Span(validating: span)
        return String(copying: utf8)
    }
    assert(result == "Hello")
    print("V3 CONFIRMED: UTF8Span(validating:) → String(copying:)")
}

// MARK: - V4: String.utf8.span backwards — get span FROM string
// String.UTF8View has .span property. Does this help going the other way?
// Not directly, but tests the round-trip.
func v4_stringToSpanRoundTrip() {
    let s = "Hello"
    let span = s.utf8.span
    assert(span.count == 5)
    assert(span[0] == 72)
    print("V4 CONFIRMED: String.utf8.span round-trip")
}

// MARK: - V5: String(bytes: span, encoding: .utf8) pattern
// Does String have a bytes-based init that takes Span?
//func v5_bytesInit() {
//    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
//        String(bytes: span, encoding: .utf8)
//    }
//    print("V5: \(result ?? "nil")")
//}

// MARK: - V6: Manual byte-by-byte construction
func v6_manualConstruction() {
    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
        var str = ""
        str.reserveCapacity(span.count)
        for i in 0..<span.count {
            str.append(Character(Unicode.Scalar(span[i])))
        }
        return str
    }
    assert(result == "Hello")
    print("V6 CONFIRMED: Manual byte-by-byte (works but verbose)")
}

// MARK: - V7: String(unsafeUninitializedCapacity:initializingUTF8With:)
func v7_unsafeInit() {
    let result = withTestSpan([72, 101, 108, 108, 111]) { span in
        String(unsafeUninitializedCapacity: span.count) { buffer in
            for i in 0..<span.count {
                buffer[i] = span[i]
            }
            return span.count
        }
    }
    assert(result == "Hello")
    print("V7 CONFIRMED: String(unsafeUninitializedCapacity:initializingUTF8With:)")
}

// ============================================================
// PART B: Span<T> → Array<T>
// ============================================================

// MARK: - V8: Current pattern
func v8_withUnsafeBufferPointer() {
    let result = withTestSpan([1, 2, 3, 4, 5]) { span in
        span.withUnsafeBufferPointer { Array($0) }
    }
    assert(result == [1, 2, 3, 4, 5])
    print("V8 CONFIRMED: span.withUnsafeBufferPointer { Array($0) }")
}

// MARK: - V9: Array(span) — direct
// Does Array.init accept Span? Span is not Sequence.
//func v9_directArrayInit() {
//    let result = withTestSpan([1, 2, 3, 4, 5]) { span in
//        Array(span)
//    }
//    assert(result == [1, 2, 3, 4, 5])
//    print("V9 CONFIRMED: Array(span)")
//}

// MARK: - V10: Manual index-based construction
func v10_manualArray() {
    let result = withTestSpan([1, 2, 3, 4, 5]) { span in
        var arr = [UInt8]()
        arr.reserveCapacity(span.count)
        for i in 0..<span.count {
            arr.append(span[i])
        }
        return arr
    }
    assert(result == [1, 2, 3, 4, 5])
    print("V10 CONFIRMED: Manual index-based Array construction")
}

// MARK: - V11: Array(unsafeUninitializedCapacity:initializingWith:)
func v11_unsafeArrayInit() {
    let result: [UInt8] = withTestSpan([1, 2, 3, 4, 5]) { span in
        Array(unsafeUninitializedCapacity: span.count) { buffer, count in
            for i in 0..<span.count {
                buffer[i] = span[i]
            }
            count = span.count
        }
    }
    assert(result == [1, 2, 3, 4, 5])
    print("V11 CONFIRMED: Array(unsafeUninitializedCapacity:) from Span")
}

// ============================================================
// PART C: Uncomment and test the "maybe" variants
// ============================================================

// Uncomment each one individually to test if it compiles:

// V2 REFUTED: String(decoding: span, as: UTF8.self)
//   Error: initializer 'init(decoding:as:)' requires that 'Span<UInt8>' conform to 'Collection'

// V9 REFUTED: Array(span)
//   Error: initializer 'init(_:)' requires that 'Span<UInt8>' conform to 'Sequence'

// ============================================================
// RUN ALL
// ============================================================

print("=== Span Conversion Experiment ===\n")

v1_withUnsafeBufferPointer()
v3_utf8Span()
v4_stringToSpanRoundTrip()
v6_manualConstruction()
v7_unsafeInit()
v8_withUnsafeBufferPointer()
v10_manualArray()
v11_unsafeArrayInit()

print("\n=== Done ===")
