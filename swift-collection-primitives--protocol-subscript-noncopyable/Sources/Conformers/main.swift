// MARK: - Incremental Construction: Find the production-specific trigger
// Purpose: The cross-module experiment with top-level protocols passed.
//          Production fails. Incrementally add production factors:
//          V1: Top-level protocols (baseline — CONFIRMED working)
//          V3: Nested protocols (Collection.Protocol / Collection.Bidir)
//          V4: Nested protocols + nested conformer (Arr<Element>.Static)
//          V5: Nested + dual conformance (Collection.Indexed + Collection.Bidir)
//          V6: Nested + dual conformance + nested conformer
//
// Toolchain: swift-6.2-DEVELOPMENT-SNAPSHOT-2025-05-25-a (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: (pending)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-02-23

import Protocols

// ============================================================================
// MARK: - V1: Top-level Bidirectional (baseline)
// ============================================================================

struct Container1<T: ~Copyable>: ~Copyable {
    let storage: UnsafeMutablePointer<T>
    let count: Int
}

extension Container1: Bidirectional where T: ~Copyable {
    var startIndex: PhantomIndex<T> { PhantomIndex(position: 0) }
    var endIndex: PhantomIndex<T> { PhantomIndex(position: count) }

    subscript(_ position: PhantomIndex<T>) -> T {
        _read { yield unsafe storage[position.position] }
    }

    func index(after i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position + 1)
    }

    func index(before i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position - 1)
    }
}

print("V1: Top-level Bidirectional — OK")

// ============================================================================
// MARK: - V3: Nested protocols (Collection.Protocol / Collection.Bidir)
// Hypothesis: Nesting protocols inside a namespace enum triggers the issue.
// ============================================================================

struct Container3<T: ~Copyable>: ~Copyable {
    let storage: UnsafeMutablePointer<T>
    let count: Int
}

extension Container3: Collection.Bidir where T: ~Copyable {
    var startIndex: PhantomIndex<T> { PhantomIndex(position: 0) }
    var endIndex: PhantomIndex<T> { PhantomIndex(position: count) }

    subscript(_ position: PhantomIndex<T>) -> T {
        _read { yield unsafe storage[position.position] }
    }

    func index(after i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position + 1)
    }

    func index(before i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position - 1)
    }
}

print("V3: Nested protocols (Collection.Bidir) — OK")

// ============================================================================
// MARK: - V4: Nested protocols + nested conformer (Arr<T>.Static)
// Hypothesis: Nested type inside generic enum triggers the issue.
// ============================================================================

extension Arr where Element: ~Copyable {
    public struct Static<let capacity: Int>: ~Copyable {
        let storage: UnsafeMutablePointer<Element>
        var _count: Int
    }
}

extension Arr.Static: Collection.Bidir where Element: ~Copyable {
    public var startIndex: PhantomIndex<Element> { PhantomIndex(position: 0) }
    public var endIndex: PhantomIndex<Element> { PhantomIndex(position: _count) }

    public subscript(_ position: PhantomIndex<Element>) -> Element {
        _read { yield unsafe storage[position.position] }
    }

    public func index(after i: PhantomIndex<Element>) -> PhantomIndex<Element> {
        PhantomIndex(position: i.position + 1)
    }

    public func index(before i: PhantomIndex<Element>) -> PhantomIndex<Element> {
        PhantomIndex(position: i.position - 1)
    }
}

print("V4: Nested protocols + nested conformer — OK")

// ============================================================================
// MARK: - V5: Nested + dual conformance (Collection.Indexed + Collection.Bidir)
// Hypothesis: Dual conformance to Indexed (no Element) and Bidir (has Element)
//             triggers an implicit Copyable requirement.
// ============================================================================

struct Container5<T: ~Copyable>: ~Copyable {
    let storage: UnsafeMutablePointer<T>
    let count: Int
}

extension Container5: Collection.Indexed where T: ~Copyable {
    var startIndex: PhantomIndex<T> { PhantomIndex(position: 0) }
    var endIndex: PhantomIndex<T> { PhantomIndex(position: count) }
    func index(after i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position + 1)
    }
}

extension Container5: Collection.Bidir where T: ~Copyable {
    subscript(_ position: PhantomIndex<T>) -> T {
        _read { yield unsafe storage[position.position] }
    }

    func index(before i: PhantomIndex<T>) -> PhantomIndex<T> {
        PhantomIndex(position: i.position - 1)
    }
}

print("V5: Dual conformance (Collection.Indexed + Collection.Bidir) — OK")

// ============================================================================
// MARK: - V6: All factors combined — nested conformer + dual conformance
// Hypothesis: This is the full production pattern.
// ============================================================================

extension Arr where Element: ~Copyable {
    public struct Dynamic: ~Copyable {
        let storage: UnsafeMutablePointer<Element>
        var _count: Int
    }
}

extension Arr.Dynamic: Collection.Indexed where Element: ~Copyable {
    public var startIndex: PhantomIndex<Element> { PhantomIndex(position: 0) }
    public var endIndex: PhantomIndex<Element> { PhantomIndex(position: _count) }
    public func index(after i: PhantomIndex<Element>) -> PhantomIndex<Element> {
        PhantomIndex(position: i.position + 1)
    }
}

extension Arr.Dynamic: Collection.Bidir where Element: ~Copyable {
    public subscript(_ position: PhantomIndex<Element>) -> Element {
        _read { yield unsafe storage[position.position] }
    }

    public func index(before i: PhantomIndex<Element>) -> PhantomIndex<Element> {
        PhantomIndex(position: i.position - 1)
    }
}

print("V6: Nested conformer + dual conformance — OK")

// ============================================================================
// MARK: - Results Summary
// ============================================================================
print()
print("All variants compiled successfully!")
