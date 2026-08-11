// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Note: Heap.MinMax is declared INSIDE the Heap struct body (in Heap.swift)
// due to Swift's ~Copyable constraint propagation rules. This file contains
// nested types and extensions for the MinMax heap.

public import Heap_Primitive
public import Memory_Heap_Primitives
public import Storage_Contiguous_Primitives
import Storage_Contiguous_Primitives
public import Buffer_Linear_Primitives
public import Property_Primitives

// MARK: - MinMax Nested Types

extension Heap.MinMax {
    /// Which position in the heap to operate on (min or max).
    public enum Position: Sendable, Equatable {
        /// The minimum element.
        case min
        /// The maximum element.
        case max
    }
}

// The former `MinMax.Fixed` variant is DISSOLVED (Round M coda — the
// variant-dissolution doctrine): bounded capacity returns column-composed,
// consumer-pulled, at the heap-template round.

// MARK: - Property Typealias

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Property typealias for accessor patterns (~Copyable).
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Heap.MinMax>
}

// MARK: - Remove Accessor

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Accessor for remove operations.
    ///
    /// Use this for removal operations:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    /// heap.remove.all()                      // Remove all, release capacity
    /// heap.remove.all(keepingCapacity: true) // Remove all, keep capacity
    /// ```
    public var remove: Remove.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Remove.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.MinMax.Remove,
    Base == Heap<Element>.MinMax,
    Element: ~Copyable & Comparison.`Protocol`
{
    /// Removes all elements from the heap.
    ///
    /// - Parameter keepingCapacity: Whether to keep the current capacity.
    ///   If `true`, the heap retains its current capacity.
    ///   If `false` (default), the capacity is released.
    /// - Complexity: O(n)
    // on remove.all() + conditional buffer reassignment in deep @inlinable chain.
    @inlinable
    public func all(keepingCapacity: Bool = false) {
        base.value._buffer.remove.all()
        if !keepingCapacity {
            unsafe (base.value._buffer = Buffer<Storage<Element>.Contiguous<Memory.Heap<Element>>>.Linear(minimumCapacity: .zero))
        }
    }
}
