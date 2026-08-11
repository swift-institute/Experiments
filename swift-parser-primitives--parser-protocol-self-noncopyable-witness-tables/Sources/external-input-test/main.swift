// MARK: - V5: External-package Input + Self: ~Copyable witness-table probe
//
// Goal: Faithfully reproduce the original (2026-02-14, Swift 6.2.3)
//       Required Conditions for Crash:
//         (1) ~Copyable protocol constraint   — Π_α has Self: ~Copyable
//         (2) Protocol composition            — Map<Fail<…>>: Π_α
//         (3) External-package concrete type  — Input.Slice<Buffer<UInt8>.Linear>
//         (4) Cross-module instantiation      — this executableTarget ≠ ProtocolModule
//
// All four conditions present. If SIGSEGV is gated solely on the original-
// research pattern, this is where it fires. If V5 PASSES on the current
// toolchain, the witness-table SIGSEGV blocker named in the Tier-3 doc
// can be downgraded.

import ProtocolModule
import Input_Primitives
import Buffer_Linear_Primitives

typealias ByteInput = Input.Slice<Buffer<UInt8>.Linear>

enum BinaryError: Swift.Error {
    case eof
}

func runV5() {
    print("V5: External-package Input — Parser.Fail<ByteInput, Int, BinaryError>...")
    let leaf = Parser.Fail<ByteInput, Int, BinaryError>(.eof)
    var input1 = makeByteInput(0x41, 0x42)
    do {
        let _ = try leaf.parse(&input1)
        print("  V5 leaf UNREACHABLE — should throw")
    } catch {
        print("  V5 leaf PASSED — error: \(error)")
    }

    print("V5b: Composed Map<Fail<ByteInput, Int, BinaryError>, String>...")
    let mapped = Parser.Map<Parser.Fail<ByteInput, Int, BinaryError>, String>(
        upstream: Parser.Fail<ByteInput, Int, BinaryError>(.eof),
        transform: { (i: Int) in "got \(i)" }
    )
    var input2 = makeByteInput(0x43, 0x44)
    do {
        let _ = try mapped.parse(&input2)
        print("  V5b composed UNREACHABLE — should throw")
    } catch {
        print("  V5b composed PASSED — error: \(error)")
    }

    print("V5c: Triple-nested Map<Map<Fail<ByteInput, Int, BinaryError>, String>, Int>...")
    let inner = Parser.Map<Parser.Fail<ByteInput, Int, BinaryError>, String>(
        upstream: Parser.Fail<ByteInput, Int, BinaryError>(.eof),
        transform: { (i: Int) in "inner-\(i)" }
    )
    let outer = Parser.Map<
        Parser.Map<Parser.Fail<ByteInput, Int, BinaryError>, String>,
        Int
    >(
        upstream: inner,
        transform: { (s: String) in s.count }
    )
    var input3 = makeByteInput(0x45)
    do {
        let _ = try outer.parse(&input3)
        print("  V5c triple-nested UNREACHABLE — should throw")
    } catch {
        print("  V5c triple-nested PASSED — error: \(error)")
    }
}

func makeByteInput(_ bytes: UInt8...) -> ByteInput {
    var buffer = Buffer<UInt8>.Linear()
    for byte in bytes {
        buffer.append(byte)
    }
    return Input.Slice(buffer)
}

runV5()

print("")
print("ALL V5 VARIANTS COMPLETE — full crash conditions tested, no SIGSEGV under current toolchain.")
