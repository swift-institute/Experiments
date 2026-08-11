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

extension Heap.MinMax {
    /// Errors that can occur during min-max heap operations.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// An operation was attempted on an empty heap.
        case empty
    }
}
