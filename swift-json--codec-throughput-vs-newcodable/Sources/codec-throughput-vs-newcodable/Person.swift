// MARK: - Person — synthetic skeleton-verification schema
//
// Verifies the harness end-to-end without requiring a JSON fixture
// file. Build a `[Person]` of size N in code, encode it once with
// Foundation, then run each decoder against the resulting bytes 256
// times.
//
// The schema is deliberately trivial: name (String) + age (Int).
// Its purpose is to make sure the harness compiles and all four
// codec paths actually decode/encode something — not to validate
// the perf claim on a real workload. Use Twitter / Canada / Catalog
// for that, once their schemas are ported.

import Foundation
import JSON
import NewCodable

@JSONCodable
@CommonCodable
struct Person: Codable, Equatable {
    let name: String
    let age: Int
}

extension Person: JSON.Serializable {
    static func serialize(_ value: Self) -> JSON {
        .object([
            ("name", .string(value.name)),
            ("age", .number(value.age)),
        ])
    }

    static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let name = String?(json.name) else {
            throw .missingKey("name")
        }
        guard let age = Int(json.age) else {
            throw .missingKey("age")
        }
        return Person(name: name, age: age)
    }
}

// MARK: - PersonBench

enum PersonBench {
    static let N = 10_000

    static func run() {
        let people: [Person] = (0..<N).map { i in
            Person(name: "person-\(i)", age: 18 + (i % 80))
        }

        // Build the payload once, with Foundation, so every decoder
        // reads identical bytes.
        let payload: Data = try! JSONEncoder().encode(people)

        print("=== Person [Person] (N=\(N), \(payload.count) bytes) ===")
        decodeMatrix(payload: payload)
        encodeMatrix(value: people)
        print("")
    }

    // MARK: Decode

    static func decodeMatrix(payload: Data) {
        // 1. Foundation JSONDecoder
        do {
            let decoder = JSONDecoder()
            let dur = try! Harness.measure {
                blackHole(try decoder.decode([Person].self, from: payload))
            }
            Harness.report(label: "decode  foundation", seconds: dur, bytes: payload.count)
        }

        // 2. NewJSONDecoder via JSONDecodable (parser-driven fast path)
        do {
            let decoder = NewJSONDecoder()
            func runJSON<D: JSONTopLevelDecoder & ~Copyable>(_ d: borrowing D) {
                let dur = try! Harness.measure {
                    blackHole(try d.decode([Person].self, from: payload))
                }
                Harness.report(label: "decode  newcodable-json", seconds: dur, bytes: payload.count)
            }
            runJSON(decoder)
        }

        // 3. NewJSONDecoder via CommonDecodable (format-agnostic path)
        do {
            let decoder = NewJSONDecoder()
            func runCommon<D: CommonTopLevelDecoder & ~Copyable>(_ d: borrowing D) {
                let dur = try! Harness.measure {
                    blackHole(try d.decode([Person].self, from: payload))
                }
                Harness.report(label: "decode  newcodable-common", seconds: dur, bytes: payload.count)
            }
            runCommon(decoder)
        }

        // 4. Institute tree-grain (JSON.parse + T.deserialize(_:))
        do {
            let dur = try! Harness.measure {
                let json = try JSON.parse([UInt8](payload))
                blackHole(try [Person].deserialize(json))
            }
            Harness.report(label: "decode  institute-tree", seconds: dur, bytes: payload.count)
        }

        // 5. Institute event-grain (T.deserialize(events:))
        //
        // TODO[event-grain]: override [Person].deserialize(events:) to
        // pull-decode the root array element-by-element via
        // JSON.Span.EventStream. The default implementation in the
        // JSON.Serializable extension delegates to tree-grain, which
        // gives identical numbers to path 4 above — not informative.
        // Real comparison requires the byte-to-target opt-in path.
        // See:
        //   swift-json/Sources/JSON/JSON.Serializable.swift:117 (default impl)
        //   swift-json/Sources/JSON/JSON.Span.EventStream.swift  (stream API)
        //   swift-json/Experiments/streaming-deserialize-a0-feasibility/ (prior art)
    }

    // MARK: Encode

    static func encodeMatrix(value: [Person]) {
        // 1. Foundation JSONEncoder
        do {
            let encoder = JSONEncoder()
            let bytes = (try! encoder.encode(value)).count
            let dur = try! Harness.measure {
                blackHole(try encoder.encode(value))
            }
            Harness.report(label: "encode  foundation", seconds: dur, bytes: bytes)
        }

        // 2. NewJSONEncoder via JSONEncodable
        do {
            let encoder = NewJSONEncoder()
            func runJSON<E: JSONTopLevelEncoder & ~Copyable>(_ e: borrowing E) -> Int {
                let bytes = (try! e.encode(value)).count
                let dur = try! Harness.measure {
                    blackHole(try e.encode(value))
                }
                Harness.report(label: "encode  newcodable-json", seconds: dur, bytes: bytes)
                return bytes
            }
            _ = runJSON(encoder)
        }

        // 3. NewJSONEncoder via CommonEncodable
        do {
            let encoder = NewJSONEncoder()
            func runCommon<E: CommonTopLevelEncoder & ~Copyable>(_ e: borrowing E) {
                let bytes = (try! e.encode(value)).count
                let dur = try! Harness.measure {
                    blackHole(try e.encode(value))
                }
                Harness.report(label: "encode  newcodable-common", seconds: dur, bytes: bytes)
            }
            runCommon(encoder)
        }

        // 4. Institute (JSON.Serializable.serialize + JSON.serialize(as: [UInt8]))
        do {
            let json = [Person].serialize(value)
            let bytes = json.serialize(as: [UInt8].self).count
            let dur = try! Harness.measure {
                let j = [Person].serialize(value)
                blackHole(j.serialize(as: [UInt8].self))
            }
            Harness.report(label: "encode  institute", seconds: dur, bytes: bytes)
        }
    }
}
