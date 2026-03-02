// String.View.swift — ~Escapable view type
//
// CRITICAL TEST: This file accesses TaggedLib._storage from @inlinable code
// in StringLib. The @_lifetime annotation must propagate correctly across
// the module boundary through @usableFromInline internal var _storage.

import TaggedLib

// MARK: - View Type

extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _pointer: UnsafePointer<Char>

        @inlinable
        @_lifetime(borrow pointer)
        internal init(_ pointer: UnsafePointer<Char>) {
            unsafe self._pointer = pointer
        }

        @inlinable
        public borrowing func withUnsafePointer<R: ~Copyable, E: Swift.Error>(
            _ body: (UnsafePointer<Char>) throws(E) -> R
        ) throws(E) -> R {
            try unsafe body(_pointer)
        }
    }
}

// MARK: - View Access (closure-based)

extension Tagged where RawValue == StringStorage, Tag: ~Copyable {
    /// Calls `body` with a borrowed view of this string's contents.
    ///
    /// CRITICAL: Accesses `_storage.pointer` directly — NOT `rawValue.pointer`.
    /// The rawValue `_read` coroutine creates a scope boundary that blocks
    /// `@_lifetime` propagation for `~Escapable` return types.
    @inlinable
    public borrowing func withView<R: ~Copyable, E: Swift.Error>(
        _ body: (borrowing View) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(View(_storage.pointer))
    }
}

// MARK: - Span Access

extension Tagged<PathTag, StringStorage>.View {
    /// O(n) scan for null terminator.
    @inlinable
    public var length: Int {
        var current = _pointer
        var count = 0
        while unsafe current.pointee != 0 {
            unsafe current = current.successor()
            count += 1
        }
        return count
    }

    /// Safe span over the view's characters (excluding null terminator).
    public var span: Span<Char> {
        @_lifetime(copy self)
        @inlinable
        borrowing get {
            let span = unsafe Span(_unsafeStart: _pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}
