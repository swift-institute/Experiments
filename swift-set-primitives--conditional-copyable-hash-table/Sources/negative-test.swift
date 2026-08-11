// ===----------------------------------------------------------------------===//
// Negative Test: Verify ~Copyable restriction works
// ===----------------------------------------------------------------------===//
//
// This file should NOT compile. Uncomment the lines to verify.
// ===----------------------------------------------------------------------===//

// Uncomment to test that copying ~Copyable HashTable fails:
/*
func testCopyFails() {
    struct MoveOnly: ~Copyable { var x: Int }
    var table = HashTable<MoveOnly>()
    let copy = table  // ❌ Should fail: cannot copy ~Copyable type
}
*/

// Uncomment to test that for-in on ~Copyable HashTable fails:
/*
func testForInFails() {
    struct MoveOnly: ~Copyable { var x: Int }
    var table = HashTable<MoveOnly>()
    for element in table {  // ❌ Should fail: no Sequence conformance
        print(element)
    }
}
*/

// Uncomment to test that copying ~Copyable OrderedSet fails:
/*
func testOrderedSetCopyFails() {
    struct MoveOnly: ~Copyable { var x: Int }
    var set = OrderedSet<MoveOnly>()
    let copy = set  // ❌ Should fail: cannot copy ~Copyable type
}
*/

// Uncomment to test that for-in on ~Copyable OrderedSet fails:
/*
func testOrderedSetForInFails() {
    struct MoveOnly: ~Copyable { var x: Int }
    var set = OrderedSet<MoveOnly>()
    for element in set {  // ❌ Should fail: no Sequence conformance
        print(element)
    }
}
*/
