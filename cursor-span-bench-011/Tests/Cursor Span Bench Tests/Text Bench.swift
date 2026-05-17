import Testing
import Cursor_Span_Bench_Subject
import Lexer_Primitives
import Text_Primitives

nonisolated(unsafe) var textSink: UInt64 = 0

@inline(never)
func textBlackHole(_ value: UInt32) {
    textSink &+= UInt64(value)
}

@inline(never)
func readTextSink() -> UInt64 { textSink }

@Suite(.serialized)
struct TextBench {
    static let bufferSize: Int = 1 << 16
    static let iterations: Int = 200

    @Test
    func peekAdvance() {
        let source: [UInt8] = [UInt8](repeating: 0x20, count: Self.bufferSize)

        // Warmup
        for _ in 0..<10 {
            unsafe source.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var scanner = Lexer.Scanner(span)
                var sum: UInt32 = 0
                while let b = scanner.peek() {
                    sum &+= UInt32(b)
                    scanner.advance()
                }
                textBlackHole(sum)
            }
            unsafe source.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var cursor = Cursor.Span<Text>(span)
                var sum: UInt32 = 0
                while let b = cursor.peek() {
                    sum &+= UInt32(b)
                    cursor.advance()
                }
                textBlackHole(sum)
            }
        }

        let clock = ContinuousClock()

        let legacyTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe source.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var scanner = Lexer.Scanner(span)
                    var sum: UInt32 = 0
                    while let b = scanner.peek() {
                        sum &+= UInt32(b)
                        scanner.advance()
                    }
                    textBlackHole(sum)
                }
            }
        }

        let cursorTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe source.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var cursor = Cursor.Span<Text>(span)
                    var sum: UInt32 = 0
                    while let b = cursor.peek() {
                        sum &+= UInt32(b)
                        cursor.advance()
                    }
                    textBlackHole(sum)
                }
            }
        }

        reportText("Text peekAdvance", legacy: legacyTime, cursor: cursorTime)
        #expect(cursorTime <= legacyTime * 1.25,
                "Cursor.Span<Text> peek/advance loop regression beyond 25% budget")
        #expect(readTextSink() != 0)
    }

    @Test
    func consume() {
        let source: [UInt8] = [UInt8](repeating: 0x41, count: Self.bufferSize)

        // Warmup
        for _ in 0..<10 {
            unsafe source.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var scanner = Lexer.Scanner(span)
                var sum: UInt32 = 0
                while !scanner.isAtEnd {
                    sum &+= UInt32(scanner.consume())
                }
                textBlackHole(sum)
            }
            unsafe source.withUnsafeBufferPointer { buf in
                let span = unsafe Swift.Span(_unsafeElements: buf)
                var cursor = Cursor.Span<Text>(span)
                var sum: UInt32 = 0
                while !cursor.isAtEnd {
                    sum &+= UInt32(cursor.consume())
                }
                textBlackHole(sum)
            }
        }

        let clock = ContinuousClock()

        let legacyTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe source.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var scanner = Lexer.Scanner(span)
                    var sum: UInt32 = 0
                    while !scanner.isAtEnd {
                        sum &+= UInt32(scanner.consume())
                    }
                    textBlackHole(sum)
                }
            }
        }

        let cursorTime = clock.measure {
            for _ in 0..<Self.iterations {
                unsafe source.withUnsafeBufferPointer { buf in
                    let span = unsafe Swift.Span(_unsafeElements: buf)
                    var cursor = Cursor.Span<Text>(span)
                    var sum: UInt32 = 0
                    while !cursor.isAtEnd {
                        sum &+= UInt32(cursor.consume())
                    }
                    textBlackHole(sum)
                }
            }
        }

        reportText("Text consume", legacy: legacyTime, cursor: cursorTime)
        #expect(cursorTime <= legacyTime * 1.25,
                "Cursor.Span<Text> consume loop regression beyond 25% budget")
        #expect(readTextSink() != 0)
    }
}

@inline(never)
func reportText(_ name: String, legacy: Duration, cursor: Duration) {
    let ratio = Double(cursor.components.attoseconds) / Double(legacy.components.attoseconds)
    print("[BENCH-011] \(name): legacy=\(legacy) cursor=\(cursor) ratio=\(ratio)")
}
