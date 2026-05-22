//
//  __WitnessProtocol+Aliases.swift
//  Witness Core target
//
//  CANDIDATE 4 PROBE: protocol-extension typealiases on Witness.`Protocol`.
//  Hypothesis: `extension Witness.Protocol { typealias Literal = __WitnessLiteral }`
//  exposes `Self.Literal<...>` and `OtherType.Literal<...>` inside a
//  conformer's body, bypassing the outer-generic-inference failure.
//

// Cand 4a: Bare typealias on the protocol.
extension Witness.`Protocol` where Self: ~Copyable {
    public typealias Literal = __WitnessLiteral
    public typealias Sequence = __WitnessSequence
    // Note: Map / Filter / Fail / Always etc. would similarly hoist.
}

// Cand 1 probe — static factory methods on Witness.`Protocol`
extension Witness.`Protocol` where Self: ~Copyable, Buffer: RangeReplaceableCollection, Buffer.Element == UInt8 {
    public static func literal(_ string: StaticString) -> __WitnessLiteral<Buffer> {
        __WitnessLiteral<Buffer>(string)
    }
}
