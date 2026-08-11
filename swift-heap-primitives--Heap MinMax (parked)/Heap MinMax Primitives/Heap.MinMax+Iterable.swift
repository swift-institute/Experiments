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

public import Iterable
public import Iterator_Chunk_Primitives
public import Heap_MinMax_Primitive
import Memory_Iterator_Primitives

// MARK: - Iterable (multipass, borrowing)
//
// `makeIterator()` is vended FOR FREE by the memory→Iterable bridge over the
// `Span.`Protocol`` conformance (type module), yielding `Iterator.Chunk`.
// `forEach` is inherited from the Iterable floor. Heap order, NOT sorted order.

extension Heap.MinMax: Iterable where Element: ~Copyable {
    @_implements(Iterable, Iterator)
    public typealias IterableIterator = Iterator_Chunk_Primitives.Iterator.Chunk<Element>
}
