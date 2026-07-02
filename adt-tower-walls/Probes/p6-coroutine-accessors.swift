// p6: `read`/`modify` coroutine accessors + protocol requirement `{ read modify }` (CoroutineAccessors).
// Result (Apple Swift 6.3.3, 2026-07-02): MIXED — CoroutineAccessors flag IS accepted by the production compiler; struct read/modify parse; protocol requirements accept { read } and { read set } but NOT modify ('expected get, read, or set').
struct CX: ~Copyable {
    var _x: Int = 0
    var x: Int {
        read { yield _x }
        modify { yield &_x }
    }
}
protocol PX: ~Copyable {
    associatedtype E: ~Copyable
    subscript(i: Int) -> E { read modify }
}
var c = CX()
c.x += 1
print("p6 ok:", c.x)
