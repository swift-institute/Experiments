// MARK: - codec-throughput-vs-newcodable / main
//
// Purpose: Replicate Apple's NewCodable JSON benchmark suite against
// swift-json's JSON.Serializable, on identical payloads with Apple's
// exact 256-iter min-interval methodology.
//
// Hypothesis: swift-json's event-grain JSON.Serializable path is
// within 1.0x of Apple's NewCodable JSONParserDecoder on the
// twitter / canada / citm_catalog payloads.
//
// Toolchain: Apple Swift 6.3+ (TBD; record exact build at run time)
// Platform: macOS 26 (arm64)
//
// Status: PENDING — Person synthetic schema verifies harness only;
// Twitter / Canada / Catalog schemas await porting from
// /Users/coen/Developer/swiftlang/swift-foundation/Tests/NewCodableBenchmarks/
// (see the corresponding .swift stubs in this target).
//
// Result: PENDING
// Date: 2026-05-18

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

// MARK: - Driver

let args = CommandLine.arguments
let schema = args.count >= 2 ? args[1] : "person"

switch schema {
case "person":
    PersonBench.run()
case "twitter":
    TwitterBench.run()
case "canada":
    CanadaBench.run()
case "citm":
    CatalogBench.run()
case "all":
    PersonBench.run()
    TwitterBench.run()
    CanadaBench.run()
    CatalogBench.run()
default:
    FileHandle.standardError.write(Data("""
        unknown schema: \(schema)
        usage: codec-throughput-vs-newcodable <schema>
          schema: person | twitter | canada | citm | all

        """.utf8))
    exit(1)
}
