// String.Domain.swift — Domain phantom tags and conditional extensions

import TaggedLib

// MARK: - Domain Tags

/// Generic string domain (replaces current String_Primitives.String usage).
public enum GenericTag: ~Copyable {}

/// Path domain (replaces current Kernel.Path usage).
public enum PathTag: ~Copyable {}

// MARK: - Path-Specific Extensions

extension Tagged where RawValue == StringStorage, Tag == PathTag {
    /// Whether this path starts with `/`.
    @inlinable
    public var isAbsolutePath: Bool {
        guard count > 0 else { return false }
        return unsafe _storage.pointer.pointee == UInt8(ascii: "/")
    }
}

// MARK: - Ergonomic Typealiases

/// A kernel-level filesystem path string.
public typealias KernelPath = Tagged<PathTag, StringStorage>

/// A generic platform string (OS-native encoding).
public typealias OSString = Tagged<GenericTag, StringStorage>
