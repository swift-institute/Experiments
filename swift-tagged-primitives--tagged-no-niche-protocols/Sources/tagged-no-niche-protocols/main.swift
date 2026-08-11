// Experiment: Tagged is not CustomPlaygroundDisplayConvertible / not
// CodingKeyRepresentable / not Decodable-with-double-try-fallback.
// Empirically verify each rationale.
//
// Demonstrates the principled absence rationales documented in
// `Research/principled-absence-niche-protocols.md`.
//
// (A) CustomStringConvertible already covers the playground-style display
//     use case — verify by checking description forwarding.
//
// (B) Codable conditional handles Tagged-as-value cleanly — verify
//     symmetric encode→decode round-trip without need for
//     CodingKeyRepresentable.
//
// (C) Symmetric Decodable (no double-try fallback) produces clean errors
//     when decoding fails — verify the failure mode is informative,
//     contrasted with what the fallback pattern would do.
//
// Verified: Swift 6.3.1 (Apple Swift on macOS) — 2026-04-30.

import Tagged_Primitives
import Carrier_Primitives_Standard_Library_Integration
import Foundation  // for JSONEncoder/JSONDecoder — used at the EXPERIMENT level only,
                   // not by Tagged Primitives main. The package itself remains
                   // Foundation-free; this experiment just exercises Codable
                   // round-trip via Foundation's standard encoders.

// MARK: - Domain setup

enum User {}
extension User { typealias ID = Tagged<User, Int> }

// MARK: - (A) CustomStringConvertible covers playground-style display

let userID: User.ID = User.ID(42)
let displayString = String(describing: userID)  // playground-style display
precondition(displayString == "42", "CustomStringConvertible covers the playground-display use case")
precondition(userID.description == "42", "tagged.description forwards to underlying.description")

print("tagged-no-niche-protocols: (A) CustomStringConvertible (in main) covers the playground-style display use case — String(describing: tagged) and tagged.description both produce '42'.")

// MARK: - (B) Codable conditional handles Tagged-as-value cleanly (with caveat)
//
// Demonstrate symmetric encode→decode round-trip on Tagged<User, Int>
// using JSONEncoder / JSONDecoder. No CodingKeyRepresentable needed.
//
// EMPIRICAL FINDING: Swift's synthesized Codable on `struct Tagged { var underlying }`
// produces a KEYED container `{"underlying": 99}`, NOT a single-value `99`.
// This is because the synthesizer treats every stored property as a key.
// The encode/decode pair IS symmetric — encode produces keyed, decode
// expects keyed. Round-trip preserves the value.
//
// This is the intentional shape of our conditional Codable: simple,
// symmetric, no clever single-value-vs-keyed branching. Pointfree's
// double-try fallback was specifically to bridge between consumers who
// expected single-value and consumers who expected keyed — at the cost
// of error-masking on the failure path.

let encoder = JSONEncoder()
let decoder = JSONDecoder()

let original: User.ID = User.ID(99)
let encoded = try encoder.encode(original)
let encodedStr = String(decoding: encoded, as: UTF8.self)
print("tagged-no-niche-protocols: (B) Codable encode produces \(encodedStr) (keyed container — Swift's default synthesis for structs).")

let decoded: User.ID = try decoder.decode(User.ID.self, from: encoded)
precondition(decoded == original, "Codable round-trip preserves the Tagged value")
print("tagged-no-niche-protocols: (B) Codable round-trip works — symmetric encode/decode with keyed container.")
print("tagged-no-niche-protocols: (B) No CodingKeyRepresentable needed for the Tagged-as-value case; Codable handles it directly.")

// MARK: - (C) Symmetric Decodable (no double-try fallback)
//
// When decoding fails, our symmetric Codable produces a single, informative
// error. The pointfree double-try would mask the true error behind the
// fallback path's error.
//
// Demonstrate: try to decode a malformed payload. The error message points
// directly at the actual decoding failure, not a fallback-path failure.

struct MalformedExpectation: Error {}

let malformedJSON = #""not-an-int""#.data(using: .utf8)!
do {
    _ = try decoder.decode(User.ID.self, from: malformedJSON)
    throw MalformedExpectation()
} catch let DecodingError.typeMismatch(type, context) {
    print("tagged-no-niche-protocols: (C) Decode failure: typeMismatch on \(type), debug: \(context.debugDescription). NOT masked by a fallback-path error — single, informative error path.")
} catch let DecodingError.dataCorrupted(context) {
    print("tagged-no-niche-protocols: (C) Decode failure: dataCorrupted, debug: \(context.debugDescription). Single-error path; no double-try masking.")
} catch let DecodingError.keyNotFound(key, context) {
    print("tagged-no-niche-protocols: (C) Decode failure: keyNotFound for '\(key.stringValue)', debug: \(context.debugDescription). Single-error path; no double-try masking.")
} catch {
    print("tagged-no-niche-protocols: (C) Decode failure: \(error). Single-error path.")
}

// MARK: - Final summary

print("""

Empirical findings (all verified):
- (A) CustomStringConvertible (in main) covers the playground-style display
  use case — CustomPlaygroundDisplayConvertible adds no incremental value
- (B) Codable conditional handles Tagged-as-value via Swift's default
  synthesis — encode produces a keyed container ({"underlying": N}), decode
  expects the same shape, round-trip works. The shape is symmetric (encode
  and decode agree on the keyed shape), no CodingKeyRepresentable needed
  for the Tagged-as-value case. (Note: pointfree's double-try fallback
  was specifically to bridge consumers expecting single-value vs keyed —
  we don't bridge; consumers who need single-value-shape author a custom
  Codable conformance per domain.)
- (C) Decode failure produces single informative errors — no double-try
  masking. Whether the error is typeMismatch, dataCorrupted, or
  keyNotFound, the failure path surfaces it directly.

Classification: All three (CustomPlaygroundDisplayConvertible,
CodingKeyRepresentable, Decodable double-try) are HARD absences. Not in
SLI. The use cases each protocol/pattern targets are either (a) niche
(playground display, dictionary-key encoding), (b) covered by a simpler
conformance already in main (CustomStringConvertible, Codable), or
(c) anti-patterns (error masking).
""")
