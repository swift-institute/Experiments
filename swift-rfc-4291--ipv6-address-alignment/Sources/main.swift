// MARK: - IPv6 Address Memory Layout Verification
// Purpose: Verify whether RFC_4291.IPv6.Address's memory layout matches
//          POSIX's `in6_addr`. If layouts match, the RFC type can replace
//          iso-9945's raw IPv6 storage inside `sockaddr_in6.sin6_addr`
//          without byte-level re-marshalling at the syscall boundary.
// Hypothesis (from architectural analysis):
//   - Size:      RFC 16, POSIX 16 → match
//   - Alignment: RFC 2 (UInt16 tuple), POSIX 4 (union with uint32_t) → MISMATCH
//   - Bytes:     both network byte order, 8 × 16-bit segments → same content
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform:  macOS 26.0 (arm64)
//
// Result: REFUTED — layouts differ in BOTH alignment AND byte order.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         Alignment:  RFC = 2, POSIX = 4 (anticipated mismatch — confirmed)
//         Byte order: RFC = host order (little-endian on arm64),
//                     POSIX/in6_addr = network order (big-endian)
//         Example — address 2001:0db8:85a3:0:0:8a2e:0370:7334:
//           RFC   bytes: 01 20 b8 0d a3 85 00 00 00 00 2e 8a 70 03 34 73
//           POSIX bytes: 20 01 0d b8 85 a3 00 00 00 00 8a 2e 03 70 73 34
//         RFC_4291.IPv6.Address's docstring claims internal storage is
//         "network byte order (big-endian)", but the init stores host-order
//         UInt16s directly — the big-endian conversion happens only in the
//         Binary.Serializable serializer, not at the storage layer. Ditto
//         RFC_791.IPv4.Address: `rawValue: UInt32` stores host order.
//
//         Command: swift run — see Outputs/run.txt for verbatim measurements.
// Date:   2026-04-20

import RFC_4291

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

// MARK: - Measurements

let rfcSize      = MemoryLayout<RFC_4291.IPv6.Address>.size
let rfcStride    = MemoryLayout<RFC_4291.IPv6.Address>.stride
let rfcAlignment = MemoryLayout<RFC_4291.IPv6.Address>.alignment

let posixSize      = MemoryLayout<in6_addr>.size
let posixStride    = MemoryLayout<in6_addr>.stride
let posixAlignment = MemoryLayout<in6_addr>.alignment

print("=== Memory layout comparison ===")
print("")
print("RFC_4291.IPv6.Address:")
print("  size      = \(rfcSize)")
print("  stride    = \(rfcStride)")
print("  alignment = \(rfcAlignment)")
print("")
print("POSIX in6_addr:")
print("  size      = \(posixSize)")
print("  stride    = \(posixStride)")
print("  alignment = \(posixAlignment)")
print("")

// MARK: - Byte-content equivalence

let rfcAddress = RFC_4291.IPv6.Address(
    0x2001, 0x0db8, 0x85a3, 0x0000,
    0x0000, 0x8a2e, 0x0370, 0x7334
)

var rfcBytes = [UInt8]()
withUnsafeBytes(of: rfcAddress) { raw in
    rfcBytes.append(contentsOf: raw)
}

// Construct the equivalent in6_addr (byte-wise, to sidestep any platform-specific
// initializer shape) and read its bytes.
var posix = in6_addr()
withUnsafeMutableBytes(of: &posix) { dst in
    // Big-endian bytes: 20 01 0d b8 85 a3 00 00 00 00 8a 2e 03 70 73 34
    let expected: [UInt8] = [
        0x20, 0x01, 0x0d, 0xb8, 0x85, 0xa3, 0x00, 0x00,
        0x00, 0x00, 0x8a, 0x2e, 0x03, 0x70, 0x73, 0x34
    ]
    for i in 0..<16 { dst[i] = expected[i] }
}

var posixBytes = [UInt8]()
withUnsafeBytes(of: posix) { raw in
    posixBytes.append(contentsOf: raw)
}

func hex(_ byte: UInt8) -> String {
    let table: [Character] = ["0","1","2","3","4","5","6","7","8","9","a","b","c","d","e","f"]
    return String(table[Int(byte >> 4)]) + String(table[Int(byte & 0xF)])
}

print("=== Byte equivalence ===")
print("RFC   bytes: \(rfcBytes.map(hex).joined(separator: " "))")
print("POSIX bytes: \(posixBytes.map(hex).joined(separator: " "))")
print("equal = \(rfcBytes == posixBytes)")
print("")

// MARK: - Reinterpret-cast safety test
//
// If alignments match, reinterpreting an `in6_addr` pointer as an
// `RFC_4291.IPv6.Address` pointer (and vice versa) is safe. If they do not,
// only the wider-alignment → narrower-alignment direction is safe.

print("=== Reinterpret-cast safety ===")

// Direction 1: POSIX in6_addr* → RFC_4291.IPv6.Address*
// Always safe if posixAlignment >= rfcAlignment (stricter-aligned storage
// satisfies a looser-aligned view).
let d1Safe = posixAlignment >= rfcAlignment
print("in6_addr → RFC_4291.IPv6.Address: \(d1Safe ? "SAFE" : "UNSAFE") (\(posixAlignment) >= \(rfcAlignment))")

// Direction 2: RFC_4291.IPv6.Address* → in6_addr*
// Safe only if rfcAlignment >= posixAlignment.
let d2Safe = rfcAlignment >= posixAlignment
print("RFC_4291.IPv6.Address → in6_addr: \(d2Safe ? "SAFE" : "UNSAFE") (\(rfcAlignment) >= \(posixAlignment))")
print("")

// MARK: - Results Summary (verbatim from execution, 2026-04-20)
// Size match:      16 == 16  ✓
// Alignment match: 2  != 4   ✗
// Content match:   false     ✗  (host-order vs network-order storage)
// Direction 1 safe (POSIX → RFC): SAFE   (4 >= 2)
// Direction 2 safe (RFC → POSIX): UNSAFE (2 !>= 4)
//
// What this rules out:
// - A zero-copy in-place reinterpretation of RFC values as in6_addr
//   (the canonical unification that would let us skip marshalling
//   at the syscall boundary).
// - The assumption that swapping iso-9945's internal UInt16/UInt8
//   backing for RFC_4291.IPv6.Address is a drop-in change.
//
// What this implies for the unification question:
// - Layouts differ fundamentally, not superficially. Byte-order unification
//   would require the RFC type to store values in network byte order, which
//   is a semantic change (the `segments` tuple would need to return
//   `.bigEndian`-swapped values on access, OR the storage would need to be
//   an opaque `[UInt8; 16]` / `(UInt32 × 4)` big-endian with `segments` as
//   a computed accessor returning host-order UInt16s).
// - Per the user's split-vs-unify criterion ("keep split unless memory
//   layout matches"), the current shapes REMAIN SPLIT. The iso-9945
//   socket endpoint keeps its own in6_addr-based storage; RFC_4291
//   keeps its host-order UInt16 storage for RFC-correctness of the
//   public `segments` accessor.
//
// Marshalling at the iso-9945 / windows-standard boundary is therefore
// unavoidable with the current RFC type shape. Composition is still
// viable at the API level (iso-9945 accepts RFC values, converts them
// byte-wise into sockaddr_in6 during construction), but not at the
// layout level (no reinterpret-cast).
//
// REFUTED — direct memory-layout unification is not available without
// changing the RFC type's storage semantics.
