// MARK: - No-Escapable Variant
// Purpose: Test whether removing ~Escapable from Parser.Protocol fixes the crash
// Hypothesis: Crash disappears when associatedtype Input has no ~Escapable constraint
// Result: PENDING
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

import NoEscapableModule
import Buffer_Linear_Primitives

typealias ByteInput = Input.Slice<Buffer<UInt8>.Linear>

func makeByteInput(_ bytes: UInt8...) -> ByteInput {
    var buffer = Buffer<UInt8>.Linear()
    for byte in bytes {
        buffer.append(byte)
    }
    return Input.Slice(buffer)
}

print("No-Escapable V1: Parser.Always<ByteInput, Int>...")
let v1 = Parser.Always<ByteInput, Int>(42)
print("  output = \(v1.output)")
print("  PASSED")

print("No-Escapable V2: Parser.Always<ByteInput, Void>...")
let v2 = Parser.Always<ByteInput, Void>(())
var input = makeByteInput(0xFF)
v2.parse(&input)
print("  isEmpty = \(input.isEmpty)")
print("  PASSED")

print("ALL PASSED — ~Escapable removal fixes crash")
