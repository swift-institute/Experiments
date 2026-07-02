// MARK: - WallKit — the cross-package half of the adt-tower-walls probes
//
// Purpose:   Provide, in a SEPARATE PACKAGE, the types whose behavior the walls
//            key on cross-module: (a) a @_rawLayout inline store WITH the
//            [MEM-SAFE-027] _deinitWorkaround, (b) the same store WITHOUT it
//            (the naked swiftlang/swift#86652 shape), (c) a ~Copyable element
//            with a deinit counter, (d) the minimal Store.Protocol-shaped seam
//            (SeamP) + a heap conformer witnessing the element subscript with
//            _read/_modify — the protocol-vended-borrow linchpin.
//
// Toolchain: Apple Swift 6.3.3 (swiftlang-6.3.3.1.3), macOS 26 (arm64)
// Date:      2026-07-02

// MARK: Deinit accounting

public enum Probe {
    /// Single-threaded probe counter.
    nonisolated(unsafe) public static var deinitCount = 0
}

/// A noncopyable element whose deinit is observable.
public struct NC: ~Copyable {
    public var v: Int
    public init(_ v: Int) { self.v = v }
    deinit { Probe.deinitCount += 1 }
}

// MARK: Wall 2 targets — @_rawLayout inline stores (with / without the workaround)

/// Fixed-4 inline store WITH the `[MEM-SAFE-027]` `_deinitWorkaround` (the institute
/// substrate idiom: workaround FIRST, `@_rawLayout` storage LAST; deinit oracle
/// destroys the live prefix, base derived per access).
public struct Inline4W<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    var _deinitWorkaround: AnyObject? = nil

    @usableFromInline
    var count: Int = 0

    @_rawLayout(likeArrayOf: Element, count: 4)
    @usableFromInline
    struct _Raw: ~Copyable {
        @usableFromInline
        init() {}
    }

    @usableFromInline
    var _storage: _Raw

    public init() {
        self._deinitWorkaround = nil
        self.count = 0
        self._storage = _Raw()
    }

    public mutating func append(_ element: consuming Element) {
        precondition(count < 4, "full")
        let base = withUnsafeMutablePointer(to: &_storage) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)
        }
        (base + count).initialize(to: element)
        count += 1
    }

    deinit {
        if count > 0 {
            _ = withUnsafePointer(to: _storage) { raw in
                UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: count)
            }
        }
    }
}

/// The SAME store WITHOUT the workaround — the naked swiftlang/swift#86652 shape.
/// If Wall 2 persists on this toolchain, dropping a value of this type from
/// ANOTHER package skips the deinit (value witness misclassified trivial) and
/// the elements leak.
public struct Inline4N<Element: ~Copyable>: ~Copyable {
    @usableFromInline
    var count: Int = 0

    @_rawLayout(likeArrayOf: Element, count: 4)
    @usableFromInline
    struct _Raw: ~Copyable {
        @usableFromInline
        init() {}
    }

    @usableFromInline
    var _storage: _Raw

    public init() {
        self.count = 0
        self._storage = _Raw()
    }

    public mutating func append(_ element: consuming Element) {
        precondition(count < 4, "full")
        let base = withUnsafeMutablePointer(to: &_storage) {
            UnsafeMutableRawPointer($0).assumingMemoryBound(to: Element.self)
        }
        (base + count).initialize(to: element)
        count += 1
    }

    deinit {
        if count > 0 {
            _ = withUnsafePointer(to: _storage) { raw in
                UnsafeMutableRawPointer(mutating: UnsafeRawPointer(raw))
                    .assumingMemoryBound(to: Element.self)
                    .deinitialize(count: count)
            }
        }
    }
}

// MARK: The minimal seam (Store.Protocol-shaped) + a heap conformer

/// The 4-requirement element-store seam, mirroring `Store.Protocol`
/// (`__StoreProtocol`) in shape: capacity + `{ get set }` element subscript
/// (witnessed by `_read`/`_modify`) + the two init-state transitions.
public protocol SeamP: ~Copyable {
    associatedtype Element: ~Copyable
    var capacity: Int { get }
    subscript(_ slot: Int) -> Element { get set }
    mutating func initialize(at slot: Int, to element: consuming Element)
    mutating func move(at slot: Int) -> Element
}

/// Heap-backed conformer witnessing the subscript with `_read`/`_modify`
/// coroutines (a plain `get` cannot vend a `~Copyable` element by borrow).
public struct PtrStore<Element: ~Copyable>: ~Copyable, SeamP {
    @usableFromInline
    var base: UnsafeMutablePointer<Element>

    public let capacity: Int

    @usableFromInline
    var live: Int = 0

    public init(capacity: Int) {
        self.capacity = capacity
        self.base = .allocate(capacity: capacity)
    }

    public subscript(_ slot: Int) -> Element {
        _read { yield base[slot] }
        _modify { yield &base[slot] }
    }

    public mutating func initialize(at slot: Int, to element: consuming Element) {
        (base + slot).initialize(to: element)
        live = max(live, slot + 1)
    }

    public mutating func move(at slot: Int) -> Element {
        live -= 1
        return (base + slot).move()
    }

    deinit {
        base.deinitialize(count: live)
        base.deallocate()
    }
}
