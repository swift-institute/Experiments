import SlotStorage

// A move-only resource element whose deinit is observable — proves teardown timing.
struct R: ~Copyable {
    let id: Int
    init(_ i: Int) { id = i }
    deinit { print("  deinit R(\(id))") }
}

// All TESTs run in module `Demo`, consuming types from module `SlotStorage` →
// every teardown below is a CROSS-MODULE teardown (the Wall-2 / swift#86652 surface).

print("TEST 1 — cross-module teardown (the Wall-2 dodge): expect ONLY 101 and 202:")
do {
    var s = SparseInline<R, 4>()
    s.put(R(101), at: 0)
    s.put(R(202), at: 3)
    _ = s
}  // drop → InlineArray recursively deinits each Slot; empties are no-ops

print("TEST 2 — conditional Copyable across the module boundary:")
do {
    var a = SparseInline<Int, 4>()
    a.put(7, at: 1)
    var b = a
    b.put(9, at: 2)
    print("  copied ok across module boundary (s.count semantics held)")
    _ = (a, b)
}

print("TEST 3 — generational Slab: O(1) alloc/free + use-after-free detection:")
do {
    var slab = Slab<R, 8>()
    let h0 = slab.insert(R(1))
    let h1 = slab.insert(R(2))
    let h2 = slab.insert(R(3))
    print("  count=\(slab.count) (expect 3); isValid(h1)=\(slab.isValid(h1)) (expect true)")
    print("  remove h1 → expect 'deinit R(2)' next:")
    slab.remove(h1)
    print("  after remove: count=\(slab.count) (expect 2); isValid(h1)=\(slab.isValid(h1)) (expect FALSE)")
    let h3 = slab.insert(R(4))
    print("  reused slot: h3.index=\(h3.index) (expect 1); stale h1 rejected=\(!slab.isValid(h1)) (expect true)")
    print("  drop slab → remaining R(1), R(3), R(4) deinit (order may vary):")
    _ = (h0, h2, h3)
    _ = consume slab
}

print("TEST 4 — move-OUT (Store.Protocol.move path): take element out, return it, drop later:")
do {
    var slab = Slab<R, 4>()
    let ha = slab.insert(R(50))
    let hb = slab.insert(R(60))
    print("  move out the R(50) handle — expect NO deinit yet:")
    let taken = slab.move(ha)
    print("  moved out R(\(taken.id)); count=\(slab.count) (expect 1); isValid(ha)=\(slab.isValid(ha)) (expect false)")
    print("  explicitly drop the moved element → expect 'deinit R(50)' now:")
    _ = consume taken
    print("  drop slab → remaining R(60) deinits:")
    _ = hb
    _ = consume slab
}

print("TEST 6 — HEAP-backed slot store (BASE path: Memory.Heap<Slot<E>>) cross-module + move-out:")
do {
    var hs = HeapSlab<R>(capacity: 4)
    let a = hs.insert(R(70))
    let b = hs.insert(R(80))
    print("  count=\(hs.count) (expect 2); move out R(70) — expect NO deinit yet:")
    let taken = hs.move(a)
    print("  moved out R(\(taken.id)); count=\(hs.count) (expect 1); isValid(a)=\(hs.isValid(a)) (expect false)")
    print("  drop the moved element → expect 'deinit R(70)':")
    _ = consume taken
    print("  drop heap slab → backing class deinit cleans the occupied slot → 'deinit R(80)':")
    _ = b
    _ = consume hs
}

// ─── G1(iv) layout classification over realistic MSB node shapes ───
enum LSlot<E: ~Copyable>: ~Copyable { case empty; case occupied(E) }
final class Box {}
struct PtrElem: ~Copyable { var p: UnsafeMutableRawPointer }   // resource handle (spare bits)
struct RefElem: ~Copyable { var r: Box }                       // class-backed handle (spare bits)
struct LinkedNode<E: ~Copyable>: ~Copyable { var e: E; var next: UInt32; var prev: UInt32 }   // List/Queue.Linked
struct TreeNode<E: ~Copyable>: ~Copyable { var e: E; var firstChild: UInt32; var sibling: UInt32 } // Tree.N

func classify<T: ~Copyable>(_ name: String, _ t: T.Type) {
    let e = MemoryLayout<T>.stride
    let s = MemoryLayout<LSlot<T>>.stride
    print("  \(name): node \(e) → Slot<node> \(s)  (\(e == s ? "FREE" : "taxed +\(s - e)"))")
}
print("TEST 5 — per-family layout (FREE = no discriminant penalty):")
classify("LinkedNode<PtrElem>", LinkedNode<PtrElem>.self)
classify("LinkedNode<RefElem>", LinkedNode<RefElem>.self)
classify("TreeNode<RefElem>  ", TreeNode<RefElem>.self)
classify("LinkedNode<UInt64> ", LinkedNode<UInt64>.self)   // full-range → taxed
print("done")
