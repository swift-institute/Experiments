// SUPERSEDED: See noncopyable-constraint-behavior
// MARK: - ~Copyable Multifile Poisoning
// Purpose: File organization within the same module does NOT prevent poisoning
// Status: CONFIRMED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — Sequence inherits Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
// Revalidated: Swift 6.3.1 (2026-04-17) — STILL PRESENT
//
// Structure:
//   Base.swift         — Slab<Element: ~Copyable> with UnsafeMutablePointer storage
//   Conformance.swift  — conditional Sequence conformance (where Element: Copyable)
//   main.swift         — instantiation with non-Copyable element
//
// Expected: Compiler errors on Slab's stored properties despite file separation

struct Token: ~Copyable {
    var id: Int
}

// This should compile but fails due to poisoning from Conformance.swift
var slab = Slab<Token>(capacity: 16)
print("Slab created: capacity = \(slab.capacity)")
