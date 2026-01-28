// MARK: - ~Copyable Inline Storage Deinit Bug
// Purpose: ~Copyable structs fail to call element deinitializers when destroyed
// Status: BUG REPRODUCED
// Date: 2026-01-20
// Toolchain: Swift 6.2

// STUB - Code needs to be recreated
// This experiment reproduced a Swift compiler bug where:
// - InlineArray<capacity, ...> with value generic parameter
// - ~Copyable struct containing only value-type properties
// - Cross-module boundary for element type
// - deinit that performs manual element cleanup
// Results in deinit NOT being called.
//
// Workaround: Add `var _deinitWorkaround: AnyObject? = nil`

print("noncopyable-inline-deinit: STUB")
