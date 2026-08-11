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

internal import Property_Primitives
import Sequence_Primitives
public import Heap_MinMax_Primitive

// MARK: - Sequence.Drain.Protocol Conformance

extension Heap.MinMax: Sequence.Drain.`Protocol` where Element: Copyable & Comparison.`Protocol` {
    // drain(_ body:) method already exists in Heap.MinMax Copyable.swift (type module).
    // This extension declares conformance to the protocol.
}

// MARK: - Drain Property Accessor

extension Heap.MinMax where Element: Copyable & Comparison.`Protocol` {
    /// Accessor for drain operations.
    public var drain: Property<Sequence.Drain>.Inout {
        mutating _read {
            yield Property<Sequence.Drain>.Inout(&self)
        }
        mutating _modify {
            var accessor = Property<Sequence.Drain>.Inout(&self)
            yield &accessor
        }
    }
}
