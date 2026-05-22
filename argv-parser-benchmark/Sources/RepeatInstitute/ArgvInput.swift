//
//  ArgvInput.swift — institute Parser.Protocol variant
//
//  Bridge from `Swift.Array<String>` to `Parser.Input.Protocol`.
//  Verbatim copy from argv-parser-protocol-spike/Sources/ArgvParserSpike/ArgvInput.swift.
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
