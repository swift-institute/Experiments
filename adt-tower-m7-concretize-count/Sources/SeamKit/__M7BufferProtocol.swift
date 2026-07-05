// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute Experiments corpus.
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//
//
// M7 concretized replica seam — see Research/adt-tower.md §4.2.
//
// Toolchain: swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
//            Target: arm64-apple-macosx26.0
// Platform:  macOS 26 (arm64)
// Status:    CONFIRMED — concretized `count: Index<Element>.Count`; unconstrained
//            `isEmpty` default (`count == .zero`) compiles; the sole associated
//            type is `Element: ~Copyable`. Build Succeeded (see main.swift header).
//
// Dep-surface probe: this target imports ONLY `Index_Primitives` and is built with
// InternalImportsByDefault + MemberImportVisibility. If it compiles, the M7 claim
// "no direct Carrier_Protocol / Cardinal_Primitive import needed — `.zero`/`==`
// resolve via Index_Primitives' re-exports" holds under strict conditions.

public import Index_Primitives

// MARK: - __M7BufferProtocol (concretized replica of __BufferProtocol)

/// Concretized observability seam.
///
/// M7 amendment vs the production `__BufferProtocol`:
/// - DELETES `associatedtype Count: Carrier.`Protocol`<Cardinal>`.
/// - `Element: ~Copyable` is the ONLY associated type.
/// - `count` is the CONCRETE `Index<Element>.Count` (= `Tagged<Element, Cardinal>`).
public protocol __M7BufferProtocol: ~Copyable, ~Escapable {
    /// The element type stored in the buffer.
    associatedtype Element: ~Copyable

    /// The number of elements logically held, in the concrete element domain.
    var count: Index<Element>.Count { get }

    /// Whether the buffer has no elements.
    var isEmpty: Bool { get }
}

// MARK: - Unconstrained Derived-Observable Default

extension __M7BufferProtocol where Self: ~Copyable & ~Escapable {
    /// Whether the buffer has no elements.
    ///
    /// M7's payoff (resolves W18): this default is now UNCONSTRAINED — no
    /// `Count == Index<Element>.Count` pin is needed because `count` is already
    /// concrete. The concrete `Index<Element>.Count` (= `Tagged<Element, Cardinal>`)
    /// surfaces both `==` (Tagged.Equatable over `Underlying: Equatable`) and
    /// `.zero` (Carrier.`Protocol` where `Underlying == Cardinal`), and both
    /// resolve via `Index_Primitives`' `@_exported` re-exports.
    @inlinable
    public var isEmpty: Bool { count == .zero }
}
