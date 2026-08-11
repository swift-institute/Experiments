// Verify that HashTable<MoveOnly> cannot be copied
//
// Build with: swift build -Xswiftc -DVERIFY_NONCOPYABLE
// Expected: FAILS with "'copy' cannot be applied to noncopyable types"
//
// This verifies that HashTable<~Copyable> is indeed ~Copyable.

#if VERIFY_NONCOPYABLE
func verifyCopyFails() {
    let table = HashTable<MoveOnlyResource>()
    let copy = copy table  // ❌ Fails: 'copy' cannot be applied to noncopyable types
    _ = copy
    _ = table
}
#endif
