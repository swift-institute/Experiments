//
//  main.swift
//  Consumer target
//
//  Declares a conformer to Witness.Protocol via the typealias path.
//  Mirrors what Version.Semantic.Serializer / ASCII.Decimal.Serializer do
//  in the failing downstream packages.
//

public import Witness_Core

// MARK: - Direct conformer to Witness.Protocol (the typealias path)
//
// Mirroring Version.Semantic.Serializer shape precisely:
// - Generic on Buffer (parameterized conformer, not concrete Buffer)
// - Conforms via Witness.`Protocol` (typealias path)
// - No explicit `Body` typealias (relies on default)

struct CalendarVersionSerializer<Buffer: RangeReplaceableCollection>: Witness.`Protocol`
where Buffer.Element == UInt8 {
    typealias Output = Int
    typealias Failure = Never

    init() {}

    func serialize(_ output: Int, into buffer: inout Buffer) {
        buffer.append(contentsOf: "\(output)".utf8)
    }
}

var buf: [UInt8] = []
CalendarVersionSerializer<[UInt8]>().serialize(42, into: &buf)
print("Consumer: serialized \(String(decoding: buf, as: UTF8.self))")
