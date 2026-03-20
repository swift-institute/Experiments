// Middle buffer layer backed by @_rawLayout storage.
// Mirrors production: Buffer<Element>.Ring.Inline<capacity> wrapping Storage<Element>.Inline<capacity>.
//
// This is the CRITICAL variant. The existing Middle.swift uses regular stored properties
// which don't trigger bug #86652. This variant uses InlineStorage (backed by @_rawLayout),
// which is what production uses and what triggers the bug.

import Element
import Storage

// MARK: - @_rawLayout Middle (type generic + value generic)

/// Wraps InlineStorage<Element, capacity> — mirrors Buffer.Ring.Inline<capacity>.
/// The @_rawLayout storage inside InlineStorage is what triggers the compiler bug.
public struct MiddleRaw<Element: ~Copyable, let capacity: Int>: ~Copyable {
    @usableFromInline
    package var header: Int

    @usableFromInline
    package var storage: InlineStorage<Element, capacity>

    @inlinable
    public init(header: Int, storage: consuming InlineStorage<Element, capacity>) {
        self.header = header
        self.storage = storage
    }

    /// Manual cleanup — mirrors production Buffer.Ring.Inline remove.all() path.
    /// Called by outer container's deinit when compiler fails to synthesize member destruction.
    @inlinable
    public mutating func deinitializeStorage() {
        storage.deinitializeAll()
    }

    deinit {
        // This deinit should trigger InlineStorage.deinit via member destruction.
        // Bug #86652: the compiler does NOT synthesize this member destruction
        // for cross-package, value-generic, @_rawLayout-backed properties.
        print("  MiddleRaw<Element, \(capacity)> deinit")
    }
}

// MARK: - Deeply Nested @_rawLayout Middle

/// Namespace enum — mirrors `enum Buffer<Element: ~Copyable>`.
public enum BufferRawNS<Element: ~Copyable> {

    /// Nested struct — mirrors `struct Ring: ~Copyable` inside Buffer.
    public struct Ring: ~Copyable {

        /// Doubly-nested with value generic and @_rawLayout storage.
        /// Mirrors Buffer<Element>.Ring.Inline<capacity> in production.
        public struct Inline<let capacity: Int>: ~Copyable {
            @usableFromInline
            package var header: Int

            @usableFromInline
            package var storage: InlineStorage<Element, capacity>

            @inlinable
            public init(header: Int, storage: consuming InlineStorage<Element, capacity>) {
                self.header = header
                self.storage = storage
            }

            /// Manual cleanup path.
            @inlinable
            public mutating func deinitializeStorage() {
                storage.deinitializeAll()
            }

            deinit {
                print("  BufferRawNS<Element>.Ring.Inline<\(capacity)> deinit")
            }
        }
    }
}
