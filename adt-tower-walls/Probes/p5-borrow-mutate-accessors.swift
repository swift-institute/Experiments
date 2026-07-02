// p5: `borrow`/`mutate` accessors (BorrowAndMutateAccessors). Expect: probe with/without flag.
// Result (Apple Swift 6.3.3, 2026-07-02): STILL PRESENT — bare: 'borrow accessor requires -enable-experimental-feature BorrowAndMutateAccessors'; with flag: 'cannot be enabled in production compiler'. Unavailable on 6.3.3.
struct BX: ~Copyable {
    var _x: Int = 0
    var x: Int {
        borrow { yield _x }
        mutate { yield &_x }
    }
}
var b = BX()
b.x += 1
print("p5 ok:", b.x)
