// MARK: - ADT variant front-doors — alias-based variant spelling over one generic carrier
//
// Purpose:   Validate the mechanism the tower re-derivation proposes for the variant
//            algebra: ONE bound-free generic carrier (`__Vector<S: ~Copyable>`) whose
//            API is written once as conditional capability extensions, with the
//            CANONICAL type and every ALLOCATION VARIANT provided as generic
//            typealiases — the canonical as a top-level alias pinning the default
//            column, variants as CONSTRAINED NESTED aliases that re-parameterize the
//            column while inheriting Element from the family member they are named on
//            (`Vector<Int>.Small<8>`).
// Hypothesis: (1) a nested alias whose body references `S.Element` under a seam
//            constraint resolves; (2) alias-chained spelling `Vector<Int>.Small<8>`
//            resolves through the canonical alias; (3) column-pinned inits (incl. a
//            value-generic pin) are callable through the aliases; (4) the whole chain
//            carries a ~Copyable Element; (5) it all works cross-module.
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101), macOS 26 (arm64), Xcode 26.6
// Platform:  macOS 26 (arm64)
//
// Result:    CONFIRMED — all five hypotheses hold on 6.3.3, debug AND release, cross-module:
//   canonical `Vector<Int>` (top-level alias) ✓; variant `Vector<Int>.Small<8>` (constrained
//   nested alias, `S.Element` in the body, value-generic `let n`) ✓; pinned inits through the
//   alias chain (incl. the value-generic pin) ✓; ~Copyable Element end-to-end with in-place
//   `_modify` mutation (`Vector<MO>.Small<4>`, m[0].x += 1) ✓; generic algorithm over any
//   column ✓. Output: "canonical: count=3 v[2]=30 · small: count=2 s[1]=42 · moSmall: count=1
//   m[0].x=8 · generic: total(v)=60 total(s)=43" (identical debug/release).
//   SIL gate: 0 `witness_method` in the ENTIRE -O cross-module client SIL — the alias chain
//   specializes completely. A variant therefore costs ONE typealias line (+ its column, if new).
//   NOTE: this exact alias family was INEXPRESSIBLE on 6.3.2 — the namespaced value-generic
//   typealias SIGSEGV (re-probed FIXED in Experiments/adt-tower-walls Probes p1b/p2b).
// Date:      2026-07-02

// MARK: The seam (Store.Protocol-shaped, reduced)

public protocol Seam: ~Copyable {
    associatedtype Element: ~Copyable
    var count: Int { get }
    subscript(_ i: Int) -> Element { get set }
    mutating func append(_ element: consuming Element)
}

// MARK: Two synthetic columns (heap-growable; inline-budgeted "small")

public struct HeapCol<E: ~Copyable>: ~Copyable, Seam {
    public typealias Element = E
    var base: UnsafeMutablePointer<E>
    public private(set) var count: Int = 0
    var capacity: Int
    public init(minimumCapacity: Int = 4) {
        capacity = Swift.max(minimumCapacity, 1)
        base = .allocate(capacity: capacity)
    }
    public subscript(_ i: Int) -> E {
        _read { yield base[i] }
        _modify { yield &base[i] }
    }
    public mutating func append(_ element: consuming E) {
        if count == capacity {
            let bigger = UnsafeMutablePointer<E>.allocate(capacity: capacity * 2)
            bigger.moveInitialize(from: base, count: count)
            base.deallocate()
            base = bigger
            capacity *= 2
        }
        (base + count).initialize(to: element)
        count += 1
    }
    deinit {
        base.deinitialize(count: count)
        base.deallocate()
    }
}

/// Value-generic "small" column — inline budget `n` carried in the TYPE (no stored
/// capacity word), heap spill path elided (out of scope for the alias mechanism).
public struct SmallCol<E: ~Copyable, let n: Int>: ~Copyable, Seam {
    public typealias Element = E
    var base: UnsafeMutablePointer<E>
    public private(set) var count: Int = 0
    public init() { base = .allocate(capacity: n) }
    public subscript(_ i: Int) -> E {
        _read { yield base[i] }
        _modify { yield &base[i] }
    }
    public mutating func append(_ element: consuming E) {
        precondition(count < n, "small budget exceeded (spill path elided)")
        (base + count).initialize(to: element)
        count += 1
    }
    deinit {
        base.deinitialize(count: count)
        base.deallocate()
    }
}

// MARK: The carrier — thin, bound-free ([DS-025]-shaped)

public struct __Vector<S: ~Copyable>: ~Copyable {
    public var column: S
    public init(column: consuming S) { self.column = column }
}

extension __Vector: Copyable where S: Copyable {}

// The write-once API surface: capabilities by conditional extension over the seam.
extension __Vector where S: ~Copyable, S: Seam {
    public var count: Int { column.count }
    public var isEmpty: Bool { column.count == 0 }
    public subscript(_ i: Int) -> S.Element {
        _read { yield column[i] }
        _modify { yield &column[i] }
    }
    public mutating func append(_ element: consuming S.Element) {
        column.append(element)
    }
}

// Column-pinned construction (the Array<S> idiom).
extension __Vector where S: ~Copyable {
    public init<E: ~Copyable>(minimumCapacity: Int = 4) where S == HeapCol<E> {
        self.init(column: HeapCol(minimumCapacity: minimumCapacity))
    }
    public init<E: ~Copyable, let n: Int>() where S == SmallCol<E, n> {
        self.init(column: SmallCol())
    }
}

// MARK: The front doors

/// CANONICAL: a top-level generic alias pinning the default (heap) column.
public typealias Vector<E: ~Copyable> = __Vector<HeapCol<E>>

/// VARIANTS: constrained nested aliases re-parameterizing the column, Element
/// inherited from the family member the alias is named on. Spelled
/// `Vector<Int>.Small<8>` — the outer generic arguments are supplied by the
/// canonical alias, so the variant costs ONE LINE and zero forwarding.
extension __Vector where S: ~Copyable, S: Seam {
    public typealias Small<let n: Int> = __Vector<SmallCol<S.Element, n>>
}
