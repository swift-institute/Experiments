// MARK: - V5: typed-only L2; consumer writes its own raw shim
// Purpose: L2 exposes typed only — no raw access through L2 at all. The
// consumer that needs raw writes its own minimal C-shim target (or, in
// this sandbox, an in-target Swift helper) that imports the platform C
// module directly.
//
// Architectural caveat: per [PLAT-ARCH-008a], non-platform-stack consumers
// MUST NOT import Darwin/Glibc/Musl/WinSDK. V5 is the "physically possible
// but architecturally forbidden" pattern — consumers route around L2 by
// reaching back to the platform C themselves.

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}
