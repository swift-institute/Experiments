// P4 — bespoke vending struct: a custom nested ~Escapable `Borrowed` view type
// that points at the iterator's stored output and is vended per step. This is
// the path the Ownership.Borrow doc itself points ~Escapable conformers to
// ("typical ~Escapable conformers declare their own nested Borrowed struct").
//
// The iterator owns the backing storage (a heap slot holding an Int). The
// vended `Borrowed` is ~Escapable, points into that storage, and is lifetime-
// tied to self. No UnsafeMutablePointer<~Escapable> and no Ownership.Borrow
// read-back are involved — sidesteps both W1 and W2 by construction.

// The ~Escapable output view: a borrowed window over the iterator's slot.
struct Borrowed: ~Escapable {
    let p: UnsafePointer<Int>
    @_lifetime(borrow owner)
    init(_ p: UnsafePointer<Int>, borrowing owner: borrowing some ~Copyable & ~Escapable) {
        self.p = p
    }
    var value: Int { unsafe p.pointee }
}

struct Iter: ~Copyable, ~Escapable {
    let slot: UnsafeMutablePointer<Int>   // Int IS Escapable — slot is legal
    var index: Int

    @_lifetime(immortal)
    init() {
        slot = UnsafeMutablePointer<Int>.allocate(capacity: 1)
        slot.initialize(to: 0)
        index = 0
    }

    consuming func finish() {
        slot.deinitialize(count: 1)
        slot.deallocate()
    }

    // Lend a ~Escapable Borrowed view tied to self.
    @_lifetime(&self)
    mutating func next() -> Borrowed? {
        guard index < 3 else { return nil }
        slot.pointee = index * 10
        index += 1
        return Borrowed(UnsafePointer(slot), borrowing: self)
    }
}
