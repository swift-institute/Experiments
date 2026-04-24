// V10 support library — field-of-self + @inlinable + cross-module consumer.
//
// Purpose: empirically test whether the V1 miscompile class extends to the
// `withUnsafePointer(to: self.storedField)` shape — the pattern Memory.Inline
// uses in swift-memory-primitives. Memory.Inline.pointer(at:) is @inlinable,
// on a ~Copyable container, and does withUnsafePointer(to: _storage) where
// _storage is a @_rawLayout-like stored field of self.
//
// The existing V1-V9 are all in a single-file executable and crash
// uniformly in single-file mode. To test the CROSS-MODULE behavior
// specifically for the field-of-self shape, we need a two-target
// SwiftPM layout. This library target holds the @inlinable method; the
// executable target (main.swift §V10) is the cross-module consumer.
//
// Shape mirrored from Memory.Inline.pointer(at:):
//
//     @unsafe
//     @inlinable
//     public func pointer(at slot: Int) -> UnsafeMutablePointer<Element> {
//         return unsafe withUnsafePointer(to: _storage) { base in
//             unsafe UnsafeMutablePointer(
//                 mutating: UnsafeRawPointer(base)
//                     .advanced(by: slot * MemoryLayout<Element>.stride)
//                     .assumingMemoryBound(to: Element.self)
//             )
//         }
//     }
//
// Difference from V1: the withUnsafePointer target is a stored field of
// `self`, not a borrowing parameter. Same @inlinable, same cross-module
// inlining, same ~Copyable context. If the bug extends, V10 crashes
// cross-module. If field-of-self is structurally safe (self's ABI
// survives where a borrowing parameter's ABI doesn't), V10 passes.

/// Inner ~Copyable storage cell — mirrors Memory.Inline's _Raw shape
/// (without @_rawLayout; plain stored Int here is sufficient to exercise
/// the withUnsafePointer-to-~Copyable-stored-field codegen path).
public struct Cell: ~Copyable {
    @usableFromInline
    internal var _value: Int

    @inlinable
    public init(_ v: Int) {
        self._value = v
    }

    @inlinable
    public var value: Int { _value }
}

/// Container that stores a ~Copyable cell and exposes an @inlinable
/// `pointer()` method mirroring Memory.Inline.pointer(at:). The method
/// is the focus of the V10 experiment.
public struct FieldContainer: ~Copyable {
    @usableFromInline
    internal var _storage: Cell

    @inlinable
    public init(_ v: Int) {
        self._storage = Cell(v)
    }

    /// Returns a typed pointer derived from `withUnsafePointer(to: _storage)`.
    ///
    /// This is the direct analog of Memory.Inline.pointer(at:). Cross-module
    /// consumers calling this method trigger the @inlinable cross-module
    /// inlining path; if the V1 miscompile class extends to field-of-self,
    /// the returned pointer dangles.
    @unsafe
    @inlinable
    public func pointer() -> UnsafePointer<Int> {
        return unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Int.self)
        }
    }

    /// V11 companion: same shape as `pointer()` but NOT `@inlinable`. If the
    /// V1 workaround (cross-module function-call boundary preserves
    /// `@in_guaranteed` ABI) generalizes to the field-of-self shape, this
    /// method returns a stable pointer; if field-of-self is a different bug
    /// class, this method still dangles.
    @unsafe
    public func pointerNonInlinable() -> UnsafePointer<Int> {
        return unsafe withUnsafePointer(to: _storage) { base in
            unsafe UnsafeRawPointer(base).assumingMemoryBound(to: Int.self)
        }
    }
}
