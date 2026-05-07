// MARK: - Binary Base N POC — Cross-Module Consumer
// Purpose: Validate that the `BinaryBase` library's value-generic API is consumable
//          across a module boundary per [EXP-017].
//
// Toolchain: Apple Swift 6.3.1
// Platform:  macOS 26.0 (arm64)
//
// Status: PENDING
//
// Blog: BLOG-IDEA-083 "Closed by Nature: Why Binary.Base.`16` Beats Binary.Base<N>"
// Blog: BLOG-IDEA-084 "Property<Tag, Base> at Type Level: Static-Method Witness Dispatch"

import BinaryBase
import BinaryBaseClosed
import BinaryBaseProperty

// MARK: - V4 — Cross-module access to Binary.Base<N>

let hexBytes: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]
let hex16 = BinaryBase.Binary.Base<16>.rfc4648.encode(hexBytes)
print("hex16 of [0xDE 0xAD 0xBE 0xEF]:", hex16)
precondition(hex16 == "DEADBEEF", "V4: cross-module BinaryBase.Binary.Base<16> dispatch failed")

let b64 = BinaryBase.Binary.Base<64>.rfc4648.encode(hexBytes)
print("b64 of [0xDE 0xAD 0xBE 0xEF]:", b64)
precondition(b64 == "3q2+7w==", "V4: cross-module BinaryBase.Binary.Base<64> dispatch failed")

let b62 = BinaryBase.Binary.Base<62>.standard.encode(UInt64(123456789))
print("b62 of UInt64(123456789):", b62)
precondition(b62 == "8M0kX", "V4: cross-module BinaryBase.Binary.Base<62> dispatch failed (expected 8M0kX, got \(b62))")

// MARK: - V4 — N-discrimination — same-N values share a type, different-N values do not

let h1: BinaryBase.Binary.Base<16> = .rfc4648
let _: BinaryBase.Binary.Base<16> = h1  // same N — compiles
// let _: Binary.Base<32> = h1  // would fail — different N value-generic instantiations are distinct types

// MARK: - V5 — Span<UInt8> consumer-side use

let bytes: [UInt8] = [0x12, 0x34]
let hex16FromSpan = bytes.withUnsafeBufferPointer { buf -> String in
    let span = Span<UInt8>(_unsafeElements: buf)
    return BinaryBase.Binary.Base<16>.rfc4648.encode(span: span)
}
print("hex16 of [0x12 0x34] via Span:", hex16FromSpan)
precondition(hex16FromSpan == "1234", "V5: Span<UInt8> encode failed")

// MARK: - V6 — Closed-radix-set shape via backticked-digit nested types
//
// Both `BinaryBase` (V1-V5) and `BinaryBaseClosed` (V6) declare the `Binary`
// top-level namespace. The consumer module-qualifies the V6 references via
// `BinaryBaseClosed.Binary.Base.\`16\`` to disambiguate. In a production
// package only one shape would exist; the module-qualifier is an experiment
// artifact, not part of the proposed API.

let v6_hex = BinaryBaseClosed.Binary.Base.`16`.rfc4648.encode(hexBytes)
print("V6 hex via Binary.Base.`16`:", v6_hex)
precondition(v6_hex == "DEADBEEF", "V6: Binary.Base.`16` dispatch failed")

let v6_b62 = BinaryBaseClosed.Binary.Base.`62`.standard.encode(UInt64(123456789))
print("V6 b62 via Binary.Base.`62`:", v6_b62)
precondition(v6_b62 == "8M0kX", "V6: Binary.Base.`62` dispatch failed")

// V6 — Custom alphabet via init (the OPEN axis: alphabets are user-extensible)
let customB62 = BinaryBaseClosed.Binary.Base.`62`(
    codeUnits: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".utf8),
    pad: nil
)
let v6_custom = customB62.encode(UInt64(123456789))
print("V6 b62 with GMP-style alphabet:", v6_custom)
precondition(!v6_custom.isEmpty, "V6: custom alphabet failed")

// V6 — Closed radix set: `Binary.Base.\`23456789\`` would not compile (no such type).
// The line below is intentionally commented; uncommenting it must produce a compile error.
// let _ = BinaryBaseClosed.Binary.Base.`23456789`.standard.encode(UInt64(0))

// MARK: - V7 — Property.Typed-based call-site shape via swift-property-primitives

let v7_hex = BinaryBaseProperty.Binary.Base.`16`.encode(hexBytes)
print("V7 hex via Binary.Base.`16`.encode (callAsFunction):", v7_hex)
precondition(v7_hex == "DEADBEEF", "V7: Binary.Base.`16`.encode failed")

// V7 base32 — default callAsFunction is RFC 4648 §6 standard
let v7_b32 = BinaryBaseProperty.Binary.Base.`32`.encode(hexBytes)
print("V7 b32 via Binary.Base.`32`.encode (default §6):", v7_b32)
precondition(v7_b32 == "32W353Y=", "V7: Binary.Base.`32`.encode default failed (got \(v7_b32))")

// V7 base32 hex — RFC 4648 §7
let v7_b32_hex = BinaryBaseProperty.Binary.Base.`32`.encode.hex(hexBytes)
print("V7 b32 via Binary.Base.`32`.encode.hex (§7):", v7_b32_hex)
precondition(v7_b32_hex == "RQMRTRO=", "V7: Binary.Base.`32`.encode.hex failed (got \(v7_b32_hex))")

// V7 base32 Crockford — third-party-style extension on the same Encode tag
let v7_b32_crockford = BinaryBaseProperty.Binary.Base.`32`.encode.crockford(hexBytes)
print("V7 b32 via Binary.Base.`32`.encode.crockford:", v7_b32_crockford)
precondition(!v7_b32_crockford.isEmpty, "V7: Binary.Base.`32`.encode.crockford failed")

// V7 base62 — default and gmp variant
let v7_b62 = BinaryBaseProperty.Binary.Base.`62`.encode(UInt64(123456789))
print("V7 b62 via Binary.Base.`62`.encode:", v7_b62)
precondition(v7_b62 == "8M0kX", "V7: Binary.Base.`62`.encode failed")

let v7_b62_gmp = BinaryBaseProperty.Binary.Base.`62`.encode.gmp(UInt64(123456789))
print("V7 b62 via Binary.Base.`62`.encode.gmp:", v7_b62_gmp)
precondition(!v7_b62_gmp.isEmpty, "V7: Binary.Base.`62`.encode.gmp failed")

print("All variants CONFIRMED")
