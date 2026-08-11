// ===----------------------------------------------------------------------===//
// Main: Test driver - testing both same-module and cross-module
// ===----------------------------------------------------------------------===//

import LibraryA
import LibraryB

// Test with Copyable type
let inner1 = Outer<Int>.Inner(innerValue: 42)
print("Inner value: \(inner1.innerValue)")
print("doSomething: \(inner1.doSomething())")

// Same-module functions
print("sameModuleUseInner: \(sameModuleUseInner(inner: inner1))")
print("sameModulePlus: \(sameModulePlus(lhs: inner1, rhs: 10))")

// Cross-module functions
print("useInner (cross-module): \(useInner(inner: inner1))")
print("crossModuleMethod: \(inner1.crossModuleMethod())")
print("operator + (cross-module): \(inner1 + 10)")

print("All tests passed!")
