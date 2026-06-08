/// A generational slab — O(1) insert/remove + use-after-free detection — over
/// slot-enum storage, with **no custom `deinit`**.
///
/// Occupancy, validity, and the free-list live in a parallel **trivial**
/// (`BitwiseCopyable`) `Meta` array (generation counter + free-list link); the
/// slot-enum holds only the value, so the `~Copyable` payload's *automatic*
/// teardown does the cleanup on `remove`/drop. The slot-enum is **never
/// borrow-peeked** — `if case .occupied = values[i]` on a `~Copyable` `InlineArray`
/// subscript does not compile (*"borrowed and cannot be consumed"*) — so occupancy
/// is read from `Meta` (the standard slot-map side-channel; this is the one real
/// ergonomic tax of the approach, not a blocker).
public struct Handle: Hashable, Sendable {
    public let index: UInt32
    public let generation: UInt32
}

struct Meta: Sendable {
    var generation: UInt32
    var next: UInt32
}

public struct Slab<Element: ~Copyable, let N: Int>: ~Copyable {
    var values: InlineArray<N, Slot<Element>>   // .empty | .occupied(E) — auto-cleans on drop
    var meta: InlineArray<N, Meta>              // generation + free-list link (trivial)
    var freeHead: UInt32
    public private(set) var count: Int

    public init() {
        values = InlineArray<N, Slot<Element>> { _ in .empty }
        meta = InlineArray<N, Meta> { i in Meta(generation: 0, next: UInt32(i + 1)) }
        freeHead = 0
        count = 0
    }

    public var isFull: Bool { freeHead >= UInt32(N) }

    /// Validity/occupancy read entirely from the trivial `Meta` side-array.
    public func isValid(_ h: Handle) -> Bool {
        Int(h.index) < N && meta[Int(h.index)].generation == h.generation
    }

    public mutating func insert(_ value: consuming Element) -> Handle {
        precondition(!isFull, "Slab full")
        let i = Int(freeHead)
        freeHead = meta[i].next
        meta[i].generation &+= 1
        values[i] = .occupied(value)            // consumes value; old .empty drops trivially
        count += 1
        return Handle(index: UInt32(i), generation: meta[i].generation)
    }

    /// Drop-on-remove: the element's `deinit` fires in place. Returns false for a stale handle.
    @discardableResult
    public mutating func remove(_ h: Handle) -> Bool {
        guard isValid(h) else { return false }
        values[Int(h.index)] = .empty           // occupied element drops → deinit fires HERE
        recycle(Int(h.index))
        return true
    }

    /// Move-OUT: take the `~Copyable` element out of the slot and **return** it — the
    /// `Store.Protocol.move(at:)` path (every discipline's `remove`/`move` routes here).
    /// Realized with stdlib `swap` on the `InlineArray` subscript: no copy, no custom `deinit`.
    public mutating func move(_ h: Handle) -> Element {
        precondition(isValid(h), "stale handle")
        let i = Int(h.index)
        var taken = Slot<Element>.empty
        swap(&values[i], &taken)                // values[i] ← .empty; taken ← old .occupied(E)
        recycle(i)
        switch consume taken {
        case .occupied(let e): return e
        case .empty: fatalError("invariant: a valid handle implies an occupied slot")
        }
    }

    private mutating func recycle(_ i: Int) {
        meta[i].generation &+= 1                 // invalidate outstanding handles to this slot
        meta[i].next = freeHead
        freeHead = UInt32(i)
        count -= 1
    }
}

extension Slab: Copyable where Element: Copyable {}
