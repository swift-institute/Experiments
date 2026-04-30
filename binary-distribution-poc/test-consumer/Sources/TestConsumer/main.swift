import Tagged_Primitives

// Define a tag type for user IDs
enum UserIDTag {}
typealias UserID = Tagged<UserIDTag, Int>

// Define a tag type for order IDs
enum OrderIDTag {}
typealias OrderID = Tagged<OrderIDTag, Int>

// Create some tagged values
let userId: UserID = Tagged(42)
let orderId: OrderID = Tagged(100)

print("User ID: \(userId.rawValue)")
print("Order ID: \(orderId.rawValue)")

// Test comparison
let anotherUserId: UserID = Tagged(42)
print("User IDs equal: \(userId == anotherUserId)")

// Test map
let doubledUserId = userId.map { $0 * 2 }
print("Doubled User ID: \(doubledUserId.rawValue)")

print("\n✓ POC PASSED - XCFramework binary consumption works!")
