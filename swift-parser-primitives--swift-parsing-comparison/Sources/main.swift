// MARK: - swift-parsing vs swift-parser-primitives Comparison
// Purpose: Compare throughput between pointfreeco/swift-parsing
//   and the actual parser types from swift-parser-primitives
// Hypothesis: The inout-slice pattern with typed throws has comparable or
//   better throughput than swift-parsing's Substring.UTF8View approach
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2025-05-31-a
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-02-15

import Parsing
import Parser_Primitives
import Parser_Primitives_Test_Support

// Avoid `Parser` name conflict (protocol from Parsing, enum from Parser_Primitives)
private typealias PP = Parser_Primitives.Parser

// ============================================================================
// MARK: - Benchmark Infrastructure
// ============================================================================

let iterations = 1_000_000

@inline(never)
func benchmark(_ label: String, _ body: () -> Void) {
    // Warmup
    for _ in 0..<1000 { body() }

    let start = ContinuousClock.now
    for _ in 0..<iterations { body() }
    let elapsed = ContinuousClock.now - start

    let nsPerOp = Double(elapsed.components.attoseconds) / 1e9 / Double(iterations)
    let rounded = (nsPerOp * 10).rounded() / 10
    print("\(label): \(rounded) ns/op")
}

// ============================================================================
// MARK: - Benchmark 1: Literal Byte Matching
// Parse the 3-byte sequence "GET"
// ============================================================================

print("--- Benchmark 1: Literal (3 bytes) ---")

let getBytes: [UInt8] = [0x47, 0x45, 0x54]
let getString = "GET"
let getTestBytes = TestBytes(getBytes)

// swift-parsing
do {
    let parser = getString.utf8
    benchmark("  swift-parsing") {
        var input = getString[...].utf8
        _ = try! parser.parse(&input)
    }
}

// parser-primitives
do {
    let parser = PP.Literal<ByteInput>(getBytes)
    benchmark("  parser-primitives") {
        var input = ByteInput(getTestBytes)
        try! parser.parse(&input)
    }
}

// ============================================================================
// MARK: - Benchmark 2: Prefix While Predicate
// Parse 20 digit bytes
// ============================================================================

print("\n--- Benchmark 2: Prefix While (20 digits) ---")

let digitBytes: [UInt8] = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30,
                           0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x30]
let digitString = "12345678901234567890"
let digitTestBytes = TestBytes(digitBytes)

// swift-parsing
do {
    let parser = Prefix<Substring.UTF8View>(while: { $0 >= 0x30 && $0 <= 0x39 })
    benchmark("  swift-parsing") {
        var input = digitString[...].utf8
        _ = try! parser.parse(&input)
    }
}

// parser-primitives
do {
    let parser = PP.Prefix.While<ByteInput> { $0 >= 0x30 && $0 <= 0x39 }
    benchmark("  parser-primitives") {
        var input = ByteInput(digitTestBytes)
        _ = try! parser.parse(&input)
    }
}

// ============================================================================
// MARK: - Benchmark 3: Many with Separator (10 elements)
// Parse "1,2,3,4,5,6,7,8,9,0"
// ============================================================================

print("\n--- Benchmark 3: Many Separated (10 elements) ---")

let csvBytes: [UInt8] = [0x31, 0x2C, 0x32, 0x2C, 0x33, 0x2C, 0x34, 0x2C, 0x35, 0x2C,
                         0x36, 0x2C, 0x37, 0x2C, 0x38, 0x2C, 0x39, 0x2C, 0x30]
let csvString = "1,2,3,4,5,6,7,8,9,0"
let csvTestBytes = TestBytes(csvBytes)

// swift-parsing
do {
    let parser = Many {
        Prefix<Substring.UTF8View>(1...) { $0 != UInt8(ascii: ",") }
    } separator: {
        ",".utf8
    }
    benchmark("  swift-parsing") {
        var input = csvString[...].utf8
        _ = try! parser.parse(&input)
    }
}

// parser-primitives
do {
    let parser = PP.Many.Separated<ByteInput, PP.Prefix.While<ByteInput>, PP.Literal<ByteInput>> {
        PP.Prefix.While<ByteInput>(minLength: 1) { $0 != UInt8(ascii: ",") }
    } separator: {
        PP.Literal<ByteInput>(",")
    }
    benchmark("  parser-primitives") {
        var input = ByteInput(csvTestBytes)
        _ = try! parser.parse(&input)
    }
}

// ============================================================================
// MARK: - Benchmark 4: OneOf Backtracking (3 alternatives, last matches)
// Input: "POST" — try "GET", "PUT", "POST"
// ============================================================================

print("\n--- Benchmark 4: OneOf 3-way Backtracking ---")

let postBytes: [UInt8] = [0x50, 0x4F, 0x53, 0x54]
let postString = "POST"
let postTestBytes = TestBytes(postBytes)

// swift-parsing
do {
    let parser = OneOf {
        "GET".utf8
        "PUT".utf8
        "POST".utf8
    }
    benchmark("  swift-parsing") {
        var input = postString[...].utf8
        _ = try! parser.parse(&input)
    }
}

// parser-primitives
do {
    let parser = PP.OneOf.Three(
        PP.Literal<ByteInput>("GET"),
        PP.Literal<ByteInput>("PUT"),
        PP.Literal<ByteInput>("POST")
    )
    benchmark("  parser-primitives") {
        var input = ByteInput(postTestBytes)
        _ = try! parser.parse(&input)
    }
}

// ============================================================================
// MARK: - Benchmark 5: Sequential Composition
// Parse "GET /index.html HTTP/1.1" — method, space, path, space, version
// ============================================================================

print("\n--- Benchmark 5: Sequential Composition ---")

let requestBytes: [UInt8] = [
    0x47, 0x45, 0x54, 0x20, 0x2F, 0x69, 0x6E, 0x64, 0x65, 0x78, 0x2E,
    0x68, 0x74, 0x6D, 0x6C, 0x20, 0x48, 0x54, 0x54, 0x50, 0x2F, 0x31,
    0x2E, 0x31
]
let requestString = "GET /index.html HTTP/1.1"
let requestTestBytes = TestBytes(requestBytes)

// swift-parsing
do {
    let parser = Parse {
        Prefix<Substring.UTF8View> { $0 != UInt8(ascii: " ") }
        " ".utf8
        Prefix<Substring.UTF8View> { $0 != UInt8(ascii: " ") }
        " ".utf8
        Prefix<Substring.UTF8View> { _ in true }
    }
    benchmark("  swift-parsing") {
        var input = requestString[...].utf8
        _ = try! parser.parse(&input)
    }
}

// parser-primitives
do {
    let notSpace = PP.Prefix.While<ByteInput> { $0 != UInt8(ascii: " ") }
    let space: PP.Literal<ByteInput> = " "
    let rest = PP.Rest<ByteInput>()

    benchmark("  parser-primitives") {
        var input = ByteInput(requestTestBytes)
        _ = try! notSpace.parse(&input)
        try! space.parse(&input)
        _ = try! notSpace.parse(&input)
        try! space.parse(&input)
        _ = rest.parse(&input)
    }
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("\nBenchmark complete. \(iterations) iterations per test.")
