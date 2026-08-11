// ===----------------------------------------------------------------------===//
// LibraryB: Cross-module consumer - testing with explicit where clause
// ===----------------------------------------------------------------------===//

public import LibraryA

// Test 1: Free function using Outer<T>.Inner with ~Copyable constraint
public func useInner<T: ~Copyable>(inner: Outer<T>.Inner) -> Int
where T: ~Copyable {
    inner.doSomething()
}

// Test 2: Extension on Outer.Inner
extension Outer.Inner where Element: ~Copyable {
    public func crossModuleMethod() -> Int {
        innerValue + 100
    }
}

// Test 3: Free function operator
public func + <T: ~Copyable>(lhs: Outer<T>.Inner, rhs: Int) -> Int
where T: ~Copyable {
    lhs.innerValue + rhs
}
