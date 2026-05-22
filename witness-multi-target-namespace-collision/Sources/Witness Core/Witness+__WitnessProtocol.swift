//
//  Witness+__WitnessProtocol.swift
//  Witness Core target
//
//  Hoist + conformance — the suspected fault site. Analogue of the
//  swift-serializer-primitives extension layout that link-failed in
//  downstream consumers.
//

public import Witness_Namespace

extension Witness: __WitnessProtocol {
    // STEP 2: bind Body to Never — production conformance per [API-IMPL-020].
    public typealias Body = Never

    @inlinable
    public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
        try _serialize(output, &buffer)
    }
}

extension Witness {
    public typealias `Protocol` = __WitnessProtocol
}
