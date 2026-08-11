// TypedConformances.swift
// Mimics finite-collection-primitives — the integration package.
//
// Provides:
// 1. Collection conformance for Enumeration (with typed Index<Element>)
// 2. Default allCases on Enumerable (returns Enumeration<Self>)
// 3. Retroactive CaseIterable for concrete types

import CoreFinite
import TypedIndex

// MARK: - Enumeration: Collection (typed Index<Element>)

extension CoreFinite.Enumeration: Collection {
    public typealias Index = TypedIndex.Index<Element>

    @inlinable
    public var startIndex: TypedIndex.Index<Element> {
        TypedIndex.Index(0)
    }

    @inlinable
    public var endIndex: TypedIndex.Index<Element> {
        TypedIndex.Index(Element.count)
    }

    @inlinable
    public subscript(position: TypedIndex.Index<Element>) -> Element {
        Element(__unchecked: (), ordinal: position.position)
    }

    @inlinable
    public func index(after i: TypedIndex.Index<Element>) -> TypedIndex.Index<Element> {
        TypedIndex.Index(i.position + 1)
    }
}

// MARK: - Enumeration: BidirectionalCollection

extension CoreFinite.Enumeration: BidirectionalCollection {
    @inlinable
    public func index(before i: TypedIndex.Index<Element>) -> TypedIndex.Index<Element> {
        TypedIndex.Index(i.position - 1)
    }
}

// MARK: - Enumeration: RandomAccessCollection

extension CoreFinite.Enumeration: RandomAccessCollection {
    @inlinable
    public var count: Int { Element.count }

    @inlinable
    public func distance(from start: TypedIndex.Index<Element>, to end: TypedIndex.Index<Element>) -> Int {
        end.position - start.position
    }

    @inlinable
    public func index(_ i: TypedIndex.Index<Element>, offsetBy distance: Int) -> TypedIndex.Index<Element> {
        TypedIndex.Index(i.position + distance)
    }

    @inlinable
    public func index(
        _ i: TypedIndex.Index<Element>,
        offsetBy distance: Int,
        limitedBy limit: TypedIndex.Index<Element>
    ) -> TypedIndex.Index<Element>? {
        let result = i.position + distance
        if distance >= 0 {
            return result <= limit.position ? TypedIndex.Index(result) : nil
        } else {
            return result >= limit.position ? TypedIndex.Index(result) : nil
        }
    }
}

// MARK: - Default allCases for all Enumerable types

extension CoreFinite.Enumerable {
    /// All values of this type (zero-allocation RandomAccessCollection).
    public static var allCases: CoreFinite.Enumeration<Self> {
        CoreFinite.Enumeration()
    }
}

// MARK: - Cross-module witness matching for Sequence protocol

/// Tests that makeIterator() from CoreFinite is found as witness.
public protocol TypedSequence {
    associatedtype Iterator: IteratorProtocol
    func makeIterator() -> Iterator
}

extension CoreFinite.Enumeration: TypedSequence {}
