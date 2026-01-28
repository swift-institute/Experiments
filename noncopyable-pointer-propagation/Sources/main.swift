// MARK: - ~Copyable Constraint Poisoning Test
// Purpose: Test if constraint poisoning occurs
// Status: BUG REPRODUCED
// Date: 2026-01-22
// Toolchain: Swift 6.2

// STUB - Code needs to be recreated
// This experiment demonstrated constraint poisoning where adding
// `extension Container: Sequence where Element: Copyable`
// causes stored properties like `UnsafeMutablePointer<Element>`
// to fail with "type 'Element' does not conform to 'Copyable'"

print("noncopyable-pointer-propagation: STUB")
