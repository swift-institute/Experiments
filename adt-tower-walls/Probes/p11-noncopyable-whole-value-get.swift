// p11: whole-value read of a ~Copyable element through a protocol `{ get set }` requirement
// Result (Apple Swift 6.3.3, 2026-07-02): Sema ACCEPTS under -typecheck; the gate is at SIL — see p11b.
// from a BORROWED container. Expect: ERROR (cannot move/copy out of a borrow).
public protocol Seam11: ~Copyable {
    associatedtype Element: ~Copyable
    subscript(_ slot: Int) -> Element { get set }
}
public struct MO11: ~Copyable { public var v: Int }
func takeWhole<S: Seam11 & ~Copyable>(_ s: borrowing S) -> S.Element where S.Element == MO11 {
    s[0]
}
print("p11 compiled (unexpected)")
