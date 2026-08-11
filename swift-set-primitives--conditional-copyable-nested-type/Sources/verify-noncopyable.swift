// Verify that Container<MoveOnlyToken>.Ordered cannot be copied
//
// Build with: swift build -Xswiftc -DVERIFY_NONCOPYABLE
// Expected: FAILS with "'copy' cannot be applied to noncopyable types"

#if VERIFY_NONCOPYABLE
func verifyCopyFails() {
    let ordered = Container<MoveOnlyToken>.Ordered()
    let copy = copy ordered  // ❌ Should fail
    _ = copy
    _ = ordered
}
#endif
