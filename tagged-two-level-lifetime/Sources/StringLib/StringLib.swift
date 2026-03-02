@_exported import TaggedLib

public typealias Char = UInt8

// ============================================================================
// MARK: - Concrete String type (NOT generic, NOT Tagged)
// ============================================================================
// String owns Memory.Contiguous<Char> and provides span/view with @_lifetime.
// This mirrors production String_Primitives.String.

@safe
public struct PlatformString: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let pointer: UnsafePointer<Char>

    public let count: Int

    @inlinable
    public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        unsafe self.pointer = UnsafePointer(pointer)
        self.count = count
    }

    @unsafe
    @inlinable
    public var unsafeBaseAddress: UnsafePointer<Char> { unsafe pointer }

    /// Span with @_lifetime — this is the INNER @_lifetime layer.
    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    @inlinable
    deinit {
        unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
    }
}

// ============================================================================
// MARK: - Concrete Path type (NOT generic, NOT Tagged)
// ============================================================================
// Path also owns contiguous char memory. Structurally identical storage,
// but nominally distinct from PlatformString.

@safe
public struct PlatformPath: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let pointer: UnsafePointer<Char>

    public let count: Int

    @inlinable
    public init(adopting pointer: UnsafeMutablePointer<Char>, count: Int) {
        unsafe self.pointer = UnsafePointer(pointer)
        self.count = count
    }

    /// Span with @_lifetime — inner layer.
    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    @inlinable
    public var isAbsolute: Bool {
        unsafe (count > 0 && pointer.pointee == 47) // '/'
    }

    @inlinable
    deinit {
        unsafe UnsafeMutablePointer(mutating: pointer).deallocate()
    }
}

// ============================================================================
// MARK: - ~Escapable View on PlatformString
// ============================================================================

extension PlatformString {
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

    /// ~Escapable View as property.
    public var view: View {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = unsafe View(pointer, count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - Domain tag
// ============================================================================

public enum Kernel: ~Copyable {}

// ============================================================================
// MARK: - V1: Span through Tagged<Kernel, PlatformString> — chained @_lifetime
// ============================================================================
// Chain: Tagged.rawValue (stored property) → PlatformString.span (@_lifetime)
//        → _overrideLifetime(s, borrowing: self)
// This is the CRITICAL two-level test.

extension Tagged where RawValue == PlatformString, Tag: ~Copyable {
    @inlinable
    public var count: Int { rawValue.count }

    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = rawValue.span
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V2: Span through Tagged<Kernel, PlatformPath> — chained @_lifetime
// ============================================================================
// Same chain but for Path. Confirms the pattern works for multiple RawValue types.

extension Tagged where RawValue == PlatformPath, Tag: ~Copyable {
    @inlinable
    public var count: Int { rawValue.count }

    public var span: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = rawValue.span
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V3: ~Escapable View through Tagged<Kernel, PlatformString>
// ============================================================================
// Chain: Tagged.rawValue (stored) → PlatformString.view (@_lifetime, ~Escapable)
//        → _overrideLifetime(v, borrowing: self)

extension Tagged where RawValue == PlatformString, Tag == Kernel {
    public var view: PlatformString.View {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = rawValue.view
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V4: Direct Span from rawValue.pointer/count (no inner @_lifetime)
// ============================================================================
// Control: builds Span directly from rawValue's pointer/count.
// Not chained — single @_lifetime only.

extension Tagged where RawValue == PlatformString, Tag: ~Copyable {
    public var directSpan: Span<Char> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: rawValue.unsafeBaseAddress, count: rawValue.count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V5: Domain-specific extension on Tagged<Kernel, PlatformPath>
// ============================================================================

extension Tagged where RawValue == PlatformPath, Tag == Kernel {
    @inlinable
    public var isAbsolute: Bool { rawValue.isAbsolute }
}

// ============================================================================
// MARK: - V6: Type distinctness — Tagged<Kernel, String> != Tagged<Kernel, Path>
// ============================================================================
// This is verified at the type level: you can't assign a Tagged<Kernel, PlatformString>
// to a Tagged<Kernel, PlatformPath>. Compile-time safety.
