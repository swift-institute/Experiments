//
//  __WitnessProtocol.swift
//  Witness Core target
//
//  Hoisted protocol declaration. Analogue of __SerializerProtocol.
//

public protocol __WitnessProtocol<Output, Buffer, Failure>: ~Copyable {
    associatedtype Output
    associatedtype Buffer
    associatedtype Failure: Swift.Error

    // STEP 2: Body associatedtype with ~Copyable suppression (production-shape).
    associatedtype Body: ~Copyable

    // STEP 4: production has @Witness.Builder<Buffer> attribute on body
    @Witness.Builder<Buffer>
    var body: Body { borrowing get }

    borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure)
}

// STEP 2: Default body: Never for leaf conformers — the extension cited in the
// production link error.
extension __WitnessProtocol where Self: ~Copyable, Body == Never {
    @inlinable
    public var body: Never {
        borrowing get {
            fatalError("\(Self.self) is a leaf witness")
        }
    }
}

// STEP 3: Default serialize that delegates to body, mirroring production.
extension __WitnessProtocol
where
    Self: ~Copyable,
    Body: __WitnessProtocol,
    Body.Output == Output,
    Body.Buffer == Buffer,
    Body.Failure == Failure
{
    @inlinable
    public borrowing func serialize(_ output: Output, into buffer: inout Buffer) throws(Failure) {
        try body.serialize(output, into: &buffer)
    }
}
