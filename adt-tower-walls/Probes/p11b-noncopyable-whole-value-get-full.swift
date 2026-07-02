// p11b: FULL COMPILE — whole-value +1 read of a ~Copyable element through the protocol
// Result (Apple Swift 6.3.3, 2026-07-02): REJECTED at SIL — 'noncopyable s.subscript cannot be consumed…'. Borrow/mutate through the seam: yes; whole-value move-out: no. Sound.
// `{ get set }` requirement from a borrowed container. -typecheck passed (Sema OK);
// does SILGen/ownership checking reject, and where?
public protocol Seam11: ~Copyable {
    associatedtype Element: ~Copyable
    subscript(_ slot: Int) -> Element { get set }
}
public struct MO11: ~Copyable { public var v: Int; public init(_ v: Int) { self.v = v } }
public struct Store11: ~Copyable, Seam11 {
    var base: UnsafeMutablePointer<MO11>
    public typealias Element = MO11
    public init() { base = .allocate(capacity: 2); base.initialize(to: MO11(7)) }
    public subscript(_ slot: Int) -> MO11 {
        _read { yield base[slot] }
        _modify { yield &base[slot] }
    }
    deinit { base.deinitialize(count: 1); base.deallocate() }
}
func takeWhole<S: Seam11 & ~Copyable>(_ s: borrowing S) -> S.Element where S.Element == MO11 {
    s[0]
}
let st = Store11()
let e = takeWhole(st)
print("p11b compiled+ran (unexpected?):", e.v)
