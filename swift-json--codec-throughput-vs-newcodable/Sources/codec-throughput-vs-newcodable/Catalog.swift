// MARK: - Catalog — STUB
//
// The Catalog root type for the citm_catalog.json fixture (1.6 MB,
// deeply nested event catalog with many small dictionaries).
//
// Porting checklist:
//
// 1. Copy type declarations from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/Catalog.swift
//
//    Types: Catalog, AreaName, AudienceSubCategoryName, BlockName,
//    Event, Performance, Price, SeatCategory, Area, SubTopicName,
//    TopicSubTopics, Venue, plus dictionary-keyed sub-types.
//
// 2. Copy CommonDecodable / CommonEncodable extensions from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/CatalogCommon.swift
//
// 3. Apply @JSONCodable / @CommonCodable / Codable annotations.
//
// 4. Hand-write JSON.Serializable conformance per type.
//
//    The interesting shape here is the heavy dictionary use —
//    string-keyed top-level dictionaries with thousands of small
//    entries. swift-json's JSON.object pairs-array vs Apple's
//    OrderedDictionary access pattern is the likely divergence
//    point.
//
// 5. Replace this stub with a real `CatalogBench.run()` that reads
//    `Fixtures/citm_catalog.json`.

import Foundation

enum CatalogBench {
    static func run() {
        print("=== Catalog ===")
        print("  STUB — port Catalog schema from")
        print("    /Users/coen/Developer/swiftlang/swift-foundation/")
        print("      Tests/NewCodableBenchmarks/Catalog.swift")
        print("      Tests/NewCodableBenchmarks/CatalogCommon.swift")
        print("")
    }
}
