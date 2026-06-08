/// The OUT-OF-LINE (heap-backed) analog of `Slab` — the **BASE-path** shape that
/// `Buffer.Linked` / `Buffer.Arena` reach today via `Storage.Pool` / `Storage.Arena`.
///
/// Models `Storage.Contiguous<Memory.Heap<Slot<Element>>>`: a class-backed buffer of
/// `Slot<Element>` whose backing `deinit` cleans each slot (`.occupied` tears down its
/// payload; `.empty` is a no-op) — exactly `Memory.Heap`'s **existing** element-cleanup
/// oracle (no change to `Memory.Heap` needed). Two consequences:
///   • **No Wall 1** — the cleanup lives in the backing `class` (unconditionally able to
///     `deinit`), not on a conditionally-`Copyable` struct.
///   • **No occupancy ledger needed at the Memory leaf** — `Slot` carries occupancy
///     in-band, so `Memory.Heap` treats it as a dense `[Slot]` and cleans all N.
///
/// Free-list + generation (the allocation/occupancy discipline = **ROLE-2**) live HERE,
/// at the Buffer-level type — NOT in a raw `Memory.Pool`/`Memory.Arena` allocator.
/// `~Copyable`-only (uniquely owned); the conditional-`Copyable` + CoW story is proven
/// separately by the inline `Slab` and the existing `Storage.Contiguous<Memory.Heap>`.
public struct HeapSlab<Element: ~Copyable>: ~Copyable {
    final class Backing {
        let capacity: Int
        let slots: UnsafeMutablePointer<Slot<Element>>
        let meta: UnsafeMutablePointer<Meta>
        init(capacity: Int) {
            self.capacity = capacity
            slots = .allocate(capacity: capacity)
            meta = .allocate(capacity: capacity)
            for i in 0..<capacity {
                (slots + i).initialize(to: .empty)
                (meta + i).initialize(to: Meta(generation: 0, next: UInt32(i + 1)))
            }
        }
        deinit {
            for i in 0..<capacity { (slots + i).deinitialize(count: 1) }  // each Slot self-cleans
            slots.deallocate()
            meta.deallocate()
        }
    }

    var backing: Backing
    var freeHead: UInt32
    public private(set) var count: Int

    public init(capacity: Int) {
        backing = Backing(capacity: capacity)
        freeHead = 0
        count = 0
    }

    public var isFull: Bool { freeHead >= UInt32(backing.capacity) }

    public func isValid(_ h: Handle) -> Bool {
        Int(h.index) < backing.capacity && backing.meta[Int(h.index)].generation == h.generation
    }

    public mutating func insert(_ value: consuming Element) -> Handle {
        precondition(!isFull, "HeapSlab full")
        let i = Int(freeHead)
        freeHead = backing.meta[i].next
        backing.meta[i].generation &+= 1
        (backing.slots + i).pointee = .occupied(value)
        count += 1
        return Handle(index: UInt32(i), generation: backing.meta[i].generation)
    }

    /// Move-OUT (the `Store.Protocol.move(at:)` path): take the element out, leave `.empty`, return it.
    public mutating func move(_ h: Handle) -> Element {
        precondition(isValid(h), "stale handle")
        let i = Int(h.index)
        let taken = (backing.slots + i).move()          // moves Slot out → slot uninitialized
        (backing.slots + i).initialize(to: .empty)      // re-establish .empty
        backing.meta[i].generation &+= 1
        backing.meta[i].next = freeHead
        freeHead = UInt32(i)
        count -= 1
        switch consume taken {
        case .occupied(let e): return e
        case .empty: fatalError("invariant: a valid handle implies an occupied slot")
        }
    }
}
