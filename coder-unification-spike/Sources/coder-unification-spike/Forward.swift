//
//  Forward.swift
//  coder-unification-spike
//
//  The forward-APPEND combinator algebra: twins of the ~10 core L1 parser
//  combinators, each conforming to `Coder.Protocol` with
//  `Buffer == Input == Substring`.
//
//  The load-bearing difference vs the L1 `Parser.Printer` algebra: every
//  `serialize` here visits children in FORWARD (parse) order and each leaf
//  APPENDS, whereas every L1 `print` visits children in REVERSE order and
//  each leaf PREPENDS (e.g. Parser.Take.Two.swift:77 "Print in reverse
//  order to build input correctly"; Pair+Parser.Printer.swift:21-23;
//  Parser.Many.swift:127 `output.reversed()`;
//  Parser.Skip.First.swift:60 "Print in reverse order").
//
//  Both disciplines target the same law: the emitted text, read left to
//  right, is the parse order.
//
//  Backtracking (OneOf / Optionally): the L1 printer needs
//  `input.checkpoint` / `input.restore` on the INPUT type
//  (Parser.OneOf.Two.swift:71-76 — hence the `Input: Input.Protocol`
//  constraint). The append discipline needs only "truncate the buffer back
//  to its pre-branch length", expressible on any RangeReplaceableCollection
//  buffer (here via value-copy restore, identical semantics).
//

public import Coder_Primitives
public import Parser_Primitive
public import Serializer_Primitive

public enum Forward {}

// MARK: - Take (sequential conjunction)

extension Forward {
    /// Twin of `Parser.Take.Two` (+ its Printer conformance,
    /// Parser.Take.Two.swift:69-89). Serialize order is FORWARD: first
    /// child first.
    public struct Take2<
        C0: Coder.`Protocol`, C1: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C0.Input == Substring, C0.Buffer == Substring, C0.Failure == Leaf.Fault,
        C1.Input == Substring, C1.Buffer == Substring, C1.Failure == Leaf.Fault
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = (C0.Output, C1.Output)
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let c0: C0
        public let c1: C1

        public init(_ c0: C0, _ c1: C1) { self.c0 = c0; self.c1 = c1 }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> Output {
            let o0 = try c0.parse(&input)
            let o1 = try c1.parse(&input)
            return (o0, o1)
        }

        public func serialize(_ output: Output, into buffer: inout Substring) throws(Leaf.Fault) {
            // FORWARD order — the inversion under test.
            try c0.serialize(output.0, into: &buffer)
            try c1.serialize(output.1, into: &buffer)
        }
    }

    /// Three-element sequential conjunction (the Take.Sequence builder shape).
    public struct Take3<
        C0: Coder.`Protocol`, C1: Coder.`Protocol`, C2: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C0.Input == Substring, C0.Buffer == Substring, C0.Failure == Leaf.Fault,
        C1.Input == Substring, C1.Buffer == Substring, C1.Failure == Leaf.Fault,
        C2.Input == Substring, C2.Buffer == Substring, C2.Failure == Leaf.Fault
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = (C0.Output, C1.Output, C2.Output)
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let c0: C0
        public let c1: C1
        public let c2: C2

        public init(_ c0: C0, _ c1: C1, _ c2: C2) { self.c0 = c0; self.c1 = c1; self.c2 = c2 }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> Output {
            let o0 = try c0.parse(&input)
            let o1 = try c1.parse(&input)
            let o2 = try c2.parse(&input)
            return (o0, o1, o2)
        }

        public func serialize(_ output: Output, into buffer: inout Substring) throws(Leaf.Fault) {
            try c0.serialize(output.0, into: &buffer)
            try c1.serialize(output.1, into: &buffer)
            try c2.serialize(output.2, into: &buffer)
        }
    }
}

// MARK: - Skip

extension Forward {
    /// Twin of `Parser.Skip.First` (print at Parser.Skip.First.swift:59-71,
    /// reverse order). Skips the FIRST (Void) child, keeps the second.
    public struct SkipFirst<
        C0: Coder.`Protocol`, C1: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C0.Input == Substring, C0.Buffer == Substring, C0.Failure == Leaf.Fault, C0.Output == Void,
        C1.Input == Substring, C1.Buffer == Substring, C1.Failure == Leaf.Fault
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = C1.Output
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let c0: C0
        public let c1: C1

        public init(_ c0: C0, _ c1: C1) { self.c0 = c0; self.c1 = c1 }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> C1.Output {
            try c0.parse(&input)
            return try c1.parse(&input)
        }

        public func serialize(_ output: C1.Output, into buffer: inout Substring) throws(Leaf.Fault) {
            // FORWARD: skipped literal first, value second — matching parse order.
            try c0.serialize((), into: &buffer)
            try c1.serialize(output, into: &buffer)
        }
    }

    /// Twin of `Parser.Skip.Second` (print at Parser.Skip.Second.swift:61-73,
    /// reverse order). Keeps the first child, skips the SECOND (Void) child.
    public struct SkipSecond<
        C0: Coder.`Protocol`, C1: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C0.Input == Substring, C0.Buffer == Substring, C0.Failure == Leaf.Fault,
        C1.Input == Substring, C1.Buffer == Substring, C1.Failure == Leaf.Fault, C1.Output == Void
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = C0.Output
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let c0: C0
        public let c1: C1

        public init(_ c0: C0, _ c1: C1) { self.c0 = c0; self.c1 = c1 }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> C0.Output {
            let o0 = try c0.parse(&input)
            try c1.parse(&input)
            return o0
        }

        public func serialize(_ output: C0.Output, into buffer: inout Substring) throws(Leaf.Fault) {
            try c0.serialize(output, into: &buffer)
            try c1.serialize((), into: &buffer)
        }
    }
}

// MARK: - Optionally

extension Forward {
    /// Twin of `Parser.Optionally` (print at Parser.Optionally.swift:61-72).
    /// Absent value emits nothing. On child emission failure the buffer is
    /// restored to its pre-attempt state before swallowing (a strict
    /// improvement over the L1 print, which swallows a possibly-partial
    /// prepend — the WORKAROUND comment at Parser.Optionally.swift:63-68).
    public struct Optionally<C: Coder.`Protocol`>: Coder.`Protocol`
    where C.Input == Substring, C.Buffer == Substring, C.Failure == Leaf.Fault {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = C.Output?
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let wrapped: C

        public init(_ wrapped: C) { self.wrapped = wrapped }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> C.Output? {
            let checkpoint = input
            do throws(Leaf.Fault) {
                return try wrapped.parse(&input)
            } catch {
                input = checkpoint
                return nil
            }
        }

        public func serialize(_ output: C.Output?, into buffer: inout Substring) throws(Leaf.Fault) {
            guard let output else { return }
            let checkpoint = buffer
            do throws(Leaf.Fault) {
                try wrapped.serialize(output, into: &buffer)
            } catch {
                buffer = checkpoint
            }
        }
    }
}

// MARK: - OneOf

extension Forward {
    /// Twin of `Parser.OneOf.Two` (parse and print both checkpoint/restore,
    /// Parser.OneOf.Two.swift:47-83). The append-side "restore" is
    /// truncation back to the pre-branch buffer state — no `Input.Protocol`
    /// cursor machinery required.
    public struct OneOf2<
        C0: Coder.`Protocol`, C1: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C0.Input == Substring, C0.Buffer == Substring, C0.Failure == Leaf.Fault,
        C1.Input == Substring, C1.Buffer == Substring, C1.Failure == Leaf.Fault,
        C0.Output == C1.Output
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = C0.Output
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let c0: C0
        public let c1: C1

        public init(_ c0: C0, _ c1: C1) { self.c0 = c0; self.c1 = c1 }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> Output {
            let checkpoint = input
            do throws(Leaf.Fault) {
                return try c0.parse(&input)
            } catch {
                input = checkpoint
                do throws(Leaf.Fault) {
                    return try c1.parse(&input)
                } catch {
                    input = checkpoint
                    throw .noBranchMatched
                }
            }
        }

        public func serialize(_ output: Output, into buffer: inout Substring) throws(Leaf.Fault) {
            let checkpoint = buffer
            do throws(Leaf.Fault) {
                try c0.serialize(output, into: &buffer)
            } catch {
                buffer = checkpoint
                do throws(Leaf.Fault) {
                    try c1.serialize(output, into: &buffer)
                } catch {
                    buffer = checkpoint
                    throw .noBranchMatched
                }
            }
        }
    }
}

// MARK: - Many

extension Forward {
    /// Twin of `Parser.Many` (print at Parser.Many.swift:119-134, which
    /// iterates `output.reversed()`). Serialize iterates FORWARD.
    public struct Many<C: Coder.`Protocol`>: Coder.`Protocol`
    where C.Input == Substring, C.Buffer == Substring, C.Failure == Leaf.Fault {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = [C.Output]
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let element: C
        public let minimum: Int
        public let maximum: Int

        public init(_ element: C, minimum: Int = 0, maximum: Int = .max) {
            self.element = element
            self.minimum = minimum
            self.maximum = maximum
        }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> [C.Output] {
            var results: [C.Output] = []
            while results.count < maximum {
                let checkpoint = input
                do throws(Leaf.Fault) {
                    results.append(try element.parse(&input))
                } catch {
                    input = checkpoint
                    break
                }
            }
            if results.count < minimum {
                throw .countTooLow(expected: minimum, got: results.count)
            }
            return results
        }

        public func serialize(_ output: [C.Output], into buffer: inout Substring) throws(Leaf.Fault) {
            if output.count < minimum { throw .countTooLow(expected: minimum, got: output.count) }
            if maximum < .max, output.count > maximum {
                throw .countTooHigh(expected: maximum, got: output.count)
            }
            for item in output {  // FORWARD — vs Parser.Many.swift:127 `.reversed()`
                try element.serialize(item, into: &buffer)
            }
        }
    }

    /// Twin of `Parser.Many.Separated` (print at
    /// Parser.Many.Separated.swift:152-176: reversed elements, separator
    /// printed BEFORE each non-first element in reverse — which lands
    /// between successive elements). Serialize iterates FORWARD with the
    /// separator between successive elements: the naturally-ordered form.
    public struct ManySeparated<
        C: Coder.`Protocol`, S: Coder.`Protocol`
    >: Coder.`Protocol`
    where
        C.Input == Substring, C.Buffer == Substring, C.Failure == Leaf.Fault,
        S.Input == Substring, S.Buffer == Substring, S.Failure == Leaf.Fault, S.Output == Void
    {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = [C.Output]
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let element: C
        public let separator: S
        public let minimum: Int
        public let maximum: Int

        public init(_ element: C, separator: S, minimum: Int = 0, maximum: Int = .max) {
            self.element = element
            self.separator = separator
            self.minimum = minimum
            self.maximum = maximum
        }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> [C.Output] {
            var results: [C.Output] = []
            var checkpoint = input
            while results.count < maximum {
                do throws(Leaf.Fault) {
                    if !results.isEmpty { try separator.parse(&input) }
                    results.append(try element.parse(&input))
                    checkpoint = input
                } catch {
                    input = checkpoint
                    break
                }
            }
            if results.count < minimum {
                throw .countTooLow(expected: minimum, got: results.count)
            }
            return results
        }

        public func serialize(_ output: [C.Output], into buffer: inout Substring) throws(Leaf.Fault) {
            if output.count < minimum { throw .countTooLow(expected: minimum, got: output.count) }
            if maximum < .max, output.count > maximum {
                throw .countTooHigh(expected: maximum, got: output.count)
            }
            var isFirst = true
            for item in output {  // FORWARD
                if !isFirst { try separator.serialize((), into: &buffer) }
                try element.serialize(item, into: &buffer)
                isFirst = false
            }
        }
    }
}

// MARK: - Converted (the Conversion / Map seam)

extension Forward {
    /// Twin of `Parser.Converted` (print at Parser.Converted.swift:83-95:
    /// unapply, then upstream print). Identical shape under append —
    /// unapply, then upstream serialize; the conversion seam is
    /// order-agnostic.
    public struct Converted<C: Coder.`Protocol`, NewOutput>: Coder.`Protocol`
    where C.Input == Substring, C.Buffer == Substring, C.Failure == Leaf.Fault {
        public typealias Input = Substring
        public typealias Buffer = Substring
        public typealias Output = NewOutput
        public typealias Failure = Leaf.Fault
        public typealias Body = Never

        public let upstream: C
        public let apply: @Sendable (C.Output) -> NewOutput
        public let unapply: @Sendable (NewOutput) -> C.Output?

        public init(
            _ upstream: C,
            apply: @escaping @Sendable (C.Output) -> NewOutput,
            unapply: @escaping @Sendable (NewOutput) -> C.Output?
        ) {
            self.upstream = upstream
            self.apply = apply
            self.unapply = unapply
        }

        public var body: Never { return fatalError("leaf") }

        public func parse(_ input: inout Substring) throws(Leaf.Fault) -> NewOutput {
            apply(try upstream.parse(&input))
        }

        public func serialize(_ output: NewOutput, into buffer: inout Substring) throws(Leaf.Fault) {
            guard let upstreamOutput = unapply(output) else { throw .unapplyFailed }
            try upstream.serialize(upstreamOutput, into: &buffer)
        }
    }
}
