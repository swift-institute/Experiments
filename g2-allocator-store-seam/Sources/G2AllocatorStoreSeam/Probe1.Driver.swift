// ===----------------------------------------------------------------------===//
//
// Probe 1 — runtime driver. Exercises the Pool through BOTH surfaces (allocation
// + the Store seam) end-to-end, so "Pool fits Store cleanly" is empirical, not
// merely type-level. Returns a result the caller can assert on.
//
// ===----------------------------------------------------------------------===//

public import Index_Primitives
import Cardinal_Primitive
import Ordinal_Primitive
import Store_Protocol_Primitives

extension G2 {
    /// Drives `G2.Pool<Node>` through allocate → initialize → read → move → free,
    /// across a sparse interleaving (free slot 0 while slots 1,2 stay live), then
    /// lets `deinit` reclaim the survivors. Returns the ids read back, in order.
    ///
    /// If the Store seam genuinely supports sparse occupancy, this round-trips with
    /// no UB and the deinit deinitializes exactly slots 1 and 2.
    public static func drivePool() -> [Int] {
        var observed: [Int] = []
        var pool = G2.Pool<Node>(capacity: Index<Node>.Count(Cardinal(UInt(4))))

        // Allocate three slots; the free-list hands out 0, 1, 2.
        let s0 = pool.allocate()!
        let s1 = pool.allocate()!
        let s2 = pool.allocate()!

        // Initialize each via the Store seam (uninit → init).
        pool.initialize(at: s0, to: G2.Node(id: 100))
        pool.initialize(at: s1, to: G2.Node(id: 101))
        pool.initialize(at: s2, to: G2.Node(id: 102))

        // Read back through the Store subscript.
        observed.append(pool[s0].id)
        observed.append(pool[s1].id)
        observed.append(pool[s2].id)

        // Create SPARSITY: move slot 0 out (init → uninit) and return it to the
        // free-list. Slots 1 and 2 remain live and INTERSPERSED with the now-free 0.
        let taken = pool.move(at: s0)
        observed.append(taken.id)
        pool.free(s0)

        // Re-allocate: the free-list returns slot 0 again (LIFO). Initialize it anew.
        let s0b = pool.allocate()!
        pool.initialize(at: s0b, to: G2.Node(id: 200))
        observed.append(pool[s0b].id)

        // Leave slots 0(=200), 1(=101), 2(=102) live; slot 3 never allocated.
        // `deinit` must deinitialize EXACTLY the three live slots via the occupancy
        // oracle — the seam alone could not tell it which.
        return observed
    }
}
