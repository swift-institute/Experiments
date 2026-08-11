// ===----------------------------------------------------------------------===//
// Same-module consumer - with explicit where clause
// ===----------------------------------------------------------------------===//

// Test: Same function but in the SAME module as Outer
// Note: Using Outer<T>.Inner where T: ~Copyable
public func sameModuleUseInner<T: ~Copyable>(inner: Outer<T>.Inner) -> Int
where T: ~Copyable {  // Explicit constraint
    inner.doSomething()
}

// Test: Same operator but in the SAME module
public func sameModulePlus<T: ~Copyable>(lhs: Outer<T>.Inner, rhs: Int) -> Int
where T: ~Copyable {  // Explicit constraint
    lhs.innerValue + rhs
}
