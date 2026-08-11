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

public import Heap_Primitive
public import Buffer_Linear_Primitives
public import Property_Primitives
import Index_Primitives

// MARK: - Drain (Copyable)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Drains all elements, passing each to the closure with ownership.
    ///
    /// After this method returns, the heap is empty but still usable.
    /// Elements are drained in heap order, which is **not** sorted order.
    ///
    /// - Parameter body: A closure that receives each drained element with ownership.
    /// - Complexity: O(n) where n is the number of elements.
    @inlinable
    public mutating func drain(_ body: (consuming Element) -> Void) {
        _buffer.ensureUnique()
        while !_buffer.isEmpty {
            body(_buffer.remove.last())
        }
    }

    /// Drains elements from the specified end in priority order while the predicate returns true.
    ///
    /// When draining from `.min`, repeatedly peeks at and takes the minimum element.
    /// When draining from `.max`, repeatedly peeks at and takes the maximum element.
    /// The heap survives with remaining elements intact.
    ///
    /// - Parameters:
    ///   - predicate: A closure that receives a borrowed reference to the next element.
    ///     Return `true` to drain it, `false` to stop.
    ///   - position: Which end to drain from (`.min` or `.max`).
    ///   - body: A closure that receives each drained element with ownership.
    /// - Complexity: O(k log n) where k is the number of elements drained.
    @inlinable
    public mutating func drain(
        while predicate: (borrowing Element) -> Bool,
        from position: Position,
        _ body: (consuming Element) -> Void
    ) {
        _buffer.ensureUnique()
        switch position {
        case .min:
            while let element = self.min.peek, predicate(element) {
                body(self.min.take!)
            }
        case .max:
            while let element = self.max.peek, predicate(element) {
                body(self.max.take!)
            }
        }
    }
}

// MARK: - Sequence Init (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Creates a min-max heap from a sequence using O(n) heapification.
    @inlinable
    public init(_ elements: some Swift.Sequence<Element>) {
        self.init()

        for element in elements {
            _buffer.append(element)
        }

        if _buffer.count > .one {
            heapify()
        }
    }
}

// MARK: - Copy-on-Write (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func makeUnique() {
        _buffer.ensureUnique()
    }
}

// MARK: - CoW-aware Public Operations (Copyable only)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap (CoW-aware).
    @inlinable
    public mutating func push(_ element: Element) {
        _buffer.ensureUnique()
        insert(element)
    }
}

// MARK: - Equatable (Copyable only)

extension Heap.MinMax: Equatable where Element: Equatable & Copyable {
    @inlinable
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var idx: Heap<Element>.Index = .zero
        let end = lhs._buffer.count.map(Ordinal.init)
        while idx < end {
            if lhs._buffer[idx] != rhs._buffer[idx] { return false }
            idx += .one
        }
        return true
    }
}

// MARK: - Hashable (Copyable only)

extension Heap.MinMax: Hashable where Element: Hashable & Copyable {
    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(count)
        var idx: Heap<Element>.Index = .zero
        let end = _buffer.count.map(Ordinal.init)
        while idx < end {
            hasher.combine(_buffer[idx])
            idx += .one
        }
    }
}

// MARK: - ExpressibleByArrayLiteral (Copyable only)

extension Heap.MinMax: ExpressibleByArrayLiteral where Element: Copyable {
    @inlinable
    public init(arrayLiteral elements: Element...) {
        self.init(elements)
    }
}

// MARK: - CustomStringConvertible

#if !hasFeature(Embedded)
    extension Heap.MinMax: CustomStringConvertible {
        public var description: String {
            "Heap.MinMax(\(count) elements)"
        }
    }
#endif

// MARK: - Peek Accessor (non-mutating, by-copy)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Non-mutating accessor for peeking at min/max elements.
    ///
    /// Use this for read-only access:
    ///
    /// ```swift
    /// let heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.peek.min  // 1
    /// let largest = heap.peek.max   // 8
    /// ```
    @inlinable
    public var peek: Peek.Typed {
        .init(self)
    }
}

extension Property_Primitives.Property.Typed
where
    Tag == Heap<Element>.MinMax.Peek,
    Base == Heap<Element>.MinMax,
    Element: Copyable & Comparison.`Protocol`
{
    /// The minimum element, or `nil` if the heap is empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var min: Element? {
        guard base._buffer.count > .zero else { return nil }
        return base._buffer[.zero]
    }

    /// The maximum element, or `nil` if the heap is empty.
    ///
    /// - Complexity: O(1)
    @inlinable
    public var max: Element? {
        guard base._buffer.count > .zero else { return nil }
        let count = base._buffer.count
        if count == .one {
            return base._buffer[.zero]
        }
        let leftMax = Heap<Element>.Navigate.leftChildOfRoot
        if count == .one + .one {
            return base._buffer[leftMax]
        }

        let rightMax = Heap<Element>.Navigate.rightChildOfRoot
        let e1 = base._buffer[leftMax]
        let e2 = base._buffer[rightMax]
        return e1 < e2 ? e2 : e1
    }
}

// MARK: - Min Accessor (Property.Inout.Typed)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for minimum element operations.
    ///
    /// Use this to peek, pop, or take the minimum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let smallest = heap.min.peek      // 1 (without removing)
    /// let removed = try heap.min.pop()  // 1 (removes and returns)
    /// let taken = heap.min.take         // next min or nil
    /// ```
    public var min: Min.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Min.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.MinMax.Min,
    Base == Heap<Element>.MinMax,
    Element: Copyable & Comparison.`Protocol`
{
    /// Returns the minimum element without removing it.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !(base.value.isEmpty) else { return nil }
        return base.value._buffer[.zero]
    }

    /// Removes and returns the minimum element.
    ///
    /// - Returns: The minimum element.
    /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
        base.value._buffer.ensureUnique()
        guard let element = base.value.removeMin() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the minimum element, or nil if empty.
    ///
    /// - Returns: The minimum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        base.value._buffer.ensureUnique()
        return base.value.removeMin()
    }
}

// MARK: - Max Accessor (Property.Inout.Typed)

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for maximum element operations.
    ///
    /// Use this to peek, pop, or take the maximum element:
    ///
    /// ```swift
    /// var heap: Heap<Int>.MinMax = [5, 3, 8, 1]
    ///
    /// let largest = heap.max.peek       // 8 (without removing)
    /// let removed = try heap.max.pop()  // 8 (removes and returns)
    /// let taken = heap.max.take         // next max or nil
    /// ```
    public var max: Max.View {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Max.View = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.Inout.Typed
where
    Tag == Heap<Element>.MinMax.Max,
    Base == Heap<Element>.MinMax,
    Element: Copyable & Comparison.`Protocol`
{
    /// Returns the maximum element without removing it.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(1)
    @inlinable
    public var peek: Element? {
        guard !(base.value.isEmpty) else { return nil }
        let count = base.value._buffer.count
        if count == .one {
            return base.value._buffer[.zero]
        }
        let leftMax = Heap<Element>.Navigate.leftChildOfRoot
        if count == .one + .one {
            return base.value._buffer[leftMax]
        }

        let rightMax = Heap<Element>.Navigate.rightChildOfRoot
        let e1 = base.value._buffer[leftMax]
        let e2 = base.value._buffer[rightMax]
        return e1 < e2 ? e2 : e1
    }

    /// Removes and returns the maximum element.
    ///
    /// - Returns: The maximum element.
    /// - Throws: ``Heap/MinMax/Error/empty`` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public func pop() throws(Heap<Element>.MinMax.Error) -> Element {
        base.value._buffer.ensureUnique()
        guard let element = base.value.removeMax() else {
            throw .empty
        }
        return element
    }

    /// Removes and returns the maximum element, or nil if empty.
    ///
    /// - Returns: The maximum element, or `nil` if the heap is empty.
    /// - Complexity: O(log n)
    @inlinable
    public var take: Element? {
        base.value._buffer.ensureUnique()
        return base.value.removeMax()
    }
}
