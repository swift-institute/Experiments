// P1 — baseline wall: UnsafeMutablePointer<T> where T: ~Escapable.
struct View: ~Escapable, ~Copyable {
    let p: UnsafePointer<Int>
    @_lifetime(borrow owner)
    init(_ p: UnsafePointer<Int>, borrowing owner: borrowing some ~Copyable & ~Escapable) {
        self.p = p
    }
}
func p1() {
    let slot = UnsafeMutablePointer<View>.allocate(capacity: 1)
    _ = slot
}
