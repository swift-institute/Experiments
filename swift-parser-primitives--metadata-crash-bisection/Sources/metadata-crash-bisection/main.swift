// MARK: - Metadata Crash Bisection
// Purpose: Isolate the root cause of SIGSEGV in checkTransitiveCompleteness
//          when instantiating Parser.Always<Input.Slice<Buffer<UInt8>.Linear>, _>
//          from a cross-module conformance.
//
// Hypotheses:
//   V1: Minimal module (Protocol + Always only) still crashes → poison is in
//       Parser.Always: Parser.Protocol conformance record itself
//   V1-alt: Minimal module passes → poison is in other conformance records
//       (retroactive Array/String, conditional Printer, etc.)
//   V2: Removing ~Escapable from protocol fixes crash → ~Escapable requirement
//       descriptor is the malformed record
//   V3: Using [UInt8] as Input passes (control, known-good from Round 1)
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: PENDING
// Date: 2026-02-13

import MinimalParserModule
import Buffer_Linear_Primitives

// =============================================================================
// MARK: - V1: Minimal module with ByteInput (THE critical test)
// =============================================================================
// Hypothesis: Parser.Always<ByteInput, Int> crashes even with only 1 conformance
//             record (Parser.Always: Parser.Protocol) in the module.
// Result: PENDING

typealias ByteInput = Input.Slice<Buffer<UInt8>.Linear>

func makeByteInput(_ bytes: UInt8...) -> ByteInput {
    var buffer = Buffer<UInt8>.Linear()
    for byte in bytes {
        buffer.append(byte)
    }
    return Input.Slice(buffer)
}

print("V1: Parser.Always<ByteInput, Int> from minimal module...")
let v1 = Parser.Always<ByteInput, Int>(42)
print("  output = \(v1.output)")
print("  V1 PASSED")

// =============================================================================
// MARK: - V1b: ByteInput with Void (activates no conditional conformance)
// =============================================================================
// Hypothesis: Void output also crashes (not Printer-related since no Printer
//             conformance exists in minimal module)
// Result: PENDING

print("V1b: Parser.Always<ByteInput, Void> from minimal module...")
let v1b = Parser.Always<ByteInput, Void>(())
var input1b = makeByteInput(0xFF)
v1b.parse(&input1b)
print("  isEmpty = \(input1b.isEmpty)")
print("  V1b PASSED")

// =============================================================================
// MARK: - V2: Control — [UInt8] as Input (known-good)
// =============================================================================
// Hypothesis: [UInt8] as Input works (confirmed in Round 1)
// Result: PENDING

print("V2: Parser.Always<[UInt8], Int> (control)...")
let v2 = Parser.Always<[UInt8], Int>(99)
print("  output = \(v2.output)")
print("  V2 PASSED")

// =============================================================================
// MARK: - Results Summary
// =============================================================================
print("")
print("ALL PASSED")

// V1:  PENDING — minimal module, ByteInput, Int
// V1b: PENDING — minimal module, ByteInput, Void
// V2:  PENDING — control, [UInt8], Int
