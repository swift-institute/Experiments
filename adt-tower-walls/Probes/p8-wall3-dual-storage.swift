// p8: Wall 3 — struct with BOTH @_rawLayout storage and a reference-type field, release mode. Expect: probe IRGen.
// Result (Apple Swift 6.3.3, 2026-07-02): FIXED in this reduction —  + class-ref field compiles+runs at -O (needs -enable-experimental-feature RawLayout).
final class HeapBox { var x: Int = 0 }
@_rawLayout(likeArrayOf: Int, count: 4)
struct RawCells: ~Copyable { init() {} }
struct Dual: ~Copyable {
    var heap: HeapBox?
    var cells: RawCells
    init() { heap = nil; cells = RawCells() }
}
var d = Dual()
d.heap = HeapBox()
print("p8 ok")
