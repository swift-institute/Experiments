import Testing
import Cursor_Span_Bench_Subject
import Binary_Input_View_Primitives
import Byte_Primitives

/// Storage observable across the optimizer boundary, anchoring blackHole writes.
nonisolated(unsafe) var binarySink: UInt64 = 0

@inline(never)
func binaryBlackHole(_ value: UInt32) {
    binarySink &+= UInt64(value)
}

@inline(never)
func readBinarySink() -> UInt64 { binarySink }

@Suite(.serialized)
struct BinaryBench {
    static let bufferSize: Int = 1 << 16
    static let iterations: Int = 200

    @Test
    func consumeLoop() {
        let bytes: [UInt8] = [UInt8](repeating: 0xAB, count: Self.bufferSize)

        // Warmup
        for _ in 0..<10 {
            unsafe bytes.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var view = Binary.Bytes.Input.View(span)
                var sum: UInt32 = 0
                while !view.isEmpty {
                    sum &+= UInt32(view.removeFirst())
                }
                binaryBlackHole(sum)
            }
            unsafe bytes.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var cursor = Cursor.Span<Byte>(span)
                var sum: UInt32 = 0
                while !cursor.isAtEnd {
                    sum &+= UInt32(cursor.consume())
                }
                binaryBlackHole(sum)
            }
        }

        // Measured: legacy
        let clock = ContinuousClock()
        let legacyTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe bytes.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var view = Binary.Bytes.Input.View(span)
                    var sum: UInt32 = 0
                    while !view.isEmpty {
                        sum &+= UInt32(view.removeFirst())
                    }
                    binaryBlackHole(sum)
                }
            }
        }

        let cursorTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe bytes.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var cursor = Cursor.Span<Byte>(span)
                    var sum: UInt32 = 0
                    while !cursor.isAtEnd {
                        sum &+= UInt32(cursor.consume())
                    }
                    binaryBlackHole(sum)
                }
            }
        }

        report("Binary consumeLoop", legacy: legacyTime, cursor: cursorTime)
        #expect(cursorTime <= legacyTime * 1.25,
                "Cursor.Span<Byte> consume loop regression beyond 25% budget")
        #expect(readBinarySink() != 0)  // ensure the result is observable
    }

    @Test
    func peekAdvance() {
        let bytes: [UInt8] = [UInt8](repeating: 0x42, count: Self.bufferSize)

        // Warmup
        for _ in 0..<10 {
            unsafe bytes.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var view = Binary.Bytes.Input.View(span)
                var hits: UInt32 = 0
                while let b = view.first {
                    if b == 0x42 { hits &+= 1 }
                    view.removeFirst(1)
                }
                binaryBlackHole(hits)
            }
            unsafe bytes.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var cursor = Cursor.Span<Byte>(span)
                var hits: UInt32 = 0
                while let b = cursor.peek() {
                    if b == 0x42 { hits &+= 1 }
                    cursor.advance()
                }
                binaryBlackHole(hits)
            }
        }

        let clock = ContinuousClock()

        let legacyTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe bytes.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var view = Binary.Bytes.Input.View(span)
                    var hits: UInt32 = 0
                    while let b = view.first {
                        if b == 0x42 { hits &+= 1 }
                        view.removeFirst(1)
                    }
                    binaryBlackHole(hits)
                }
            }
        }

        let cursorTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe bytes.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var cursor = Cursor.Span<Byte>(span)
                    var hits: UInt32 = 0
                    while let b = cursor.peek() {
                        if b == 0x42 { hits &+= 1 }
                        cursor.advance()
                    }
                    binaryBlackHole(hits)
                }
            }
        }

        report("Binary peekAdvance", legacy: legacyTime, cursor: cursorTime)
        #expect(cursorTime <= legacyTime * 1.25,
                "Cursor.Span<Byte> peek/advance loop regression beyond 25% budget")
        #expect(readBinarySink() != 0)
    }
}

@inline(never)
func report(_ name: String, legacy: Duration, cursor: Duration) {
    let ratio = Double(cursor.components.attoseconds) / Double(legacy.components.attoseconds)
    print("[BENCH-011] \(name): legacy=\(legacy) cursor=\(cursor) ratio=\(ratio)")
}
