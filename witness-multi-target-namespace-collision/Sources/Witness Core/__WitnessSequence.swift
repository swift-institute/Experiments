//
//  __WitnessSequence.swift
//  Witness Core target
//
//  Probes: hoisted Sequence + Literal combinators mirroring production
//  shape. Used to evaluate call-site ergonomics candidates.
//

public import Witness_Namespace

// MARK: - Sequence Namespace (constructor-class combinator)

public enum __WitnessSequence {}

extension Witness {
    public typealias Sequence = __WitnessSequence
}

extension Witness.Sequence {
    public struct Two<P0: Witness.`Protocol`, P1: Witness.`Protocol`>
    where
        P0.Output == P1.Output,
        P0.Buffer == P1.Buffer
    {
        @usableFromInline internal let p0: P0
        @usableFromInline internal let p1: P1

        @inlinable
        public init(_ p0: P0, _ p1: P1) {
            self.p0 = p0
            self.p1 = p1
        }
    }
}

extension Witness.Sequence.Two: Witness.`Protocol` {
    public typealias Output = P0.Output
    public typealias Buffer = P0.Buffer
    public typealias Failure = P0.Failure  // simplified — production uses Either
    public typealias Body = Never

    @inlinable
    public func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
        try p0.serialize(output, into: &buffer)
        // Skip p1 serialize for brevity — failure-shape simplification
    }
}

// MARK: - Literal (type-reference-class combinator)

public struct __WitnessLiteral<B: RangeReplaceableCollection>
where B.Element == UInt8 {
    @usableFromInline let bytes: [UInt8]

    @inlinable
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }

    @inlinable
    public init(_ string: StaticString) {
        self.bytes = unsafe Swift.Array(
            string.utf8Start.withMemoryRebound(to: UInt8.self, capacity: string.utf8CodeUnitCount) {
                unsafe UnsafeBufferPointer(start: $0, count: string.utf8CodeUnitCount)
            }
        )
    }
}

extension Witness {
    public typealias Literal = __WitnessLiteral
}

extension Witness.Literal: Witness.`Protocol` {
    public typealias Output = Void
    public typealias Buffer = B
    public typealias Failure = Never
    public typealias Body = Never

    @inlinable
    public func serialize(_ output: Void, into buffer: inout B) {
        buffer.append(contentsOf: bytes)
    }
}

extension Witness.Literal: ExpressibleByStringLiteral {
    @inlinable
    public init(stringLiteral value: String) {
        self.bytes = Swift.Array(value.utf8)
    }
}
