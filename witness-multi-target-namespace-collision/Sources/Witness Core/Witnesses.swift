//
//  Witnesses.swift
//  Witness Core target
//
//  CANDIDATE 5 PROBE: non-generic peer enum hosting the same typealiases.
//  The peer namespace is non-generic, so its typealiases can be used
//  without binding any outer generics.
//
//  Naming convention: the pluralized peer is preferred over a non-noun-form
//  factory namespace because Swift-Institute convention prefers nouns.
//

public enum Witnesses {
    public typealias Literal = __WitnessLiteral
    public typealias Sequence = __WitnessSequence
    // Map, Filter, etc. would similarly hoist here.
}
