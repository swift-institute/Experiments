// Probe.swift
//
// Hosts the cross-package addition: `Double: Binary.Serializable`.
// Double already conforms to `JSON.Serializable` in swift-json itself
// (`JSON.Serializable.swift:419`), so the experiment exercises:
//
//   - JSON.Serializable conformance from swift-json (package A)
//   - Binary.Serializable conformance from THIS probe (package B)
//
// Two sibling format-Codable conformances on the same stdlib type,
// declared in different packages.  The family-pattern claim is that
// this composes; the experiment verifies.
//
// Toolchain: Apple Swift 6.3
// Status: V1-V4 results recorded in main.swift after execution

public import Binary_Serializable_Primitives

// MARK: - Double: Binary.Serializable (retroactive — Double is stdlib,
// Binary.Serializable is binary-primitives, conformance lands in this
// third module).

extension Double: @retroactive Binary.Serializable {
    /// Serializes a Double as 8 bytes of its IEEE-754 bit pattern,
    /// in native endian (matches the FixedWidthInteger default in
    /// swift-binary-primitives).
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ value: Double,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        var bits = value.bitPattern // UInt64, native endian
        withUnsafeBytes(of: &bits) { ptr in
            for byte in ptr {
                buffer.append(byte)
            }
        }
    }
}
