// MARK: - V2: private FFI inside L2 wrapper; typed-only public surface
// Purpose: Raw FFI lives as a `private` (file-scope) helper inside L2.
// Public/SPI surface exposes only the typed form. Consumers cannot access
// raw at all through L2 — they would have to reach for some other
// mechanism (V5) or do without (V6).

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}
