// p12: stdlib InlineArray with ~Copyable element having a deinit — do deinits fire on drop? (the literal #86652 title shape)
// Result (Apple Swift 6.3.3, 2026-07-02): PASSES debug AND -O — 2/2 deinits for stdlib InlineArray with a same-file ~Copyable element.
struct NCx: ~Copyable {
    let v: Int
    init(_ v: Int) { self.v = v }
    deinit { Counter.n += 1 }
}
enum Counter { nonisolated(unsafe) static var n = 0 }
do {
    let a = InlineArray<2, NCx> { i in NCx(i) }
    _ = a
}
print("p12: deinits=\(Counter.n) (expect 2 if clean)")
