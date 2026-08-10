// MARK: - Canada — STUB
//
// The Canada root type for the canada.json fixture (2.1 MB GeoJSON
// FeatureCollection — large coordinate arrays). This is the
// "coordinate format" stress shape in Apple's bench.
//
// Porting checklist:
//
// 1. Copy type declarations (struct shape only) from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/CoordinateFormat.swift
//
//    Types: CoordinateFormat, FeatureCollection, Feature, Geometry,
//    Coordinates (and any helpers).
//
// 2. Copy CommonDecodable / CommonEncodable hand-written extensions from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/CoordinateFormatCommon.swift
//
// 3. Apply @JSONCodable / @CommonCodable / Codable annotations.
//
// 4. Hand-write JSON.Serializable conformance per type.
//
//    The hot path here is decoding large `[[Double]]` coordinate
//    arrays — verify the Double conformance (already in swift-json
//    via Double+JSON.swift) and the Array conformance work without
//    per-element allocation cliffs.
//
// 5. Replace this stub with a real `CanadaBench.run()` that reads
//    `Fixtures/canada.json`.

import Foundation

enum CanadaBench {
    static func run() {
        print("=== Canada ===")
        print("  STUB — port CoordinateFormat schema from")
        print("    /Users/coen/Developer/swiftlang/swift-foundation/")
        print("      Tests/NewCodableBenchmarks/CoordinateFormat.swift")
        print("      Tests/NewCodableBenchmarks/CoordinateFormatCommon.swift")
        print("")
    }
}
