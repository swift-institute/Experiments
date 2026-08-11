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

public import Heap_MinMax_Primitive

// MARK: - removeAll()

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Removes all elements from the heap.
    @inlinable
    public mutating func removeAll() {
        remove.all(keepingCapacity: false)
    }
}
