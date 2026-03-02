@_exported import TaggedLib

public enum PathTag: ~Copyable {}

// ============================================================================
// MARK: - V1: Span through rawValue._read (production Tagged)
// ============================================================================
// Hypothesis: rawValue (_read coroutine, public, from separate package)
//   can be used in a @_lifetime(borrow self) borrowing get to create a Span
//   via _overrideLifetime. This is the CRITICAL test — if this works,
//   production Tagged needs NO changes for D'.
//
// Production pattern this mirrors:
//   String.span { _storage.span → _overrideLifetime(s, borrowing: self) }
//   But replacing _storage (internal) with rawValue (public _read coroutine).

// REFUTED: lifetime-dependent variable 's' escapes its scope
//   rawValue.pointer depends on _read coroutine scope, _overrideLifetime
//   cannot re-parent across that boundary.
#if false
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag: ~Copyable {
    @inlinable
    public var count: Int { rawValue.count }

    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: rawValue.pointer, count: rawValue.count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}
#endif

// ============================================================================
// MARK: - V2: Span through stored property (TaggedStored)
// ============================================================================
// Hypothesis: Public stored property rawValue has no coroutine scope.
//   Stored property access is direct — identical to accessing _storage
//   from within the same module. Should always work.

extension TaggedStored where RawValue == Memory.Contiguous<Char>, Tag: ~Copyable {
    @inlinable
    public var count: Int { rawValue.count }

    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: rawValue.pointer, count: rawValue.count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V3: ~Escapable View through rawValue._read (production Tagged)
// ============================================================================
// Hypothesis: A ~Escapable View type can be created through rawValue._read
//   in a borrowing get property, using _overrideLifetime to re-parent the
//   View's lifetime from the coroutine scope to self.
//
// This mirrors:
//   String.view { String.View(_storage.unsafeBaseAddress) → _overrideLifetime }
//   But through rawValue instead of _storage.
//
// The prior tagged-string-literal failure was in a withView CLOSURE — this
// tests the same concept in a PROPERTY, which may behave differently.

// REFUTED: lifetime-dependent variable 'v' escapes its scope
//   rawValue.pointer depends on _read coroutine scope, _overrideLifetime
//   cannot re-parent across that boundary — same as V1 but with ~Escapable View.
#if false
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag == PathTag {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _pointer: UnsafePointer<Char>
        @usableFromInline
        internal let _count: Int

        @inlinable
        @_lifetime(borrow pointer)
        internal init(_ pointer: UnsafePointer<Char>, count: Int) {
            unsafe self._pointer = pointer
            self._count = count
        }

        @inlinable
        public var length: Int { _count }

        public var span: Span<Char> {
            @_lifetime(copy self)
            @inlinable
            borrowing get {
                let s = unsafe Span(_unsafeStart: _pointer, count: _count)
                return unsafe _overrideLifetime(s, copying: self)
            }
        }
    }

    /// ~Escapable View as a direct property — NOT a with* closure.
    /// This is how ~Escapable views should be exposed per the user's requirement.
    public var view: View {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = unsafe View(rawValue.pointer, count: rawValue.count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}
#endif

// ============================================================================
// MARK: - V4: ~Escapable View through stored property (TaggedStored)
// ============================================================================
// Control test. Same View pattern but through stored property rawValue.

extension TaggedStored where RawValue == Memory.Contiguous<Char>, Tag == PathTag {
    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline
        internal let _pointer: UnsafePointer<Char>
        @usableFromInline
        internal let _count: Int

        @inlinable
        @_lifetime(borrow pointer)
        internal init(_ pointer: UnsafePointer<Char>, count: Int) {
            unsafe self._pointer = pointer
            self._count = count
        }

        @inlinable
        public var length: Int { _count }

        public var span: Span<Char> {
            @_lifetime(copy self)
            @inlinable
            borrowing get {
                let s = unsafe Span(_unsafeStart: _pointer, count: _count)
                return unsafe _overrideLifetime(s, copying: self)
            }
        }
    }

    public var view: View {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = unsafe View(rawValue.pointer, count: rawValue.count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V5: Chained Span through rawValue.span (production Tagged)
// ============================================================================
// Hypothesis: Instead of building Span from rawValue.pointer/count directly,
//   chain through Memory.Contiguous<Char>.span (which itself uses @_lifetime).
//   This mirrors: String.span → _storage.span → _overrideLifetime
//   But through rawValue._read → Memory.Contiguous<Char>.span → _overrideLifetime.
//
// The chain is:
//   1. self.rawValue → Tagged._read yields Memory.Contiguous<Char> borrow
//   2. .span → Memory.Contiguous<Char>.span @_lifetime(borrow self) returns Span
//   3. _overrideLifetime(s, borrowing: self) → re-parents to Tagged self
//
// If V1 fails but V5 passes, the issue is creating Span from raw components
// through _read, not chaining through an intermediate @_lifetime property.

// REFUTED: lifetime-dependent variable 's' escapes its scope
//   rawValue.span chains through _read → .span, but the _read coroutine
//   scope still blocks _overrideLifetime — chaining doesn't help.
#if false
extension Tagged where RawValue == Memory.Contiguous<Char>, Tag: ~Copyable {
    public var chainedSpan: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = rawValue.span
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}
#endif
