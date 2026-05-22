//
//  ArgvInput.swift
//  argv-parser-protocol-spike
//
//  Bridge from `Swift.Array<String>` (the type produced by `CommandLine.arguments`)
//  to `Parser.Input.Protocol`.
//
//  Approach: wrap `[String]` in the institute's `Array<String>.Indexed<String>`
//  (from swift-array-primitives). That wrapper conforms to `Collection.Protocol`
//  with `Element == String`. Then `Input.Slice<Array<String>.Indexed<String>>`
//  provides `Input.Protocol` automatically (checkpoint, restore, advance).
//
//  NOTE: `Array_Primitives_Core.Array` *shadows* `Swift.Array` when imported
//  ecosystem-side. Bare `Array<String>` resolves to the institute's array, so
//  the bridge has to convert element-by-element from `Swift.Array<String>`.
//

public import Array_Dynamic_Primitives
public import Array_Primitives_Core
public import Input_Primitives

/// Argv input: an `Input.Protocol` cursor over a `[String]` (institute Array).
public typealias ArgvInput = Input.Slice<Array<String>.Indexed<String>>

extension Input.Slice where Base == Array<String>.Indexed<String> {
    /// Build an argv input from a plain `Swift.Array<String>`.
    public init(argv: Swift.Array<String>) {
        var institute: Array<String> = []
        for element in argv {
            institute.append(element)
        }
        self.init(Array<String>.Indexed<String>(institute))
    }
}
