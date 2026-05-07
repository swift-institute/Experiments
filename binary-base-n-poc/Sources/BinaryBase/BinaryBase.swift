// MARK: - Binary Base N Namespace POC
// Purpose: Validate `Binary.Base<let N: Int>` shape for a unified baseN encoding family
// Hypothesis: Value generics (SE-0452) on a witness-struct typed namespace permit
//             radix-driven algorithm dispatch + canonical alphabet instances per N
//             without runtime branching.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform:  macOS 26.0 (arm64)
//
// Status:    CONFIRMED (V1, V2, V3, V4, V5, V6, V7) + REFUTED (V2b)
// Result:    CONFIRMED — V7 (closed radix + Property<Tag, Base> from swift-property-primitives)
//            is the recommended production shape. V6 (closed-radix-set via backticked-digit
//            nested types) is the structural foundation; V7 builds the open-alphabet axis
//            on top via Property.callAsFunction + per-Tag method extensions, giving the
//            cleanest call sites (`Binary.Base.\`16\`.encode(bytes)` /
//            `Binary.Base.\`32\`.encode.hex(bytes)`) AND open extension across packages
//            via `extension Property where Tag == ..., Base == ...`. V1-V5 (value-generic
//            `Binary.Base<let N: Int>`) is mechanically viable but rejected — accepting
//            nonsense radix values like `Binary.Base<23456789>` is the wrong type-system
//            contract for a closed-radix family.
// Date:      2026-05-07
//
// Per-variant results:
//   V1 CONFIRMED   `Binary.Base<let N: Int>: Sendable, Hashable` declares + Sendable-conforms
//                  + Hashable-conforms cleanly under Swift 6 strict concurrency.
//   V2 CONFIRMED   `extension Binary.Base where N == 16 { ... }` dispatches per-radix; same
//                  method name (`encode`) coexists across radix-distinct extensions without
//                  ambiguity at consumer call sites (each `Binary.Base<16>`, `Binary.Base<64>`,
//                  `Binary.Base<62>` is a distinct nominal type at compile time).
//   V2b REFUTED    `extension Binary.Base where N == 16 || N == 32 || N == 64` fails at parse
//                  time on Swift 6.3.1 — `||` is not in the where-clause grammar. Production
//                  shared-API path: per-radix repetition (≤3 radixes) OR algorithm-witness
//                  parameter (recommended for ≥4 radixes; aligns with witness-over-enum
//                  preference). Runtime branching on N is rejected.
//   V3 CONFIRMED   Witness-struct shape works: `Binary.Base<N>` IS the witness, carrying
//                  `codeUnits: [UInt8]` and `pad: UInt8?`. Canonical alphabets — `.rfc4648`,
//                  `.rfc4648Url`, `.standard` — exposed as static instances under per-N
//                  conditional extensions. Open by construction (custom alphabets via
//                  `init(codeUnits:pad:)`).
//   V4 CONFIRMED   Cross-module consumption clean (per [EXP-017]). Library target `BinaryBase`
//                  + executable consumer target `binary-base-n-poc` import-link cleanly; runtime
//                  output matches expected encodings:
//                    Binary.Base<16>.rfc4648.encode([0xDE,0xAD,0xBE,0xEF])  →  "DEADBEEF"
//                    Binary.Base<64>.rfc4648.encode([0xDE,0xAD,0xBE,0xEF])  →  "3q2+7w=="
//                    Binary.Base<62>.standard.encode(UInt64(123456789))     →  "8M0kX"
//                    Binary.Base<16>.rfc4648.encode(span: Span([0x12,0x34])) → "1234"
//   V5 CONFIRMED   `borrowing [UInt8]` and `Span<UInt8>` byte sources both supported.
//                  Sub-finding: `for byte in <borrowing [UInt8]>` triggers consume-from-borrow
//                  errors — must use indexed iteration (`for i in 0..<bytes.count`).
//                  Pre-existing institute pattern per `feedback_span_indexed_over_unsafe_pointer.md`.
//   V6 CONFIRMED   Closed-radix-set shape via backticked-digit nested types
//                  (`Binary.Base.`16``, `Binary.Base.`62``) — see `Sources/BinaryBaseClosed/`
//                  target. Each radix is a distinct nominal struct under the non-generic
//                  `Binary.Base` enum namespace. Compile-time radix validation: only declared
//                  radixes can be referenced at consumer sites. Mirrors the precedent of
//                  `Windows.\`32\`` from [PLAT-ARCH-008k] and aligns with [API-NAME-001a]
//                  (multi-sibling-type namespace). Custom alphabets via `init(codeUnits:pad:)`
//                  preserve the open alphabet axis.
//
//                  V6 alone — closed radix, but alphabet still bundled in the type or
//                  expressed as a static instance, so the call site reads either as
//                  `Binary.Base.\`16\`.rfc4648.encode(bytes)` (witness) or as
//                  `Binary.Base.\`16\`.encode(bytes)` (method-on-type, single-alphabet only).
//                  V6 is the structural step; V7 layers cleaner call sites on top.
//   V7 CONFIRMED   Property.Typed-based call-site shape via swift-property-primitives —
//                  see `Sources/BinaryBaseProperty/` target. `Binary.Base.\`N\`.encode` is
//                  a static accessor returning `Property<Encode, Base.\`N\`>`; `Property`
//                  carries `callAsFunction(_:)` (the default-alphabet path) and named
//                  variant methods (`hex`, `url`, `gmp`, `crockford`, …) declared via
//                  `extension Property where Tag == ..., Base == ...`. Each spec package
//                  adds its alphabets as extensions on the same Tag — open extension is
//                  first-class. Call-site results validated against runtime preconditions:
//                    Binary.Base.\`16\`.encode([0xDE,0xAD,0xBE,0xEF])              → "DEADBEEF"
//                    Binary.Base.\`32\`.encode([0xDE,0xAD,0xBE,0xEF])              → "32W353Y="
//                    Binary.Base.\`32\`.encode.hex([0xDE,0xAD,0xBE,0xEF])          → "RQMRTRO="
//                    Binary.Base.\`32\`.encode.crockford([0xDE,0xAD,0xBE,0xEF])    → "VTPVXVR"
//                    Binary.Base.\`62\`.encode(UInt64(123456789))                  → "8M0kX"
//                    Binary.Base.\`62\`.encode.gmp(UInt64(123456789))              → "IWAuh"
//                  Aligns with [API-NAME-008]: multi-form operations (encode + hex + crockford
//                  + url + gmp) under one root (encode) MUST use Property.View nested accessors.
//                  Encode is the canonical Property.View case — the tag is closed at the
//                  package boundary; the methods on it are open across packages.
//
//                  Recommended production shape: V7. Architecture:
//                    swift-binary-base-primitives (L1):
//                       — declares `Binary.Base.\`16\`` … `\`85\`` (closed radix set)
//                       — declares `Encode` / `Decode` phantom tags + static accessors
//                       — depends on swift-property-primitives + swift-binary-primitives's
//                         `Binary Namespace` product
//                    swift-ietf/swift-rfc-4648 (L2):
//                       — extends Property where Tag == .Encode/.Decode with the RFC's
//                         alphabets (callAsFunction = default; .hex, .url = variants)
//                    swift-binary-base-primitives also ships non-spec alphabets
//                       (base62 standard/gmp, base58 standard, base85 z85) as Property
//                       extensions on the corresponding Encode/Decode tags
//                    Third-party packages (e.g., a hypothetical swift-crockford-base32)
//                       extend the same Encode/Decode tags freely.
//
// Variants tested in this file (library target) + Sources/binary-base-n-poc/main.swift (consumer):
//   V1: Binary.Base<let N: Int> value-generic struct declaration
//   V2: where-clause dispatch on `N == <Int>` for algorithm selection (bit-packed vs integer)
//   V3: Witness-struct shape — Binary.Base IS the witness (alphabet + pad bundled), open by
//       construction; canonical alphabets are static instances under conditional extensions.
//   V4: Cross-module consumption (executed by consumer target — see consumer main.swift).
//   V5: borrowing / Span<UInt8> byte-source compatibility on the encode method.

// MARK: - V1 — Namespace + value-generic struct

/// Local Binary namespace stand-in for the POC.
///
/// In the production package this is the existing `Binary` enum re-exported from
/// the `Binary Namespace` product of `swift-binary-primitives`. The POC declares
/// it locally so the experiment has zero ecosystem dependencies.
public enum Binary {}

extension Binary {
    /// A baseN encoding configuration parameterized by radix `N`.
    ///
    /// `Binary.Base<N>` IS the witness — it carries both the alphabet (`codeUnits`) and
    /// the optional padding byte. Canonical alphabets are exposed as static instances
    /// under per-`N` conditional extensions (V3); user-defined alphabets are constructed
    /// directly via `init(codeUnits:pad:)`.
    ///
    /// The radix `N` is a compile-time integer (SE-0452 value generics). Encode / decode
    /// algorithms are selected by `where N == <Int>` extensions (V2), with no runtime
    /// dispatch.
    public struct Base<let N: Int>: Sendable, Hashable {
        public let codeUnits: [UInt8]
        public let pad: UInt8?

        public init(codeUnits: [UInt8], pad: UInt8? = nil) {
            self.codeUnits = codeUnits
            self.pad = pad
        }
    }
}

// MARK: - V2 — Algorithm dispatch via where-clause on N

// Power-of-2 radixes: bit-packing encode/decode. Each radix gets its own extension so
// the where-clause is a single `N == <literal>` (the safest value-generic shape; `||`
// in where-clauses on value generics is tested in V2b below).

extension Binary.Base where N == 16 {
    /// Hex encoding (4 bits per digit). Big-endian within each byte: high nibble first.
    public func encode(_ bytes: borrowing [UInt8]) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        for i in 0..<bytes.count {
            let byte = bytes[i]
            out.append(codeUnits[Int(byte >> 4)])
            out.append(codeUnits[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }
}

extension Binary.Base where N == 64 {
    /// Base64 encoding (6 bits per digit). RFC 4648 §4 packing.
    public func encode(_ bytes: borrowing [UInt8]) -> String {
        var out: [UInt8] = []
        let n = bytes.count
        out.reserveCapacity(((n + 2) / 3) * 4)
        var i = 0
        while i + 3 <= n {
            let a = bytes[i], b = bytes[i + 1], c = bytes[i + 2]
            out.append(codeUnits[Int(a >> 2)])
            out.append(codeUnits[Int(((a & 0x03) << 4) | (b >> 4))])
            out.append(codeUnits[Int(((b & 0x0F) << 2) | (c >> 6))])
            out.append(codeUnits[Int(c & 0x3F)])
            i += 3
        }
        // Tail: 1 or 2 leftover bytes.
        let leftover = n - i
        if leftover == 1 {
            let a = bytes[i]
            out.append(codeUnits[Int(a >> 2)])
            out.append(codeUnits[Int((a & 0x03) << 4)])
            if let p = pad { out.append(p); out.append(p) }
        } else if leftover == 2 {
            let a = bytes[i], b = bytes[i + 1]
            out.append(codeUnits[Int(a >> 2)])
            out.append(codeUnits[Int(((a & 0x03) << 4) | (b >> 4))])
            out.append(codeUnits[Int((b & 0x0F) << 2)])
            if let p = pad { out.append(p) }
        }
        return String(decoding: out, as: UTF8.self)
    }
}

// Non-power-of-2 radix: integer-based encode (variable-length output, no bit-packing).
// Demonstrates the second algorithm class — same `Binary.Base<N>` host, different math.

extension Binary.Base where N == 62 {
    /// Base62 encoding via repeated division (UInt64 fixed-width input).
    /// Production encoding handles arbitrary-length byte arrays via leading-zero
    /// preservation; the POC uses the integer form to keep the algorithm minimal.
    public func encode(_ value: UInt64) -> String {
        if value == 0 { return String(decoding: [codeUnits[0]], as: UTF8.self) }
        var v = value
        var out: [UInt8] = []
        while v > 0 {
            out.append(codeUnits[Int(v % 62)])
            v /= 62
        }
        out.reverse()
        return String(decoding: out, as: UTF8.self)
    }
}

// MARK: - V2b — Multi-radix where-clause shape probe (REFUTED)
//
// Tested: `extension Binary.Base where N == 16 || N == 32 || N == 64`
// Result: REFUTED at parse time on Swift 6.3.1 — `||` is not part of the
//   where-clause grammar (`error: expected '{' in extension` at the `||`).
//   Even inside a `#if`-gated block, the grammar must parse, so this isn't
//   conditional-compilation-rescuable. The compiler grammar for where-clause
//   requirements is a comma-separated list of equalities/conformances, all of
//   which conjoin (AND); there is no disjunction operator.
//
// Implication for the production design: shared API across multiple radixes
//   must use one of:
//     (a) repeat the extension per radix (verbose but mechanically simple);
//     (b) introduce a marker protocol or witness selecting the algorithm
//         family (a Power-of-Two witness instance vs an Integer witness
//         instance), with the algorithm bodies reading from the witness;
//     (c) drop into a single unconstrained extension and runtime-branch on N.
//   (b) aligns with the institute's witness-over-enum preference and is the
//       recommended production path; (a) is acceptable for a thin family
//       (≤3 radixes); (c) is rejected — runtime branching defeats the point
//       of a value-generic radix.

// MARK: - V3 — Canonical alphabet instances (witness pattern)

extension Binary.Base where N == 16 {
    /// RFC 4648 §8 — uppercase hex.
    public static let rfc4648: Binary.Base<16> = .init(
        codeUnits: Array("0123456789ABCDEF".utf8),
        pad: nil
    )
}

extension Binary.Base where N == 64 {
    /// RFC 4648 §4 — standard Base64.
    public static let rfc4648: Binary.Base<64> = .init(
        codeUnits: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8),
        pad: 0x3D  // "="
    )

    /// RFC 4648 §5 — URL-safe Base64. No padding.
    public static let rfc4648Url: Binary.Base<64> = .init(
        codeUnits: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".utf8),
        pad: nil
    )
}

extension Binary.Base where N == 62 {
    /// Standard base62 alphabet (digits, then upper, then lower).
    public static let standard: Binary.Base<62> = .init(
        codeUnits: Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8),
        pad: nil
    )
}

// MARK: - V5 — Span<UInt8> byte-source compatibility

extension Binary.Base where N == 16 {
    /// Span-based encode for ~Escapable byte sources. Demonstrates that the
    /// value-generic struct's methods can take Span<UInt8> without ownership
    /// gymnastics.
    public func encode(span: Span<UInt8>) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(span.count * 2)
        for i in 0..<span.count {
            let byte = span[i]
            out.append(codeUnits[Int(byte >> 4)])
            out.append(codeUnits[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }
}
