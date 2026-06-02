// MARK: - ScopedSliceKit — the candidate ~Escapable scoped-slice view
//
// The shape collection-slice-escapable-index-toolchain-fallout.md v1.1.0 left UNTESTED.
// That doc's Option-B obstruction was: an *Escapable* struct cannot store a ~Escapable
// index ("stored property 'lower' of 'Escapable'-conforming struct 'EscapableSlice' has
// non-Escapable type 'NEIndex'"). The untested variation — and exactly the "scoped view"
// the consumer-fallout v1.3.0 §Foreclosed names as the honest model for within-scope
// random access — is a slice that is ITSELF ~Escapable, so it MAY hold ~Escapable bounds.
//
// Toolchain: built on BOTH Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) and 6.5-dev
//   (org.swift.64202605121a), arm64-apple-macos26.0.
// Status: CONFIRMED — compiles + runs (debug + release, cross-module) on both toolchains.
// Result: VIABLE (Build Succeeded both toolchains; consumer prints sum=90). See main.swift
//   for the full results matrix and the verbatim escape-rejection / producer-subscript notes.

/// Escapable owner of borrowed storage. Holds an unsafe window into caller-owned memory;
/// the caller keeps the memory alive for the borrow scope (see main.swift / EscapeRejection).
public struct Base {
    public let buffer: UnsafeBufferPointer<Int>
    public init(_ buffer: UnsafeBufferPointer<Int>) { self.buffer = buffer }
}

/// A ~Escapable index: a bounds-checked cursor "valid only within the borrow"
/// (consumer-fallout v1.3.0 steelman #4). Carries a position; its lifetime is tied to the
/// base borrow, so it cannot escape. Ordering is a plain `borrowing func` (NOT
/// Comparison.`Protocol`) to keep the multi-toolchain gate free of the SE-0499
/// Comparable-vs-Escapable confound.
public struct Cursor: ~Escapable {
    public let offset: Int

    @_lifetime(borrow base)
    public init(_ offset: Int, in base: borrowing Base) { self.offset = offset }

    public borrowing func isBefore(_ other: borrowing Cursor) -> Bool {
        self.offset < other.offset
    }
}

/// The ~Escapable scoped-slice VIEW. Stores its two ~Escapable bound indices DIRECTLY
/// (no stored `Range`) plus a borrow of the base. Itself ~Escapable, so it cannot escape
/// the borrow scope.
///
/// Two ~Escapable stored fields → `@_lifetime(copy lower, copy upper)`, the validated
/// multi-~Escapable-field pattern from `pointer-nonescapable-storage` (`TuplePair`,
/// `Triple`). The unsafe `buffer` is Escapable (a raw pointer carries no lifetime
/// obligation); the view's escape protection comes transitively from `lower`/`upper`,
/// which are pinned to the base borrow.
public struct ScopedSlice: ~Escapable {
    public let buffer: UnsafeBufferPointer<Int>
    public let lower: Cursor
    public let upper: Cursor

    @_lifetime(copy lower, copy upper)
    public init(
        buffer: UnsafeBufferPointer<Int>,
        lower: borrowing Cursor,
        upper: borrowing Cursor
    ) {
        self.buffer = buffer
        self.lower = copy lower
        self.upper = copy upper
    }

    /// Within-scope read access (no escape): sum over `[lower, upper)`.
    public borrowing func sum() -> Int {
        var total = 0
        var o = lower.offset
        while o < upper.offset {
            total += buffer[o]
            o += 1
        }
        return total
    }

    /// Within-scope indexed access by an Escapable offset (the safe baseline).
    public borrowing func element(at relativeOffset: Int) -> Int {
        buffer[lower.offset + relativeOffset]
    }

    /// Within-scope indexed access keyed by a ~Escapable `Cursor`. The cursor is passed
    /// by value (subscripts reject the `borrowing` keyword); the result is `Int`
    /// (Escapable), so no lifetime escapes — distinguishing this from the ~Escapable-
    /// RETURNING producer subscript, which is obstructed (see SubscriptProducerProbe).
    public subscript(at position: Cursor) -> Int {
        buffer[position.offset]
    }

    public var count: Int { upper.offset - lower.offset }
}

// MARK: - The borrowing-bounds producing subscript (never constructs a Range)

public extension Base {
    /// The "borrowing-bounds" producer: `base.slice(from: lo, upTo: hi)`. A `func` (NOT a
    /// subscript) because (a) subscripts reject the `borrowing` ownership keyword on
    /// parameters, and (b) a subscript whose getter returns a ~Escapable value cannot
    /// thread the bounds' lifetimes through its compiler-generated `get` — both obstructions
    /// are captured in SubscriptProducerProbe. It constructs NO `Range`: the view stores the
    /// two bounds directly. The result's lifetime is the union of the two bound cursors'
    /// lifetimes, so the producer carries `@_lifetime(copy lower, copy upper)` — matching
    /// `ScopedSlice.init`. The unsafe `buffer` (from `self`) is Escapable and contributes no
    /// lifetime obligation; escape protection flows transitively through the bounds.
    @_lifetime(copy lower, copy upper)
    func slice(from lower: borrowing Cursor, upTo upper: borrowing Cursor) -> ScopedSlice {
        ScopedSlice(buffer: self.buffer, lower: lower, upper: upper)
    }
}
