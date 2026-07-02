// p4: the REFUTED V3 clause — re-suppressing ~Copyable on a nested associated type. Expect: ERROR.
// Result (Apple Swift 6.3.3, 2026-07-02): STILL PRESENT — 'cannot suppress ~Copyable on generic parameter B.Storage.Element defined in outer scope' (V3 stays refuted).
public protocol StoreSeam2: ~Copyable { associatedtype Element: ~Copyable }
public protocol BufSeam2: ~Copyable { associatedtype Storage: ~Copyable }
public struct AD<B: ~Copyable>: ~Copyable { public init() {} }
extension AD where B: ~Copyable, B: BufSeam2, B.Storage: StoreSeam2, B.Storage.Element: ~Copyable {
    public var deep: Int { 0 }
}
print("p4 compiled (unexpected)")
