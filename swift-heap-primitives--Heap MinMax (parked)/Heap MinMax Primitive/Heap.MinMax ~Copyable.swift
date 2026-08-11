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
public import Buffer_Linear_Primitive
public import Buffer_Linear_Primitives
import Index_Primitives

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Namespace for minimum element operations.
    public enum Min {
        public typealias View = Heap<Element>.MinMax.Property<Min>.Inout.Typed<Element>
    }

    /// Namespace for maximum element operations.
    public enum Max {
        public typealias View = Heap<Element>.MinMax.Property<Max>.Inout.Typed<Element>
    }

    /// Namespace for remove operations.
    public enum Remove {
        public typealias View = Heap<Element>.MinMax.Property<Remove>.Inout.Typed<Element>
    }
}

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Namespace for peek operations (Copyable — returns elements by copy).
    public enum Peek {
        public typealias Typed = Heap<Element>.MinMax.Property<Peek>.Typed<Element>
    }
}

// MARK: - Properties

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// The number of elements in the heap.
    @inlinable
    public var count: Heap.Index.Count { _buffer.count }

    /// Whether the heap is empty.
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }
}

// MARK: - MinMax Level Classification

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Determines whether the given index is on a min level in the min-max heap.
    ///
    /// Level 0 (root) is min, level 1 is max, level 2 is min, etc.
    /// Raw `Int` arithmetic is principled: binary logarithm requires it ([IMPL-001]).
    /// Confined to this static method per [PATTERN-017].
    @inlinable
    package static func isMinLevel(for index: Heap.Index) -> Bool {
        let raw = Int(bitPattern: index)
        return (raw &+ 1)._binaryLogarithm() & 0b1 == 0
    }
}

extension Int {
    @usableFromInline
    package func _binaryLogarithm() -> Int {
        precondition(self > 0)
        return Int.bitWidth - 1 - self.leadingZeroBitCount
    }
}

// MARK: - Core Operations (Internal)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func appendWithoutHeapify(_ element: consuming Element) {
        _buffer.append(element)
    }

    @usableFromInline
    package mutating func insert(_ element: consuming Element) {
        let insertionIndex = _buffer.count.map(Ordinal.init)
        _buffer.append(element)
        bubbleUp(insertionIndex)
    }

    // on multiple _buffer accessor chains (swap + remove + trickle) in deep @inlinable chain.
    @usableFromInline
    package mutating func removeMin() -> Element? {
        guard !isEmpty else { return nil }

        if _buffer.count == .one {
            return _buffer.remove.last()
        }

        let lastIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)
        _buffer.swap(at: .zero, with: lastIndex)
        let removed = _buffer.remove.last()
        trickleDownMin(.zero)
        return removed
    }

    // on multiple _buffer accessor chains (swap + remove + trickle) in deep @inlinable chain.
    @usableFromInline
    package mutating func removeMax() -> Element? {
        guard !isEmpty else { return nil }

        if _buffer.count == .one {
            return _buffer.remove.last()
        }

        if _buffer.count == .one + .one {
            return _buffer.remove.last()
        }

        let leftMax = Heap.Navigate.leftChildOfRoot
        let rightMax = Heap.Navigate.rightChildOfRoot
        let maxIndex =
            _buffer[leftMax] < _buffer[rightMax]
            ? rightMax
            : leftMax

        let lastIndex = _buffer.count.subtract.saturating(.one).map(Ordinal.init)
        _buffer.swap(at: maxIndex, with: lastIndex)
        let removed = _buffer.remove.last()

        if maxIndex < _buffer.count {
            trickleDownMax(maxIndex)
        }

        return removed
    }
}

// MARK: - Bubble Up (MinMax Heap)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func bubbleUp(_ startIndex: Heap.Index) {
        guard startIndex > .zero else { return }

        let nav = Heap.Navigate(_count: _buffer.count)
        guard let parentIndex = nav.parent(of: startIndex) else { return }

        var current = startIndex
        var currentIsMin = Self.isMinLevel(for: startIndex)

        let nodeIsLess = _buffer[current] < _buffer[parentIndex]
        let parentIsLess = _buffer[parentIndex] < _buffer[current]

        if (currentIsMin && parentIsLess)
            || (!currentIsMin && nodeIsLess)
        {
            _buffer.swap(at: current, with: parentIndex)
            current = parentIndex
            currentIsMin = !currentIsMin
        }

        if currentIsMin {
            while let p = nav.parent(of: current),
                let gpIndex = nav.parent(of: p)
            {
                guard !(_buffer[gpIndex] < _buffer[current]) else { break }
                _buffer.swap(at: current, with: gpIndex)
                current = gpIndex
            }
        } else {
            while let p = nav.parent(of: current),
                let gpIndex = nav.parent(of: p)
            {
                guard !(_buffer[current] < _buffer[gpIndex]) else { break }
                _buffer.swap(at: current, with: gpIndex)
                current = gpIndex
            }
        }
    }
}

// MARK: - Trickle Down Min

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func trickleDownMin(_ startIndex: Heap.Index) {
        var current = startIndex
        let nav = Heap.Navigate(_count: _buffer.count)

        while true {
            guard let leftIndex = nav.child(.left, of: current) else { break }

            var smallest = current

            if _buffer[leftIndex] < _buffer[smallest] {
                smallest = leftIndex
            }
            if let rightIndex = nav.child(.right, of: current) {
                if _buffer[rightIndex] < _buffer[smallest] {
                    smallest = rightIndex
                }
            }

            // Grandchildren: 4 consecutive positions starting from left child's left child.
            let firstGCIndex: Heap.Index?
            if let gcStart = nav.child(.left, of: leftIndex) {
                firstGCIndex = gcStart
                var gcIndex = gcStart
                for _ in 0..<4 {
                    guard nav.isValid(gcIndex) else { break }
                    if _buffer[gcIndex] < _buffer[smallest] {
                        smallest = gcIndex
                    }
                    gcIndex += .one
                }
            } else {
                firstGCIndex = nil
            }

            if smallest == current { break }

            _buffer.swap(at: current, with: smallest)

            if let firstGCIndex, smallest >= firstGCIndex {
                // Grandchild case: restore parent invariant, then continue.
                if let parentOfSmallest = nav.parent(of: smallest) {
                    if _buffer[parentOfSmallest] < _buffer[smallest] {
                        _buffer.swap(at: smallest, with: parentOfSmallest)
                    }
                }
                current = smallest
            } else {
                break
            }
        }
    }
}

// MARK: - Trickle Down Max

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    @usableFromInline
    package mutating func trickleDownMax(_ startIndex: Heap.Index) {
        var current = startIndex
        let nav = Heap.Navigate(_count: _buffer.count)

        while true {
            guard let leftIndex = nav.child(.left, of: current) else { break }

            var largest = current

            if _buffer[largest] < _buffer[leftIndex] {
                largest = leftIndex
            }
            if let rightIndex = nav.child(.right, of: current) {
                if _buffer[largest] < _buffer[rightIndex] {
                    largest = rightIndex
                }
            }

            // Grandchildren: 4 consecutive positions starting from left child's left child.
            let firstGCIndex: Heap.Index?
            if let gcStart = nav.child(.left, of: leftIndex) {
                firstGCIndex = gcStart
                var gcIndex = gcStart
                for _ in 0..<4 {
                    guard nav.isValid(gcIndex) else { break }
                    if _buffer[largest] < _buffer[gcIndex] {
                        largest = gcIndex
                    }
                    gcIndex += .one
                }
            } else {
                firstGCIndex = nil
            }

            if largest == current { break }

            _buffer.swap(at: current, with: largest)

            if let firstGCIndex, largest >= firstGCIndex {
                // Grandchild case: restore parent invariant, then continue.
                if let parentOfLargest = nav.parent(of: largest) {
                    if _buffer[largest] < _buffer[parentOfLargest] {
                        _buffer.swap(at: largest, with: parentOfLargest)
                    }
                }
                current = largest
            } else {
                break
            }
        }
    }
}

// MARK: - Heapify (Level-Order for MinMax)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Converts storage to valid min-max heap in O(n).
    ///
    /// Uses level-order Floyd's algorithm. Raw `Int` arithmetic for level-based
    /// position ranges is principled: power-of-2 tree math requires it ([IMPL-001]).
    @usableFromInline
    package mutating func heapify() {
        let rawCount = Int(bitPattern: _buffer.count)
        guard rawCount > 1 else { return }

        let limit = rawCount / 2
        var level = limit._binaryLogarithm()

        while level >= 0 {
            let isMin = level & 0b1 == 0
            let firstPos = UInt((1 &<< level) &- 1)
            let lastPos = UInt(Swift.min((1 &<< (level &+ 1)) &- 2, limit - 1))

            var pos = firstPos
            while pos <= lastPos {
                let index = Heap.Index(_unchecked: Ordinal(pos))
                if isMin {
                    trickleDownMin(index)
                } else {
                    trickleDownMax(index)
                }
                pos &+= 1
            }
            level -= 1
        }
    }
}

// MARK: - Public Mutating Operations

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Inserts an element into the heap.
    @inlinable
    public mutating func push(_ element: consuming Element) {
        insert(element)
    }
}

// MARK: - Borrowing Access (~Copyable elements)

extension Heap.MinMax where Element: ~Copyable & Comparison.`Protocol` {
    /// Provides borrowing access to the minimum element.
    @inlinable
    public func withMin<R>(_ body: (borrowing Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        return body(_buffer[.zero])
    }

    /// Provides borrowing access to the maximum element.
    @inlinable
    public func withMax<R>(_ body: (borrowing Element) -> R) -> R? {
        guard !isEmpty else { return nil }
        if _buffer.count == .one { return body(_buffer[.zero]) }
        if _buffer.count == .one + .one {
            return body(_buffer[Heap.Navigate.leftChildOfRoot])
        }

        let leftMax = Heap.Navigate.leftChildOfRoot
        let rightMax = Heap.Navigate.rightChildOfRoot
        let maxIndex =
            _buffer[leftMax] < _buffer[rightMax]
            ? rightMax
            : leftMax
        return body(_buffer[maxIndex])
    }

    // Note: borrowing `forEach` is inherited from the Iterable floor (ops module).
}
