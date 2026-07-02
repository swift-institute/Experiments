// p8c: Wall 3, generic-element form — @_rawLayout(likeArrayOf: Element) + class-ref field in one struct, -O.
// Result (Apple Swift 6.3.3, 2026-07-02): FIXED in this reduction — generic-element dual storage with class payload compiles+runs at -O.
final class Heap8<Element> { var xs: [Element] = [] }
@_rawLayout(likeArrayOf: Element, count: 4)
struct RawG<Element>: ~Copyable { init() {} }
struct DualG<Element>: ~Copyable {
    var heap: Heap8<Element>?
    var cells: RawG<Element>
    init() { heap = nil; cells = RawG() }
}
final class Payload { var p = 1 }
var d = DualG<Payload>()
d.heap = Heap8()
d.heap!.xs.append(Payload())
print("p8c ok:", d.heap!.xs[0].p)
