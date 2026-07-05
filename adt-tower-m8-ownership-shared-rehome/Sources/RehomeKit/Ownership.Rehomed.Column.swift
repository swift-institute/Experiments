// ===----------------------------------------------------------------------===//
//
// adt-tower-m8-ownership-shared-rehome — [EXP-003d]
//
// The pinned direct heap-linear column construction + the uniqueness/unshare gate + the
// CoW-checked mutation surface. Faithful trim of swift-shared-primitives'
// `Shared+Unique.swift`, re-spelled `extension Ownership.Rehomed: …`.
//
// The two init overloads split on element copyability: the `Copyable` form captures the
// column's deep-copy strategy (`clone`) so a shared box can restore uniqueness; the
// `~Copyable` form captures none (statically unique — the wrapper can never become shared).
//
// ===----------------------------------------------------------------------===//

public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Index_Primitives
public import Ownership_Box_Primitives

// MARK: - Construction (pinned per column; drain + clone strategies supplied here)

extension Ownership.Rehomed where Element: ~Copyable, B: ~Copyable {
    /// Wraps a dense heap-linear buffer as a statically-unique (move-only element) column.
    @inlinable
    public init(_ buffer: consuming Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear)
    where B == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear {
        self.init(box: Ownership.Box(buffer, drain: { $0.removeAll(keepingCapacity: true) }))
    }
}

extension Ownership.Rehomed where Element: Copyable, B: ~Copyable {
    /// Wraps a dense heap-linear buffer as a shared (CoW-capable) column.
    @inlinable
    public init(_ buffer: consuming Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear)
    where B == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear {
        self.init(box: Ownership.Box(
            buffer,
            drain: { $0.removeAll(keepingCapacity: true) },
            clone: { $0.clone() }
        ))
    }
}

// MARK: - Uniqueness

extension Ownership.Rehomed where Element: Copyable, B: ~Copyable {
    /// Whether this value holds the only reference to its backing box.
    @inlinable
    public var isUnique: Bool {
        mutating get { box.isUnique }
    }
}

extension Ownership.Rehomed where Element: ~Copyable, B: ~Copyable {
    /// The CoW restore, at the SEMANTIC boundary. Delegated to the one CoW box
    /// ([MEM-SAFE-028] / [MEM-COPY-019]): a no-op on statically-unique columns; on
    /// `Copyable`-element columns the clone strategy captured at construction restores uniqueness.
    @inlinable
    @discardableResult
    public mutating func ensureUnique() -> Bool {
        box.ensureUnique()
    }
}

// MARK: - The CoW-checked mutation surface (heap-linear column)

extension Ownership.Rehomed where Element: ~Copyable, B: ~Copyable {
    /// Appends an element (grows as needed). CoW-checked for Copyable elements.
    @inlinable
    public mutating func append(_ element: consuming Element)
    where B == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear, Element: Copyable {
        ensureUnique()
        box.unguarded.append(element)
    }

    /// Removes and returns the last element. CoW-checked for Copyable elements.
    @inlinable
    public mutating func removeLast() -> Element
    where B == Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<Element>>.Linear, Element: Copyable {
        ensureUnique()
        return box.unguarded.removeLast()
    }
}
