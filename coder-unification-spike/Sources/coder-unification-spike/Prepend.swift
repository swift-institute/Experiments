//
//  Prepend.swift
//  coder-unification-spike
//
//  The PREPEND baselines the byte-equality tests compare against.
//
//  Where the real L1 combinator instantiates over `Substring`, the tests use
//  it directly (Parser.Take.Two, Parser.Skip.First/Second, Parser.Converted —
//  none constrain Input beyond `P0.Input == P1.Input`). But the L1
//  backtracking/repetition combinators constrain
//  `Input: Input_Primitives.Input.Protocol` (a cursor with
//  checkpoint/seek over FIXED storage — Parser.OneOf.Two.swift:19,
//  Parser.Optionally.swift:21, Parser.Many.swift:31), which `Substring`
//  does not satisfy, and which no growable, front-insertable printer target
//  satisfies either (Input.Protocol has no insertion API at all — see the
//  README finding). For those, this file hand-rolls the L1 print algorithm
//  LINE-FOR-LINE (reversed traversal + prepend + checkpoint/restore by
//  value copy), with the mirrored L1 source cited at each site.
//

public import Parser_Primitives

public enum Prepend {}

// MARK: - OneOf (mirrors Parser.OneOf.Two print, Parser.OneOf.Two.swift:69-83)

extension Prepend {
    public struct OneOf2<P0: Parser.Printer, P1: Parser.Printer>
    where
        P0.Input == Substring,
        P1.Input == Substring,
        P0.Output == P1.Output
    {
        public let p0: P0
        public let p1: P1

        public init(_ p0: P0, _ p1: P1) { self.p0 = p0; self.p1 = p1 }

        /// Mirrors L1: try first printer; on failure restore checkpoint, try second.
        public func print(_ output: P0.Output, into input: inout Substring) throws(Leaf.Fault) {
            let checkpoint = input
            do throws(P0.Failure) {
                try p0.print(output, into: &input)
            } catch {
                input = checkpoint
                do throws(P1.Failure) {
                    try p1.print(output, into: &input)
                } catch {
                    input = checkpoint
                    throw .noBranchMatched
                }
            }
        }
    }
}

// MARK: - Optionally (mirrors Parser.Optionally print, Parser.Optionally.swift:61-72)

extension Prepend {
    public struct Optionally<P: Parser.Printer>
    where P.Input == Substring {
        public let wrapped: P

        public init(_ wrapped: P) { self.wrapped = wrapped }

        /// Mirrors L1: absent prints nothing; present prints, swallowing errors.
        public func print(_ output: P.Output?, into input: inout Substring) {
            guard let output else { return }
            do throws(P.Failure) {
                try wrapped.print(output, into: &input)
            } catch {}
        }
    }
}

// MARK: - Many (mirrors Parser.Many print, Parser.Many.swift:119-134)

extension Prepend {
    public struct Many<P: Parser.Printer>
    where P.Input == Substring {
        public let element: P
        public let minimum: Int
        public let maximum: Int

        public init(_ element: P, minimum: Int = 0, maximum: Int = .max) {
            self.element = element
            self.minimum = minimum
            self.maximum = maximum
        }

        /// Mirrors L1: REVERSED element traversal, each element prepending.
        public func print(_ output: [P.Output], into input: inout Substring) throws(Leaf.Fault) {
            if output.count < minimum { throw .countTooLow(expected: minimum, got: output.count) }
            if maximum < .max, output.count > maximum {
                throw .countTooHigh(expected: maximum, got: output.count)
            }
            for item in output.reversed() {
                do throws(P.Failure) {
                    try element.print(item, into: &input)
                } catch {
                    break
                }
            }
        }
    }
}

// MARK: - Many.Separated (mirrors Parser.Many.Separated print, Parser.Many.Separated.swift:152-176)

extension Prepend {
    public struct ManySeparated<P: Parser.Printer, S: Parser.Printer>
    where
        P.Input == Substring,
        S.Input == Substring, S.Output == Void
    {
        public let element: P
        public let separator: S
        public let minimum: Int
        public let maximum: Int

        public init(_ element: P, separator: S, minimum: Int = 0, maximum: Int = .max) {
            self.element = element
            self.separator = separator
            self.minimum = minimum
            self.maximum = maximum
        }

        /// Mirrors L1: reversed traversal; separator printed before each
        /// non-first (in reverse) element, landing between successive elements.
        public func print(_ output: [P.Output], into input: inout Substring) throws(Leaf.Fault) {
            if output.count < minimum { throw .countTooLow(expected: minimum, got: output.count) }
            if maximum < .max, output.count > maximum {
                throw .countTooHigh(expected: maximum, got: output.count)
            }
            var isFirst = true
            for item in output.reversed() {
                if !isFirst {
                    do throws(S.Failure) {
                        try separator.print((), into: &input)
                    } catch {
                        break
                    }
                }
                do throws(P.Failure) {
                    try element.print(item, into: &input)
                } catch {
                    break
                }
                isFirst = false
            }
        }
    }
}
