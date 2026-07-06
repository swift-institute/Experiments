// StringLib — the generic String types under test, the Backing seam, the
// ContiguousString protocol, and the Tagged outer-layer extensions.
//
// The inner-layer accessors mirror production String.swift:163-216 exactly
// (typed base derived per-access from the storage seam, @_lifetime(borrow self)
// span/view re-parented via _overrideLifetime). The outer Tagged extensions
// mirror production Tagged+String.swift:79-86 (the base-address detour). The
// ONLY change vs the validated `tagged-two-level-lifetime` experiment is that
// the RawValue is now generic.

@_exported import TaggedLib

// ============================================================================
// MARK: - Backing seam (minimal Memory.Region / Memory.Heap analog)
// ============================================================================

/// Minimal analog of `Memory.Region`: a ~Copyable owning raw byte region whose
/// typed base is reached PER ACCESS through the seam ([MEM-SAFE-029] — no cached
/// generic base; derive through the seam each time).
public protocol RawRegion: ~Copyable {
    @unsafe var unsafeBase: UnsafeMutableRawPointer { get }
}

/// Concrete owning region (the `Memory.Heap` analog): owns the allocation,
/// frees on destruction.
@safe
public struct HeapStub: RawRegion, ~Copyable {
    @usableFromInline let _base: UnsafeMutableRawPointer

    @inlinable
    public init(adopting base: UnsafeMutableRawPointer) {
        unsafe self._base = base
    }

    @unsafe @inlinable
    public var unsafeBase: UnsafeMutableRawPointer { unsafe _base }

    @inlinable
    deinit { unsafe _base.deallocate() }
}

// ============================================================================
// MARK: - V1a: CharOnlyString<Char>  (axis ② only — generic Char, CONCRETE backing)
// ============================================================================
// Isolates the encoding axis: does @_lifetime(borrow self) + _overrideLifetime
// work inside a struct generic over Char, with a concrete (non-generic) backing?

@safe
public struct CharOnlyString<Char>: ~Copyable where Char: FixedWidthInteger & UnsignedInteger {
    @usableFromInline let _backing: HeapStub
    public let count: Int

    @inlinable
    public init(backing: consuming HeapStub, count: Int) {
        self._backing = backing
        self.count = count
    }

    @unsafe @inlinable
    internal var _base: UnsafePointer<Char> {
        unsafe UnsafePointer(_backing.unsafeBase.assumingMemoryBound(to: Char.self))
    }

    public var span: Span<Char> {
        @_lifetime(borrow self) @inlinable borrowing get {
            let s = unsafe Span(_unsafeStart: _base, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V1b / V2: GenericString<Char, Backing>  (axes ② + ③)
// ============================================================================
// Both axes generic: Char (encoding) AND Backing (storage strategy), the latter
// reached through the RawRegion seam. This is the arc's target inner shape.

@safe
public struct GenericString<Char, Backing>: ~Copyable
where Char: FixedWidthInteger & UnsignedInteger, Backing: RawRegion & ~Copyable {
    @usableFromInline let _backing: Backing
    public let count: Int

    @inlinable
    public init(backing: consuming Backing, count: Int) {
        self._backing = backing
        self.count = count
    }

    /// Typed base derived PER ACCESS from the generic Backing seam ([MEM-SAFE-029]).
    @unsafe @inlinable
    internal var _base: UnsafePointer<Char> {
        unsafe UnsafePointer(_backing.unsafeBase.assumingMemoryBound(to: Char.self))
    }

    @unsafe @inlinable
    public var unsafeBaseAddress: UnsafePointer<Char> { unsafe _base }

    /// Inner @_lifetime layer — Span tied to self, base from the generic seam.
    public var span: Span<Char> {
        @_lifetime(borrow self) @inlinable borrowing get {
            let s = unsafe Span(_unsafeStart: _base, count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    // --- V2: nested ~Escapable View through the generic ---

    @safe
    public struct View: ~Copyable, ~Escapable {
        @usableFromInline let _pointer: UnsafePointer<Char>
        @usableFromInline let _count: Int

        @inlinable @_lifetime(borrow pointer)
        internal init(_ pointer: UnsafePointer<Char>, count: Int) {
            unsafe self._pointer = pointer
            self._count = count
        }

        @inlinable public var length: Int { _count }

        public var span: Span<Char> {
            @_lifetime(copy self) @inlinable borrowing get {
                let s = unsafe Span(_unsafeStart: _pointer, count: _count)
                return unsafe _overrideLifetime(s, copying: self)
            }
        }
    }

    /// Inner @_lifetime layer for the ~Escapable view.
    public var view: View {
        @_lifetime(borrow self) @inlinable borrowing get {
            let v = unsafe View(_base, count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - ContiguousString protocol seam (for the GENERIC outer Tagged extension)
// ============================================================================
// Lets a single `extension Tagged where Underlying: ContiguousString` serve EVERY
// String instantiation, rather than one extension per concrete <Char, Backing>.

public protocol ContiguousString: ~Copyable, ~Escapable {
    associatedtype Char: FixedWidthInteger & UnsignedInteger
    var count: Int { get }
    @unsafe var unsafeBaseAddress: UnsafePointer<Char> { get }
}

// Conditional conformance — must restate `Backing: ~Copyable` ([COPY-FIX-003]).
extension GenericString: ContiguousString where Backing: ~Copyable {}

// ============================================================================
// MARK: - Domain tags
// ============================================================================

public enum Kernel: ~Copyable & ~Escapable {}
public enum Loader: ~Copyable & ~Escapable {}

// ============================================================================
// MARK: - V4: GENERIC outer Tagged layer  (where Underlying: ContiguousString)
// ============================================================================
// THE scalability crux: one extension covers Tagged<AnyTag, AnyString>.
// Production base-address detour, but the element type is the protocol's
// associated `Underlying.Char`.

extension Tagged
where Underlying: ContiguousString, Underlying: ~Copyable & ~Escapable, Tag: ~Copyable & ~Escapable {
    @inlinable
    public var count: Int { underlying.count }

    public var span: Span<Underlying.Char> {
        @_lifetime(borrow self) @inlinable borrowing get {
            let pointer = unsafe underlying.unsafeBaseAddress
            let n = underlying.count
            let s = unsafe Span(_unsafeStart: pointer, count: n)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V3 / V5: CONCRETE outer Tagged layer  (where Underlying == String<U8,Heap>)
// ============================================================================
// Option (a): per-instantiation outer extension (the fallback if V4 is infeasible).
// `spanConcrete` is named distinctly from V4's `span` to avoid redeclaration,
// since GenericString<UInt8,HeapStub> ALSO satisfies ContiguousString.

extension Tagged where Underlying == GenericString<UInt8, HeapStub>, Tag: ~Copyable & ~Escapable {
    /// V3 — concrete-instantiation span via the detour.
    public var spanConcrete: Span<UInt8> {
        @_lifetime(borrow self) @inlinable borrowing get {
            let pointer = unsafe underlying.unsafeBaseAddress
            let n = underlying.count
            let s = unsafe Span(_unsafeStart: pointer, count: n)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    /// V5 — ~Escapable View two-level detour through the generic, re-parented to self.
    public var view: GenericString<UInt8, HeapStub>.View {
        @_lifetime(borrow self) @inlinable borrowing get {
            let pointer = unsafe underlying.unsafeBaseAddress
            let n = underlying.count
            let v = unsafe GenericString<UInt8, HeapStub>.View(pointer, count: n)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }
}

// ============================================================================
// MARK: - V6: One-parameter framing  String1<Storage>   (§8.1 comparison)
// ============================================================================
// Folds Char + Backing into a single `Storage` parameter (the
// `Storage.Contiguous<Char, Allocation>` framing from baseline §5.4).

public protocol ContiguousStorage: ~Copyable {
    associatedtype Char: FixedWidthInteger & UnsignedInteger
    @unsafe var typedBase: UnsafePointer<Char> { get }
    var count: Int { get }
}

@safe
public struct HeapStorage<Char>: ContiguousStorage, ~Copyable
where Char: FixedWidthInteger & UnsignedInteger {
    @usableFromInline let _base: UnsafeMutableRawPointer
    public let count: Int

    @inlinable
    public init(adopting base: UnsafeMutableRawPointer, count: Int) {
        unsafe self._base = base
        self.count = count
    }

    @unsafe @inlinable
    public var typedBase: UnsafePointer<Char> {
        unsafe UnsafePointer(_base.assumingMemoryBound(to: Char.self))
    }

    @inlinable
    deinit { unsafe _base.deallocate() }
}

@safe
public struct String1<Storage>: ~Copyable where Storage: ContiguousStorage & ~Copyable {
    @usableFromInline let _storage: Storage

    @inlinable
    public init(_ storage: consuming Storage) {
        self._storage = storage
    }

    @inlinable public var count: Int { _storage.count }

    public var span: Span<Storage.Char> {
        @_lifetime(borrow self) @inlinable borrowing get {
            let s = unsafe Span(_unsafeStart: _storage.typedBase, count: _storage.count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}
