// p8b: fixed-size field AFTER the @_rawLayout storage (the LLVM-verifier-crash ordering). Expect: probe.
// Result (Apple Swift 6.3.3, 2026-07-02): FIXED in this reduction — fixed-size field AFTER  storage compiles+runs at -O.
@_rawLayout(likeArrayOf: Int, count: 4)
struct RawCells2: ~Copyable { init() {} }
struct After: ~Copyable {
    var cells: RawCells2
    var tail: Int
    init() { cells = RawCells2(); tail = 0 }
}
var a = After()
a.tail = 7
print("p8b ok:", a.tail)
