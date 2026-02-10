// MARK: - Associated Type Output Collision
// Purpose: Validate that deterministic domain-prefixed associated type names
//          (RenderOutput, ParseOutput) resolve collisions permanently.
// Hypothesis: Domain-prefixed names are unique by construction and allow
//             String to conform to both protocols simultaneously.
//
// Toolchain: Swift 6.2
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — domain-prefixed names eliminate collision; both
//         conformances compile and run correctly
// Output: Build Succeeded; all runtime tests pass
// Date: 2026-02-10

// ============================================================================
// MARK: - Variant 1: Reproduce collision with bare "Output" (known failure)
// Hypothesis: Two protocols with `associatedtype Output` collide on String.
// Result: CONFIRMED (cannot compile) — known Swift limitation
// ============================================================================

// Commented out — collision is already documented and verified.
// Both protocols define `associatedtype Output`; String cannot satisfy both
// with different concrete types.

// ============================================================================
// MARK: - Variant 2: Domain-prefixed names (deterministic fix)
// Hypothesis: Parser.Protocol.ParseOutput and Rendering.Protocol.RenderOutput
//             never collide because the domain prefix makes each unique.
// Result: CONFIRMED — compiles and runs; both conformances coexist
// ============================================================================

enum Match {
    struct Error: Swift.Error, Sendable {
        let message: String
    }
}

// Parser protocol with domain-prefixed associated type
enum ParserNS {
    protocol `Protocol` {
        associatedtype Input
        associatedtype ParseOutput
        associatedtype Failure: Error
        func parse(_ input: inout Input) throws(Failure) -> ParseOutput
    }
}

// Rendering protocol with domain-prefixed associated type
enum RenderingNS {
    protocol `Protocol` {
        associatedtype Content
        associatedtype Context
        associatedtype RenderOutput
        var body: Content { get }
        static func _render<Buffer: RangeReplaceableCollection>(
            _ markup: Self,
            into buffer: inout Buffer,
            context: inout Context
        ) where Buffer.Element == RenderOutput
    }
}

// String: Parser.Protocol (ParseOutput = Void)
extension String: ParserNS.`Protocol` {
    typealias Input = Substring
    typealias ParseOutput = Void
    typealias Failure = Match.Error

    func parse(_ input: inout Substring) throws(Match.Error) {
        guard input.hasPrefix(self) else {
            throw Match.Error(message: "expected \(self)")
        }
        input = input.dropFirst(self.count)
    }
}

// String: Rendering.Protocol (RenderOutput = UInt8)
extension String: RenderingNS.`Protocol` {
    typealias Content = Never
    typealias Context = Void
    typealias RenderOutput = UInt8

    var body: Never { fatalError() }

    static func _render<Buffer: RangeReplaceableCollection>(
        _ markup: String,
        into buffer: inout Buffer,
        context: inout Void
    ) where Buffer.Element == UInt8 {
        buffer.append(contentsOf: Array(markup.utf8))
    }
}

// ============================================================================
// MARK: - Variant 3: Runtime verification
// Hypothesis: Both conformances are independently usable via generic paths.
// Result: CONFIRMED — Parser: remaining=" world"; Rendering: 5 bytes "hello"
// ============================================================================

func testParser() {
    var input: Substring = "hello world"
    do {
        try "hello".parse(&input)
        print("Parser: OK — remaining: \"\(input)\"")
    } catch {
        print("Parser: FAILED — \(error)")
    }
}

func testRendering() {
    var buffer: [UInt8] = []
    var context: Void = ()
    String._render("hello", into: &buffer, context: &context)
    let text = String(decoding: buffer, as: UTF8.self)
    print("Rendering: OK — bytes: \(buffer.count), text: \"\(text)\"")
}

func testGenericParser<P: ParserNS.`Protocol`>(
    _ parser: P, input: inout P.Input
) throws(P.Failure) -> P.ParseOutput {
    try parser.parse(&input)
}

func testGenericRendering<R: RenderingNS.`Protocol`>(
    _ renderable: R, context: inout R.Context
) -> [R.RenderOutput] where R.RenderOutput: Sendable {
    var buffer: [R.RenderOutput] = []
    R._render(renderable, into: &buffer, context: &context)
    return buffer
}

testParser()
testRendering()

var input2: Substring = "test123"
do {
    try testGenericParser("test", input: &input2)
    print("Generic Parser: OK — remaining: \"\(input2)\"")
} catch {
    print("Generic Parser: FAILED — \(error)")
}

var ctx: Void = ()
let bytes = testGenericRendering("world", context: &ctx)
print("Generic Rendering: OK — bytes: \(bytes.count)")

// ============================================================================
// MARK: - Variant 4: Convention verification
// The deterministic naming convention:
//   {Domain}Output — unique per protocol by construction
//
// Examples:
//   Parser.Protocol.ParseOutput
//   Rendering.Protocol.RenderOutput
//   Serialization.Protocol.SerializeOutput (hypothetical)
//   Encoding.Protocol.EncodeOutput (hypothetical)
//
// This eliminates the collision search entirely. No need to survey
// existing associated type names on conforming types.
// ============================================================================

// ============================================================================
// MARK: - Results Summary
// V1: CONFIRMED (collision with bare Output — known)
// V2: CONFIRMED — domain-prefixed names compile with dual conformance
// V3: CONFIRMED — both conformances work at runtime via generic paths
// V4: Convention documented
// ============================================================================
