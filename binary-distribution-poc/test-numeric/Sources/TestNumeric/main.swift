import Numeric_Primitives
import Tagged_Primitives  // Should be accessible since it's bundled

// Test Numeric.Rounding enum
let rounding: Numeric.Rounding = .down
print("Rounding mode: \(rounding)")

let rounding2: Numeric.Rounding = .even
print("Rounding mode 2: \(rounding2)")

// Test Tagged_Primitives (the dependency)
enum UserIDTag {}
typealias UserID = Tagged<UserIDTag, Int>

let userId: UserID = Tagged(123)
print("User ID: \(userId.rawValue)")

print("\n✓ POC PASSED - XCFramework with bundled dependency works!")
