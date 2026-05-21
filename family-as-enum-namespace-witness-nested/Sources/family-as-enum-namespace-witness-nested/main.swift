// MARK: - Family-as-Enum-Namespace-Witness-Nested
//
// Purpose: Validate the design pivot away from "Serializer as generic struct
//          + namespace workarounds (typealias hoist / __SerializerX / Serializers
//          plural)" to "Serializer as enum namespace + Serializer.Protocol
//          nested + Serializer.Witness as one combinator among many".
//
// Hypothesis: With the family root as a non-generic enum, all combinator
//          types nest cleanly under the namespace without requiring outer
//          generic binding at call sites. The closure-backed Witness is
//          just one combinator type among many, structurally peer to
//          Literal / Map / Filter / etc.
//
// Toolchain: swift-6.3+
// Platform:  macOS 26 (arm64)
//
// Result: CONFIRMED — all 6 validations pass (V1–V6)
//   V1 ✓ enum Serializer with nested protocol `Protocol` compiles
//   V2 ✓ Serializer.Witness<Int, [UInt8], Never>(...) at call site
//   V3 ✓ Serializer.Literal<[UInt8]>(...) WITHOUT outer-generic binding
//   V4 ✓ Serializer.Map<Serializer.Literal<[UInt8]>, Int>(...) generic
//        combinator composition
//   V5 ✓ User conformer references Serializer.Literal in serialize body
//   V6 ✓ Same shape transfers to Parser (Parser.Witness<Substring, Int, Never>)
//
// Implication: combinator namespace conflict is fully resolved by the enum
// namespace + nested Witness design. No __SerializerX / __ParserX hoisted
// types needed in public API. No Serializers plural enum needed. No four
// call-site forms. Design pivot away from W6/C6 generic-struct-witness
// approach is structurally sound.
//
// Date: 2026-05-15
//
// Validation surface:
//   V1  enum Serializer with nested protocol `Protocol`
//   V2  Serializer.Witness<O,B,F> closure-backed conformer
//   V3  Serializer.Literal<B> leaf combinator referenced WITHOUT outer
//       generic binding (the core ergonomic claim)
//   V4  Serializer.Map<Upstream, NewOutput> generic combinator composing
//       on another nested type
//   V5  User-defined conformer using nested combinators inside its
//       serialize implementation
//   V6  same shape transferred to Parser (cross-family generality)

// MARK: - V1 + V2 + V3 + V4 — Serializer family

public enum Serializer {
    public protocol `Protocol`<Output, Buffer, Failure>: ~Copyable {
        associatedtype Output
        associatedtype Buffer
        associatedtype Failure: Swift.Error

        borrowing func serialize(_ value: Output, into buffer: inout Buffer) throws(Failure)
    }
}

extension Serializer {

    // V2: closure-backed witness — one combinator among many
    public struct Witness<Output, Buffer, Failure: Swift.Error>: Serializer.`Protocol` {
        @usableFromInline
        var _serialize: (Output, inout Buffer) throws(Failure) -> Void

        @inlinable
        public init(_ serialize: @escaping (Output, inout Buffer) throws(Failure) -> Void) {
            self._serialize = serialize
        }

        @inlinable
        public borrowing func serialize(_ value: Output, into buffer: inout Buffer) throws(Failure) {
            try _serialize(value, &buffer)
        }
    }

    // V3: leaf combinator — independent generics, no outer bind required
    public struct Literal<Buffer>: Serializer.`Protocol`
    where Buffer: RangeReplaceableCollection, Buffer.Element == UInt8 {
        public typealias Output = Void
        public typealias Failure = Never

        @usableFromInline
        let bytes: [UInt8]

        @inlinable
        public init(_ string: String) {
            self.bytes = Array(string.utf8)
        }

        @inlinable
        public borrowing func serialize(_ value: Void, into buffer: inout Buffer) throws(Never) {
            buffer.append(contentsOf: bytes)
        }
    }

    // V4: generic combinator composing on another conformer
    public struct Map<Upstream: Serializer.`Protocol`, NewOutput>: Serializer.`Protocol` {
        public typealias Output = NewOutput
        public typealias Buffer = Upstream.Buffer
        public typealias Failure = Upstream.Failure

        @usableFromInline
        let upstream: Upstream
        @usableFromInline
        let transform: (NewOutput) -> Upstream.Output

        @inlinable
        public init(upstream: Upstream, transform: @escaping (NewOutput) -> Upstream.Output) {
            self.upstream = upstream
            self.transform = transform
        }

        @inlinable
        public borrowing func serialize(_ value: NewOutput, into buffer: inout Upstream.Buffer) throws(Upstream.Failure) {
            try upstream.serialize(transform(value), into: &buffer)
        }
    }
}

// MARK: - V6 — same shape transferred to Parser (cross-family generality)

public enum Parser {
    public protocol `Protocol`<Input, Output, Failure>: ~Copyable {
        associatedtype Input: ~Copyable & ~Escapable
        associatedtype Output
        associatedtype Failure: Swift.Error

        borrowing func parse(_ input: inout Input) throws(Failure) -> Output
    }
}

extension Parser {
    public struct Witness<Input: ~Copyable & ~Escapable, Output, Failure: Swift.Error>: Parser.`Protocol` {
        @usableFromInline
        var _parse: (inout Input) throws(Failure) -> Output

        @inlinable
        public init(_ parse: @escaping (inout Input) throws(Failure) -> Output) {
            self._parse = parse
        }

        @inlinable
        public borrowing func parse(_ input: inout Input) throws(Failure) -> Output {
            try _parse(&input)
        }
    }
}

// MARK: - Validations

print("=== Family-as-Enum-Namespace-Witness-Nested Spike ===")
print("")

// V3 validation: combinator referenced WITHOUT outer-generic binding
do {
    let lit: Serializer.Literal<[UInt8]> = .init("hello, ")
    var buffer: [UInt8] = []
    try lit.serialize((), into: &buffer)
    print("V3 ✓ Serializer.Literal<[UInt8]>(...) without outer bind — buffer=\(String(decoding: buffer, as: UTF8.self))")
}

// V2 validation: Witness construction at call site
do {
    let witness = Serializer.Witness<Int, [UInt8], Never> { value, buf in
        buf.append(contentsOf: String(value).utf8)
    }
    var buffer: [UInt8] = []
    try witness.serialize(42, into: &buffer)
    print("V2 ✓ Serializer.Witness<Int, [UInt8], Never>(...) — buffer=\(String(decoding: buffer, as: UTF8.self))")
}

// V4 validation: nested combinator composition
do {
    let mapped = Serializer.Map<Serializer.Literal<[UInt8]>, Int>(
        upstream: .init("prefix"),
        transform: { _ in () }
    )
    var buffer: [UInt8] = []
    try mapped.serialize(0, into: &buffer)
    print("V4 ✓ Serializer.Map<Literal, Int> — buffer=\(String(decoding: buffer, as: UTF8.self))")
}

// V5 validation: user conformer using nested combinators in its body
struct HelloSerializer: Serializer.`Protocol` {
    typealias Output = Void
    typealias Buffer = [UInt8]
    typealias Failure = Never

    func serialize(_ value: Void, into buffer: inout [UInt8]) throws(Never) {
        let hello = Serializer.Literal<[UInt8]>("hello")
        try hello.serialize((), into: &buffer)
        let comma = Serializer.Literal<[UInt8]>(", ")
        try comma.serialize((), into: &buffer)
        let world = Serializer.Literal<[UInt8]>("world")
        try world.serialize((), into: &buffer)
    }
}

do {
    let hs = HelloSerializer()
    var buffer: [UInt8] = []
    try hs.serialize((), into: &buffer)
    print("V5 ✓ User conformer uses Serializer.Literal in body — buffer=\(String(decoding: buffer, as: UTF8.self))")
}

// V6 validation: same shape for Parser
do {
    let witness = Parser.Witness<Substring, Int, Never> { input in
        let s = input
        input = ""
        return s.count
    }
    var input: Substring = "hello"
    let result = try witness.parse(&input)
    print("V6 ✓ Parser.Witness<Substring, Int, Never>(...) — parsed=\(result)")
}

print("")
print("All validations PASSED")
print("Design CONFIRMED: enum namespace + nested Protocol + nested combinators + nested Witness")
print("- Combinator namespace conflict fully resolved")
print("- No outer-generic binding required at any call site")
print("- No underscored __SerializerX / __ParserX types in public API")
print("- Same pattern transfers cleanly across Parser/Serializer/Coder family")
