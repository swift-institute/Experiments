// MARK: - V4: package access at L2
// Purpose: Raw FFI lives at `package` access. Visible across all targets
// within the SAME SPM Package.swift; INVISIBLE across separate SPM packages.
//
// Architectural caveat: in our ecosystem, swift-iso-9945 / swift-darwin /
// swift-linux / swift-windows / swift-foundations / swift-file-system live
// in DIFFERENT SPM packages (one Package.swift each). So `package`
// visibility from L2 to a cross-stack consumer (e.g., swift-file-system
// reading raw fds from swift-iso-9945) WILL NOT work.
//
// In this experiment, all 18 targets live in ONE Package.swift, so
// `package` visibility works between V4_Consumer and V4_L2. This validates
// the within-package-collection case but does not generalize.

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}
