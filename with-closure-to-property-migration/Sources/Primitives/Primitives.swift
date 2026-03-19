// ============================================================
// with-closure-to-property-migration — Primitives module
//
// Simulates swift-primitives types that currently use with* { }
// closure patterns. Each type exposes the PROPERTY form that
// should replace the closure form.
//
// Types:
//   OwnedBuffer     — ~Copyable owner (mirrors String, Path)
//   BorrowedView    — ~Escapable view  (mirrors String.View, Path.View)
//   MappedRegion    — Copyable owner   (mirrors Kernel.Memory.Map.Region)
//   EnvironmentEntry — ~Escapable owner (mirrors Kernel.Environment.Entry)
//   FileHandle      — ~Copyable owner  (mirrors Kernel.File.Handle)
// ============================================================


// ============================================================
// V1: ~Copyable owner → ~Escapable View property
// Replaces: path.withView { view in ... }
// Control: String.view already works in production
// Gap A: Path.view does NOT exist yet — verify same pattern works
// ============================================================

public struct OwnedBuffer: ~Copyable, @unchecked Sendable {
    @usableFromInline
    internal let _pointer: UnsafeMutablePointer<UInt8>
    public let count: Int

    @inlinable
    public init(_ bytes: [UInt8]) {
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: bytes.count)
        for i in 0..<bytes.count { (unsafe buf)[i] = bytes[i] }
        unsafe (self._pointer = buf)
        self.count = bytes.count
    }

    deinit { _pointer.deallocate() }

    /// Property form of withView { }
    public var view: BorrowedView {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let v = unsafe BorrowedView(UnsafePointer(_pointer), count: count)
            return unsafe _overrideLifetime(v, borrowing: self)
        }
    }

    /// Property form of withSpan { }
    public var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: UnsafePointer(_pointer), count: count)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }
}


// ============================================================
// ~Escapable View type
// Mirrors: String.View, Path.View, Kernel.Path.View
// ============================================================

public struct BorrowedView: ~Copyable, ~Escapable {
    public let pointer: UnsafePointer<UInt8>
    public let count: Int

    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<UInt8>, count: Int) {
        unsafe (self.pointer = pointer)
        self.count = count
    }

    /// ~Escapable owner → Span property (already proven: String.View.span)
    public var span: Span<UInt8> {
        @_lifetime(copy self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: pointer, count: count)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}


// ============================================================
// V3: Copyable + @unchecked Sendable owner → ~Escapable Span
// Replaces: region.withSpan { span in ... }
// Gap B: Does @_lifetime(borrow self) work when self is Copyable?
// ============================================================

public struct MappedRegion: @unchecked Sendable {
    public let base: UnsafeMutablePointer<UInt8>?
    public let length: Int

    @inlinable
    public init(base: UnsafeMutablePointer<UInt8>?, length: Int) {
        unsafe (self.base = base)
        self.length = length
    }

    /// Gap B: Copyable owner returning ~Escapable Span
    public var span: Span<UInt8> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            guard let base else {
                return unsafe _overrideLifetime(Span<UInt8>(), borrowing: self)
            }
            let s = unsafe Span(_unsafeStart: UnsafePointer(base), count: length)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    // ============================================================
    // V4a: MutableSpan via borrowing get
    // Gap C: Can a computed property return MutableSpan?
    // ============================================================
    public var mutableSpanGet: MutableSpan<UInt8> {
        @_lifetime(borrow self)
        @inlinable
        borrowing get {
            guard let base else {
                return unsafe _overrideLifetime(MutableSpan<UInt8>(), borrowing: self)
            }
            let s = unsafe MutableSpan(_unsafeStart: base, count: length)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
    }

    // ============================================================
    // V4b: MutableSpan via _modify (yields inout)
    // Gap C: Can _modify yield a ~Escapable MutableSpan?
    // Requires var self at call site.
    // ============================================================
    public var mutableSpanModify: MutableSpan<UInt8> {
        @_lifetime(borrow self)
        @inlinable
        get {
            guard let base else {
                return unsafe _overrideLifetime(MutableSpan<UInt8>(), borrowing: self)
            }
            let s = unsafe MutableSpan(_unsafeStart: base, count: length)
            return unsafe _overrideLifetime(s, borrowing: self)
        }
        @_lifetime(&self)
        @inlinable
        mutating _modify {
            guard let base else {
                var empty = MutableSpan<UInt8>()
                yield &empty
                return
            }
            var s = unsafe MutableSpan(_unsafeStart: base, count: length)
            yield &s
        }
    }
}


// ============================================================
// V5: ~Escapable owner → Span properties
// Replaces: entry.withName { span in ... }
//           entry.withValue { span in ... }
// Gap A variant: ~Escapable struct returning ~Escapable Span
// ============================================================

public struct EnvironmentEntry: ~Copyable, ~Escapable {
    @usableFromInline
    internal let _name: UnsafePointer<UInt8>
    @usableFromInline
    internal let _value: UnsafePointer<UInt8>
    public let nameLength: Int
    public let valueLength: Int

    @inlinable
    @_lifetime(borrow name, borrow value)
    @unsafe
    public init(
        name: UnsafePointer<UInt8>, nameLength: Int,
        value: UnsafePointer<UInt8>, valueLength: Int
    ) {
        unsafe (self._name = name)
        unsafe (self._value = value)
        self.nameLength = nameLength
        self.valueLength = valueLength
    }

    /// Replaces withName { span in ... }
    public var name: Span<UInt8> {
        @_lifetime(copy self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: _name, count: nameLength)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }

    /// Replaces withValue { span in ... }
    public var value: Span<UInt8> {
        @_lifetime(copy self)
        @inlinable
        borrowing get {
            let s = unsafe Span(_unsafeStart: _value, count: valueLength)
            return unsafe _overrideLifetime(s, copying: self)
        }
    }
}


// ============================================================
// V_trivial: Public descriptor (no lifetime features needed)
// Replaces: handle.withDescriptor { fd in ... }
// ============================================================

public struct FileHandle: ~Copyable {
    public let descriptor: Int32

    @inlinable
    public init(descriptor: Int32) {
        self.descriptor = descriptor
    }
}
