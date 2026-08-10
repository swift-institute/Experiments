// MARK: - Twitter — STUB
//
// The Twitter root type for the twitter.json fixture (617 KB,
// Twitter search API response shape).
//
// Porting checklist:
//
// 1. Copy Apple's type declarations (struct shape only; do NOT copy
//    the `@JSONCodable` / `@CommonCodable` macro annotations
//    blindly — re-apply them to the local declarations) from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/Twitter.swift
//
//    Types needed (verbatim from Apple's file): Twitter, Status,
//    Metadata, User, UserMentions, Hashtag, URLEntity, MediaEntity,
//    StatusEntities, LongId, ShortId, IntString<T>, LanguageCode,
//    Field enums (for each struct), plus a few helper newtypes.
//
// 2. Copy the CommonDecodable / CommonEncodable extensions
//    (NOT @JSONCodable-synthesised; Apple hand-writes them) from:
//      /Users/coen/Developer/swiftlang/swift-foundation/
//        Tests/NewCodableBenchmarks/TwitterCommon.swift
//
// 3. Annotate the type decls with `@JSONCodable` and `@CommonCodable`
//    macros so the JSONDecodable / JSONEncodable paths are synthesised
//    (Apple does this in Twitter.swift; the CommonCodable side is in
//    TwitterCommon.swift via hand-written extensions).
//
// 4. Add `Codable` conformance for the Foundation baseline (Apple's
//    Twitter type derives `Codable` for the same purpose — check
//    Apple's Twitter.swift top).
//
// 5. Write a `JSON.Serializable` conformance for Twitter (and every
//    nested type). This is the institute side — hand-written since
//    swift-json has no macro yet. See `Person.swift` for the shape.
//
//    Hint: traverse `json.dictionary`, extract typed fields, recurse.
//    For arrays use `.array(...)` constructors.
//
// 6. Replace this stub with the ported types and a `TwitterBench.run()`
//    that reads `Fixtures/twitter.json`, then runs `decodeMatrix` /
//    `encodeMatrix` analogous to PersonBench.

import Foundation

enum TwitterBench {
    static func run() {
        print("=== Twitter ===")
        print("  STUB — port Twitter schema from")
        print("    /Users/coen/Developer/swiftlang/swift-foundation/")
        print("      Tests/NewCodableBenchmarks/Twitter.swift")
        print("      Tests/NewCodableBenchmarks/TwitterCommon.swift")
        print("  then add JSON.Serializable conformance and replace this stub.")
        print("")
    }
}
