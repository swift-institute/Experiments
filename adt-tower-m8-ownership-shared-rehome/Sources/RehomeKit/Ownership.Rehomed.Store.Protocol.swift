// ===----------------------------------------------------------------------===//
//
// adt-tower-m8-ownership-shared-rehome — [EXP-003d]
//
// The seam conformances (SELF-GATING mutators) with their FULL declared bounds. Faithful trim
// of swift-shared-primitives' `Shared+Store.Protocol.swift`, re-spelled
// `extension Ownership.Rehomed: …`. Every MUTATING seam op restores uniqueness FIRST
// (`ensureUnique()`) so a shared box is never mutated while shared (Sendable soundness); reads
// stay free.
//
// ===----------------------------------------------------------------------===//

public import Store_Protocol_Primitives
public import Buffer_Protocol_Primitives
public import Index_Primitives
public import Ownership_Box_Primitives

extension Ownership.Rehomed: Store.`Protocol` where Element: ~Copyable, B: ~Copyable {
    @inlinable
    public var capacity: Index<Element>.Count { box.unguarded.capacity }

    @inlinable
    public subscript(slot: Index<Element>) -> Element {
        _read { yield box.unguarded[slot] }
        _modify {
            ensureUnique()
            yield &box.unguarded[slot]
        }
    }

    @inlinable
    public mutating func initialize(at slot: Index<Element>, to element: consuming Element) {
        ensureUnique()
        box.unguarded.initialize(at: slot, to: element)
    }

    @inlinable
    public mutating func move(at slot: Index<Element>) -> Element {
        ensureUnique()
        return box.unguarded.move(at: slot)
    }

    /// The semantic mutation gate — restores uniqueness before generic seam writes.
    @inlinable
    public mutating func prepareForMutation() {
        ensureUnique()
    }
}

extension Ownership.Rehomed: Buffer.`Protocol` where Element: ~Copyable, B: ~Copyable {
    public typealias Count = Index<Element>.Count

    /// The number of live elements (forwarded from the wrapped buffer's cursor).
    @inlinable
    public var count: Index<Element>.Count { box.unguarded.count }
}
