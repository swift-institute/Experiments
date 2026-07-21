//
//  Leaves.swift
//  coder-unification-spike
//
//  Leaf coders over `Substring` conforming to BOTH sides of the question:
//
//  - `Coder.Protocol` (Parser.Protocol & Serializer.Protocol) with
//    `Buffer == Input == Substring` — the forward-APPEND emission path
//    (`serialize(_:into:)` appends at the buffer's end).
//  - `Parser.Printer` — the L1 prepend emission path (`print(_:into:)`
//    inserts at `input.startIndex`, per the contract at
//    swift-parser-primitives Parser.Printer.swift:16-17 ("prepends"),
//    :60 ("prepends the printed representation"), :65, and the leaf
//    precedent Parser.String+Parser.swift:30
//    (`input.insert(contentsOf: self, at: input.startIndex)`)).
//
//  Because every leaf carries both emission disciplines over the same
//  parse, the SAME leaf drives the L1 prepend combinator algebra and the
//  spike's forward-append twin algebra, making the outputs byte-comparable.
//

public import Coder_Primitives
public import Parser_Primitives
public import Serializer_Primitives

public enum Leaf {
    /// Single shared failure vocabulary for the spike (the Either-nesting
    /// fidelity of L1 typed throws is out of scope here; the law under test
    /// is emission ORDER, not error typing).
    public enum Fault: Swift.Error, Equatable {
        case mismatch(expected: String, got: String)
        case endExpected
        case countTooLow(expected: Int, got: Int)
        case countTooHigh(expected: Int, got: Int)
        case noBranchMatched
        case unapplyFailed
    }
}

// MARK: - Literal

extension Leaf {
    /// Matches / emits a fixed text. `Output == Void` (the Skip fodder).
    public struct Literal: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = Void
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let text: String

        public init(_ text: String) { self.text = text }

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) {
            guard input.hasPrefix(text) else {
                throw .mismatch(expected: text, got: String(input.prefix(text.count)))
            }
            input.removeFirst(text.count)
        }

        /// L1 prepend contract: insert at the FRONT of the existing input.
        public func print(_ output: Void, into input: inout Substring) throws(Leaf.Fault) {
            input.insert(contentsOf: text, at: input.startIndex)
        }

        /// Forward-append contract: append at the END of the growing buffer.
        public func serialize(_ output: Void, into buffer: inout Substring) throws(Leaf.Fault) {
            buffer.append(contentsOf: text)
        }
    }
}

// MARK: - Integer

extension Leaf {
    /// Decimal integer (one or more ASCII digits, non-negative).
    public struct Integer: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = Int
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public init() {}

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> Int {
            let digits = input.prefix(while: { $0.isASCII && $0.isNumber })
            guard !digits.isEmpty, let value = Int(digits) else {
                throw .mismatch(expected: "digits", got: String(input.prefix(1)))
            }
            input.removeFirst(digits.count)
            return value
        }

        public func print(_ output: Int, into input: inout Substring) throws(Leaf.Fault) {
            guard output >= 0 else { throw .mismatch(expected: "non-negative", got: "\(output)") }
            input.insert(contentsOf: "\(output)", at: input.startIndex)
        }

        public func serialize(_ output: Int, into buffer: inout Substring) throws(Leaf.Fault) {
            guard output >= 0 else { throw .mismatch(expected: "non-negative", got: "\(output)") }
            buffer.append(contentsOf: "\(output)")
        }
    }
}

// MARK: - Word (the Prefix.While analog)

extension Leaf {
    /// One or more ASCII letters — the `Parser.Prefix.While` shape in leaf form.
    public struct Word: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = String
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public init() {}

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> String {
            let letters = input.prefix(while: { $0.isASCII && $0.isLetter })
            guard !letters.isEmpty else {
                throw .mismatch(expected: "letters", got: String(input.prefix(1)))
            }
            input.removeFirst(letters.count)
            return String(letters)
        }

        public func print(_ output: String, into input: inout Substring) throws(Leaf.Fault) {
            input.insert(contentsOf: output, at: input.startIndex)
        }

        public func serialize(_ output: String, into buffer: inout Substring) throws(Leaf.Fault) {
            buffer.append(contentsOf: output)
        }
    }
}

// MARK: - Rest

extension Leaf {
    /// Consumes everything remaining — the `Parser.Rest` shape in leaf form.
    public struct Rest: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = String
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public init() {}

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> String {
            let all = String(input)
            input.removeFirst(input.count)
            return all
        }

        public func print(_ output: String, into input: inout Substring) throws(Leaf.Fault) {
            input.insert(contentsOf: output, at: input.startIndex)
        }

        public func serialize(_ output: String, into buffer: inout Substring) throws(Leaf.Fault) {
            buffer.append(contentsOf: output)
        }
    }
}

// MARK: - End

extension Leaf {
    /// Matches end of input; emits nothing — the `Parser.End` shape
    /// (print conformance at Parser.End.swift:38-43 emits nothing).
    public struct End: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = Void
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public init() {}

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) {
            guard input.isEmpty else { throw .endExpected }
        }

        public func print(_ output: Void, into input: inout Substring) throws(Leaf.Fault) {}

        public func serialize(_ output: Void, into buffer: inout Substring) throws(Leaf.Fault) {}
    }
}

// MARK: - Always

extension Leaf {
    /// Produces a fixed value without consuming/emitting — the `Parser.Always`
    /// shape (print conformance at Parser.Always.swift:37-43 emits nothing).
    public struct Always<Value: Equatable & Sendable>: Coder.`Protocol`, Parser.Printer {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = Value
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let value: Value

        public init(_ value: Value) { self.value = value }

        public var body: Never { fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> Value { value }

        public func print(_ output: Value, into input: inout Substring) throws(Leaf.Fault) {
            guard output == value else { throw .unapplyFailed }
        }

        public func serialize(_ output: Value, into buffer: inout Substring) throws(Leaf.Fault) {
            guard output == value else { throw .unapplyFailed }
        }
    }
}
