//
//  Witness.swift
//  Witness Namespace target
//
//  Analogue of swift-serializer-primitives' Serializer struct.
//  Generic struct intended as the canonical witness type. Conformance to
//  the hoisted protocol is added in Witness Core via extension.
//

public struct Witness<Output, Buffer, Failure: Swift.Error> {
    public var _serialize: (Output, inout Buffer) throws(Failure) -> Void

    @inlinable
    public init(serialize: @escaping (Output, inout Buffer) throws(Failure) -> Void) {
        self._serialize = serialize
    }
}
