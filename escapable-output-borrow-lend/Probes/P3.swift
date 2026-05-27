// P3 — SE-0519 stdlib borrow type. On the dev stdlib it ships as `Ref<Value>`
// (NOT `Borrow<Value>`), @frozen, ~Escapable, where Value: ~Copyable & ~Escapable,
// backed by Builtin.Borrow<Value> / Builtin.makeBorrow.
//
// Its `.value` read-back accessor is a `borrow` accessor gated behind
// $BorrowAndMutateAccessors (SE-0507) → requires -enable-experimental-feature
// BorrowAndMutateAccessors, which is production-gated (rejected on 6.3.2).
// It is @available(anyAppleOS 9999) = unreleased ABI.
//
// Compile with: -enable-experimental-feature BorrowAndMutateAccessors

struct NE: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

@available(macOS 9999, *)
func p3() {
    let n = NE(7)
    // Construct Ref over a ~Escapable value, then read back its .value.
    let r = Ref(n)              // init(_ value: borrowing Value)
    _ = r.value.value           // borrow-accessor read-back of a ~Escapable Value
}
