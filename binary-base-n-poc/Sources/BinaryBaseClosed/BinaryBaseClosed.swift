// MARK: - V6 — Closed-radix-set shape via backticked-digit nested types
//
// Hypothesis: `Binary.Base.`16`` / `Binary.Base.`62`` (each a distinct nominal
//   struct nested under Binary.Base) compiles cleanly under Swift 6.3.1, mirrors
//   the `Windows.\`32\`` pattern from [PLAT-ARCH-008k], and replaces the value-
//   generic `Binary.Base<let N: Int>` shape from V1-V5 in cases where the radix
//   set is genuinely closed.
//
// What this shape buys vs V1-V5:
//   • CLOSED radix set — `Binary.Base.\`23456789\`` is a compile error, not an
//     unreachable instantiation. The compiler enforces the curated radix family.
//   • No V2b grammar problem — algorithm dispatch lives on per-type extensions;
//     no `where N == 16 || N == 32 || N == 64` is ever needed.
//   • Each radix is a genuine nominal type per [API-NAME-001a] — Binary.Base is
//     a namespace with multiple sibling types, not a single-type-no-namespace.
//   • Shared shape (codeUnits + pad) is preserved by mechanical repetition; for
//     ≤6 radixes (16/32/58/62/64/85) the repetition is bounded.
//
// What V1-V5's value-generic shape does that V6 doesn't:
//   • Generic functions taking `Binary.Base<N>` over the family — not possible
//     with nominal-type-per-radix without introducing an algorithm-witness
//     protocol. For our use case (encode/decode per radix) this is never needed
//     at consumer sites.
//
// Note: This target redeclares the `Binary` namespace locally so it can stand
//   alone for the experiment. The production package would consume the existing
//   `Binary` from `swift-binary-primitives`'s `Binary Namespace` product.

public enum Binary {}

extension Binary {
    public enum Base {}
}

extension Binary.Base {
    public struct `16`: Sendable, Hashable {
        public let codeUnits: [UInt8]
        public let pad: UInt8?

        public init(codeUnits: [UInt8], pad: UInt8? = nil) {
            self.codeUnits = codeUnits
            self.pad = pad
        }
    }

    public struct `62`: Sendable, Hashable {
        public let codeUnits: [UInt8]
        public let pad: UInt8?

        public init(codeUnits: [UInt8], pad: UInt8? = nil) {
            self.codeUnits = codeUnits
            self.pad = pad
        }
    }
}

// MARK: - V6 — Per-radix algorithm dispatch on the nominal type itself

extension Binary.Base.`16` {
    /// Hex encoding (4 bits per digit). Big-endian within each byte.
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

extension Binary.Base.`62` {
    /// Base62 encoding via repeated division.
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

// MARK: - V6 — Canonical instances (witness pattern preserved)

extension Binary.Base.`16` {
    /// RFC 4648 §8 — uppercase hex.
    public static let rfc4648: Self = .init(
        codeUnits: Array("0123456789ABCDEF".utf8),
        pad: nil
    )
}

extension Binary.Base.`62` {
    public static let standard: Self = .init(
        codeUnits: Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz".utf8),
        pad: nil
    )
}
