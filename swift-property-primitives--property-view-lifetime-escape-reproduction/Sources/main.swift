// MARK: - Property.View / Ownership.Inout / Ownership.Borrow Nested Coroutine Lifetime-Escape Reproduction
//
// Purpose: Isolate the Swift 6.3.1 `error: lifetime-dependent value escapes its
// scope` emitted at `base.value._buffer.peek.front` in the refactored
// Property.View family. Chain depth ≥ 6: Property.View.Typed →
// Ownership.Inout → stored-property → Property.View.Read.Typed →
// Ownership.Borrow → terminal Copyable Element.
//
// Toolchain: Apple Swift 6.3.1 (swiftlang-6.3.1.1.2 clang-2100.0.123.102)
// Platform: macOS 26 (arm64)
//
// Status: FIXED — V12 landed in swift-ownership-primitives/Ownership.Inout.swift
//   (split Ownership.Inout.value: `where Value: Copyable { get + nonmutating _modify }`
//   and `where Value: ~Copyable { _read + nonmutating _modify }`).
// Result: REPRODUCED (V3 / V2.5a) → FIX FOUND (V12) — see handoff doc.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-04-23
//
// See also:
// - /Users/coen/Developer/HANDOFF-property-view-ownership-inout-lifetime-chain.md
//   (Findings section — full probe ladder V1–V12 + structural-trigger narrowing)
// - ../property-view-ownership-inout-factoring/ (prior refactor-shape experiment)
//
// Variant ladder summary:
//
//   V1    — inline minimal types                   → could-not-reproduce (shape too shallow)
//   V2    — parallel MyInner + real primitives     → could-not-reproduce (conditional-Copyable-via-extension alone
//                                                    is NOT sufficient — verified V2.5b below)
//   V2.5a — parallel + class reference field       → REPRODUCES — the class reference is the structural trigger
//   V2.5b — parallel + value-type header field     → could-not-reproduce — value-type aggregation is not the trigger
//   V3    — MyDeque wrapping real Buffer.Ring      → REPRODUCES (baseline, matches queue-primitives failure)
//   V4    — withExtendedLifetime at call site      → FAILS
//   V5    — free borrowing helper function         → compiles (= rejected workaround shape)
//   V6    — intermediate let binding               → FAILS
//   V7    — `copy` on local binding                → FAILS
//   V8    — IIFE closure wrap                      → FAILS
//   V9    — no isEmpty guard (bare return)         → FAILS (rules out guard as factor)
//   V10   — @_lifetime(copy self) on _read         → REJECTED ("invalid lifetime dependence on an Escapable result")
//   V11   — @_lifetime(borrow self) on _read       → REJECTED (same)
//   V12   — Copyable/~Copyable accessor split      → COMPILES + ALL TESTS PASS (fix)
//
// Structural trigger (V2.5 narrowing): a class reference field inside the
// stored `_buffer` is what tips the compound-lifetime tagging over the edge.
// Conditional-Copyable-via-extension alone (V2) and value-type header
// aggregation (V2.5b) do not reproduce. The real Buffer.Ring's
// `Storage<Element>.Heap` (class-backed) is the load-bearing factor in V3.
//
// To re-verify reproduction: temporarily revert V12 in
// swift-ownership-primitives/Sources/Ownership Primitives/Ownership.Inout.swift
// (collapse the Copyable/~Copyable extensions back into a single
// `where Value: ~Copyable` extension with unified `_read + nonmutating _modify`),
// then `rm -rf .build && swift build`. The V3 `peek` and V2.5a `peek`
// accessors below will both emit `error: lifetime-dependent value escapes its scope`.

public import Property_View_Primitives
public import Property_View_Read_Primitives
public import Property_Primitives
public import Ownership_Primitives
public import Buffer_Ring_Primitives

// =============================================================================
// V3 — baseline reproducer (real Buffer<Element>.Ring)
// =============================================================================

public struct MyDeque<Element: ~Copyable> {
    @usableFromInline
    package var _buffer: Buffer<Element>.Ring

    @inlinable
    public init() {
        self._buffer = Buffer<Element>.Ring(minimumCapacity: .zero)
    }

    public enum Front {}

    public typealias Property<Tag> = Property_Primitives.Property<Tag, Self>
}

extension MyDeque: Copyable where Element: Copyable {}

extension MyDeque where Element: ~Copyable {
    @inlinable
    public var isEmpty: Bool { _buffer.isEmpty }

    @inlinable
    public var front: Property<Front>.View.Typed<Element> {
        mutating _read {
            yield unsafe .init(&self)
        }
        mutating _modify {
            var view: Property<Front>.View.Typed<Element> = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == MyDeque<Element>.Front,
      Base == MyDeque<Element>,
      Element: Copyable
{
    @inlinable
    public var peek: Element? {
        guard !base.value.isEmpty else { return nil }
        return base.value._buffer.peek.front
    }
}

// =============================================================================
// V2.5a — parallel primitives + class-reference field (REPRODUCES pre-V12)
// Retained as minimum-trigger reduction.
// =============================================================================

public final class V25aStorage {
    @usableFromInline let element: UnsafeMutableRawPointer
    @inlinable public init(_ p: UnsafeMutableRawPointer) { unsafe (self.element = p) }
}

public struct V25aInner<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    internal let _storage: V25aStorage

    @inlinable
    public init(_ pointer: UnsafeMutablePointer<Element>) {
        unsafe (self._storage = V25aStorage(.init(pointer)))
    }

    @inlinable public var isEmpty: Bool { false }
    public enum Peek {}
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Self>
}

extension V25aInner: Copyable where Element: Copyable {}

extension V25aInner where Element: ~Copyable {
    @inlinable
    public var peek: Property<Peek>.View.Read.Typed<Element> {
        _read { yield Property<Peek>.View.Read.Typed(self) }
    }
}

extension Property_Primitives.Property.View.Read.Typed
where Tag == V25aInner<Element>.Peek,
      Base == V25aInner<Element>,
      Element: Copyable
{
    @inlinable
    public var front: Element {
        unsafe base.value._storage.element.assumingMemoryBound(to: Element.self).pointee
    }
}

public struct V25aOuter<Element: ~Copyable>: ~Copyable {
    @usableFromInline internal var _buffer: V25aInner<Element>
    @inlinable public init(buffer: consuming V25aInner<Element>) { self._buffer = consume buffer }
    @inlinable public var isEmpty: Bool { _buffer.isEmpty }
    public enum Front {}
    public typealias Property<Tag> = Property_Primitives.Property<Tag, Self>
}

extension V25aOuter: Copyable where Element: Copyable {}

extension V25aOuter where Element: ~Copyable {
    @inlinable
    public var front: Property<Front>.View.Typed<Element> {
        mutating _read { yield unsafe .init(&self) }
        mutating _modify {
            var view: Property<Front>.View.Typed<Element> = unsafe .init(&self)
            yield &view
        }
    }
}

extension Property_Primitives.Property.View.Typed
where Tag == V25aOuter<Element>.Front,
      Base == V25aOuter<Element>,
      Element: Copyable
{
    @inlinable
    public var peek: Element? {
        guard !base.value.isEmpty else { return nil }
        return base.value._buffer.peek.front
    }
}

// =============================================================================
// Driver
// =============================================================================

var deque = MyDeque<Int>()
if let value = deque.front.peek {
    print("V3 peek = \(value)")
} else {
    print("V3 empty (expected — capacity 0)")
}

var storage = 42
withUnsafeMutablePointer(to: &storage) { p in
    let outer = V25aOuter<Int>(buffer: V25aInner(p))
    _ = outer
    print("V2.5a harness built")
}
