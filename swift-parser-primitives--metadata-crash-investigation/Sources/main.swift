// Status: SUPERSEDED -- Parser.Always builds clean post-investigation; see swift-parser-primitives production code. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// Test: Parser.Always from Parser_Primitives after full clean
import Parser_Primitives

typealias ByteInput = Input.Slice<Buffer<UInt8>.Linear>

print("Creating Parser.Always<ByteInput, Int>...")
let parser = Parser.Always<ByteInput, Int>(42)
print("output = \(parser.output)")
print("PASSED")
