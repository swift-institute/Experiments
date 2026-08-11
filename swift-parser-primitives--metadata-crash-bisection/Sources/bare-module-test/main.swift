// MARK: - Bare Module Test
// Purpose: Test with absolute minimum protocol — no ~Escapable, no Failure,
//          no @_exported imports, no upstream dependencies in the module
// Hypothesis: If crash persists, it's about ByteInput metadata in cross-module context
//             If crash disappears, it's about the upstream imports poisoning metadata
// Result: PENDING

import BareModule
import Input_Primitives
import Collection_Primitives
import Buffer_Linear_Primitives

typealias ByteInput = Input.Slice<Buffer<UInt8>.Linear>

func makeByteInput(_ bytes: UInt8...) -> ByteInput {
    var buffer = Buffer<UInt8>.Linear()
    for byte in bytes {
        buffer.append(byte)
    }
    return Input.Slice(buffer)
}

print("Bare V1: Parser.Always<ByteInput, Int>...")
let v1 = Parser.Always<ByteInput, Int>(42)
print("  output = \(v1.output)")
print("  PASSED")

print("Bare V2: Parser.Always<ByteInput, Void> with parse...")
let v2 = Parser.Always<ByteInput, Void>(())
var input = makeByteInput(0xFF)
v2.parse(&input)
print("  PASSED")

print("ALL PASSED — bare module works")
