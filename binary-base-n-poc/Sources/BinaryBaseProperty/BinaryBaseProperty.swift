// MARK: - V7 — Property.Typed-based call-site shape via swift-property-primitives
//
// Hypothesis: leveraging `Property<Tag, Base>` from swift-property-primitives gives
//   the cleanest call-site syntax achievable while honoring the institute's
//   open-on-alphabet / closed-on-radix constraint and aligning with the
//   `[API-NAME-008]` rule that "multi-form operations under one root MUST use
//   Property.View nested accessors."
//
// Call-site target shape:
//   Binary.Base.`16`.encode(bytes)         — single canonical alphabet, callAsFunction
//   Binary.Base.`32`.encode(bytes)         — multi-alphabet radix, callAsFunction picks default
//   Binary.Base.`32`.encode.hex(bytes)     — non-default RFC 4648 §7 variant
//   Binary.Base.`32`.encode.crockford(b)   — third-party variant added via where-Tag extension
//
// Mechanism:
//   - `Binary.Base.\`N\`` is an empty struct (marker, instantiable).
//   - Each radix declares phantom Encode/Decode tags + static `encode`/`decode`
//     accessors returning `Property<Tag, Self>`.
//   - swift-rfc-4648 (this file simulates it) declares `callAsFunction(_:)` and
//     variant methods (`hex`, `url`, `gmp`, …) on `Property` constrained by
//     `where Tag == ..., Base == ...`. Each spec package adds its own variants.
//   - Open extension on the alphabet axis is first-class — adding a Crockford
//     variant is a single `extension Property where ...` block in any package.

public import Property_Primitives_Core

public enum Binary {}

extension Binary {
    public enum Base {}
}

extension Binary.Base {
    public struct `16`: Sendable {
        public init() {}
        public enum Encode {}
        public enum Decode {}
    }

    public struct `32`: Sendable {
        public init() {}
        public enum Encode {}
        public enum Decode {}
    }

    public struct `62`: Sendable {
        public init() {}
        public enum Encode {}
        public enum Decode {}
    }
}

// MARK: - Static accessors returning Property<Tag, Self>

extension Binary.Base.`16` {
    public static var encode: Property<Encode, Self> { Property<Encode, Self>(.init()) }
    public static var decode: Property<Decode, Self> { Property<Decode, Self>(.init()) }
}

extension Binary.Base.`32` {
    public static var encode: Property<Encode, Self> { Property<Encode, Self>(.init()) }
    public static var decode: Property<Decode, Self> { Property<Decode, Self>(.init()) }
}

extension Binary.Base.`62` {
    public static var encode: Property<Encode, Self> { Property<Encode, Self>(.init()) }
    public static var decode: Property<Decode, Self> { Property<Decode, Self>(.init()) }
}

// MARK: - Alphabet-bearing methods on Property (would live in spec packages)
//
// These extensions belong in:
//   - swift-rfc-4648 for the RFC 4648 alphabets (base16, base32 + hex, base64 + url)
//   - swift-binary-base-primitives itself for non-RFC conventions (base62 standard, gmp)
//   - third-party packages for Crockford / z-base-32 / Bitcoin / Z85 / Ascii85 / etc.
// In the experiment they're all colocated for build-time validation of the pattern.

extension Property where Tag == Binary.Base.`16`.Encode, Base == Binary.Base.`16` {
    /// RFC 4648 §8 — uppercase hex (the only canonical base16 alphabet).
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String {
        let alphabet: [UInt8] = Array("0123456789ABCDEF".utf8)
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count * 2)
        for i in 0..<bytes.count {
            let byte = bytes[i]
            out.append(alphabet[Int(byte >> 4)])
            out.append(alphabet[Int(byte & 0x0F)])
        }
        return String(decoding: out, as: UTF8.self)
    }
}

extension Property where Tag == Binary.Base.`32`.Encode, Base == Binary.Base.`32` {
    /// RFC 4648 §6 — base32 standard alphabet (the default).
    public func callAsFunction(_ bytes: borrowing [UInt8]) -> String {
        encode(bytes, alphabet: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8), pad: 0x3D)
    }

    /// RFC 4648 §7 — base32 extended hex alphabet.
    public func hex(_ bytes: borrowing [UInt8]) -> String {
        encode(bytes, alphabet: Array("0123456789ABCDEFGHIJKLMNOPQRSTUV".utf8), pad: 0x3D)
    }

    /// Third-party extension demo — Crockford base32 (would live in a swift-crockford-base32
    /// package). Demonstrates that any package can extend the same Encode tag with new
    /// alphabets via `where Tag == ..., Base == ...` constraints.
    public func crockford(_ bytes: borrowing [UInt8]) -> String {
        encode(bytes, alphabet: Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ".utf8), pad: nil)
    }

    private func encode(
        _ bytes: borrowing [UInt8], alphabet: [UInt8], pad: UInt8?
    ) -> String {
        var out: [UInt8] = []
        var buffer: UInt64 = 0
        var bits: Int = 0
        for i in 0..<bytes.count {
            buffer = (buffer << 8) | UInt64(bytes[i])
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(alphabet[Int((buffer >> bits) & 0x1F)])
            }
        }
        if bits > 0 {
            out.append(alphabet[Int((buffer << (5 - bits)) & 0x1F)])
        }
        // Pad to multiple of 8 chars
        if let p = pad {
            while out.count % 8 != 0 { out.append(p) }
        }
        return String(decoding: out, as: UTF8.self)
    }
}

extension Property where Tag == Binary.Base.`62`.Encode, Base == Binary.Base.`62` {
    /// Standard base62 — digits, then upper, then lower.
    public func callAsFunction(_ value: UInt64) -> String {
        encode(value, alphabet: Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8))
    }

    /// GNU MP convention — upper before lower, digits last.
    public func gmp(_ value: UInt64) -> String {
        encode(value, alphabet: Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".utf8))
    }

    private func encode(_ value: UInt64, alphabet: [UInt8]) -> String {
        if value == 0 { return String(decoding: [alphabet[0]], as: UTF8.self) }
        var v = value
        var out: [UInt8] = []
        while v > 0 {
            out.append(alphabet[Int(v % 62)])
            v /= 62
        }
        out.reverse()
        return String(decoding: out, as: UTF8.self)
    }
}
