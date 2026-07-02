// MARK: - The worked example — a NEW ADT (`Heap`, a binary min priority queue) + two
//         allocation variants, against the REAL upstream tower ([EXP-020]).
//
// Purpose:   Measure the marginal declaration cost of (a) a new ADT and (b) a new
//            allocation variant under the proposed tower shape:
//              1. thin bound-free carrier `__Heap<S: ~Copyable>` (hoisted per
//                 [API-IMPL-009]/[PKG-NAME-006]; public spelling is the alias);
//              2. semantic ops written ONCE, generic over the Store/Buffer seams
//                 (the [DS-024] ledger laws keep `count` honest through them),
//                 gated by the seam's `prepareForMutation()` (CoW-correct), with
//                 FULL ~Copyable element support via `Comparison.Protocol`;
//              3. growth written ONCE, pinned to the linear column GENERIC over the
//                 allocation (`Resource: Memory.Growable` — heap AND small);
//              4. the canonical type and every allocation variant as typealias
//                 front-doors (`Heap<E>`, `Heap<E>.Small<n>`) — Nest.Name-clean
//                 per [API-NAME-001], the sanctioned generic-instantiation-alias
//                 exception of [API-NAME-004].
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101), macOS 26 (arm64), Xcode 26.6
// Platform:  macOS 26 (arm64)
//
// Result:    CONFIRMED — compiles + runs against the real upstream columns, debug AND
//            release, cross-module, identical output:
//              canonical: [3, 3, 7, 19, 25, 42] · small: min=1 then 1 2 8 9 ·
//              jobs(~Copyable Job element): first=1 remaining=2
//            SIL gate (-O client): ZERO witness_method on tower operations — the 9
//            residual sites are print/stdlib-Array machinery + Job's own conformance
//            thunk definitions; 52 specialized function_refs carry the tower calls.
//            THE MEASURED DECLARATION COST (the Q9 metric):
//              new ADT total: 105 code lines, 1 file, 1 target, 0 new packages
//                §1 carrier 10 · §2 semantic ops 62 (the irreducible algorithm)
//                §3 growth 15 · §4 front doors 6 · imports 12
//              marginal ALLOCATION VARIANT: 3 code lines (one constrained typealias),
//                ZERO op code, ZERO conformance code — Heap<Int>.Small<64> works with
//                every op §2/§3 already defines.
//            Honest residuals: (a) a Shared (CoW) column front door would add one
//            pinned growth twin (pop/observability already CoW-correct via the seam's
//            prepareForMutation gate); (b) Memory.Small's n is a BYTE budget;
//            (c) Comparison SLI conformances carry Int's `<` — full ~Copyable elements
//            conform Comparison.`Protocol` directly (Job in client).
// Date:      2026-07-02

public import Buffer_Primitive
public import Buffer_Linear_Primitive
public import Buffer_Protocol_Primitives
public import Store_Protocol_Primitives
public import Storage_Primitive
public import Storage_Contiguous_Primitives
public import Memory_Heap_Primitives
public import Memory_Small_Primitives
public import Memory_Allocator_Primitive
public import Memory_Allocator_Protocol_Primitives
public import Index_Primitives
public import Comparison_Primitives

// MARK: 1. The carrier (thin, bound-free; hoisted)

public struct __Heap<S: ~Copyable>: ~Copyable {
    @usableFromInline
    package var column: S

    @inlinable
    public init(column: consuming S) { self.column = column }

    @inlinable
    public consuming func take() -> S { column }
}

extension __Heap: Copyable where S: Copyable {}
extension __Heap: Sendable where S: Sendable & ~Copyable {}

// MARK: 2. Semantic ops — written ONCE over the seams (any conforming column)

extension __Heap where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index<S.Element>.Count {

    @inlinable
    public var count: Index<S.Element>.Count { column.count }

    @inlinable
    public var isEmpty: Bool { column.isEmpty }

    /// Borrowing access to the minimum element.
    ///
    /// - Precondition: The heap must not be empty.
    @inlinable
    public var min: S.Element {
        _read { yield column[0] }
    }
}

extension __Heap where S: ~Copyable, S: Store.`Protocol` & Buffer.`Protocol`,
    S.Count == Index<S.Element>.Count, S.Element: Comparison.`Protocol` {

    /// Runtime slot coordinate (heap-order arithmetic happens in raw `Int`).
    @inlinable
    func slot(_ k: Int) -> Index<S.Element> {
        Index(Ordinal(UInt(k)))
    }

    /// Exchanges two initialized slots through the seam's move/initialize transitions.
    @inlinable
    mutating func exchange(_ i: Index<S.Element>, _ j: Index<S.Element>) {
        let a = column.move(at: i)
        let b = column.move(at: j)
        column.initialize(at: i, to: b)
        column.initialize(at: j, to: a)
    }

    /// Restores the heap invariant upward from raw slot `k`.
    @inlinable
    mutating func siftUp(from k: Int) {
        var child = k
        while child > 0 {
            let parent = (child - 1) / 2
            if column[slot(child)] < column[slot(parent)] {
                exchange(slot(child), slot(parent))
                child = parent
            } else { break }
        }
    }

    /// Restores the heap invariant downward from the root over `n` live slots.
    @inlinable
    mutating func siftDown(over n: Int) {
        var parent = 0
        while true {
            let l = 2 * parent + 1
            let r = l + 1
            var smallest = parent
            if l < n, column[slot(l)] < column[slot(smallest)] { smallest = l }
            if r < n, column[slot(r)] < column[slot(smallest)] { smallest = r }
            if smallest == parent { return }
            exchange(slot(parent), slot(smallest))
            parent = smallest
        }
    }

    /// Removes and returns the minimum element (seam-generic; no growth involved).
    @inlinable
    public mutating func pop() -> S.Element {
        precondition(!isEmpty, "pop on an empty heap")
        column.prepareForMutation()
        let n = Int(count.underlying.rawValue)
        if n == 1 { return column.move(at: slot(0)) }
        let root = column.move(at: slot(0))
        let last = column.move(at: slot(n - 1))
        column.initialize(at: slot(0), to: last)
        siftDown(over: n - 1)
        return root
    }
}

// MARK: 3. Growth — written ONCE, allocation-GENERIC (heap AND small columns)

extension __Heap where S: ~Copyable {

    /// Creates an empty heap on any growable linear column.
    @inlinable
    public init<E: ~Copyable, Resource: Memory.Growable & ~Copyable>(
        minimumCapacity: Index<E>.Count = Index<E>.Count(4)
    ) where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        self.init(column: S(minimumCapacity: minimumCapacity))
    }

    /// Inserts an element (grow-if-full rides the column's own append).
    @inlinable
    public mutating func push<E: ~Copyable & Comparison.`Protocol`, Resource: Memory.Growable & ~Copyable>(
        _ element: consuming E
    ) where S == Buffer<Storage<Memory.Allocator<Resource>>.Contiguous<E>>.Linear {
        column.append(element)
        siftUp(from: Int(count.underlying.rawValue) - 1)
    }
}

// MARK: 4. The front doors — canonical + variants as typealiases

/// CANONICAL: the growable heap-allocated min priority queue.
public typealias Heap<E: ~Copyable> =
    __Heap<Buffer<Storage<Memory.Allocator<Memory.Heap>>.Contiguous<E>>.Linear>

extension __Heap where S: ~Copyable, S: Store.`Protocol` {
    /// VARIANT: small — inline budget `n` bytes, spilling to heap (the `Memory.Small` column).
    public typealias Small<let n: Int> =
        __Heap<Buffer<Storage<Memory.Allocator<Memory.Small<n>>>.Contiguous<S.Element>>.Linear>
}
