// MARK: - ~Copyable Constraint Poisoning (Multi-file)
// Purpose: Test whether file-level separation prevents constraint poisoning
// Status: BUG REPRODUCED (2026-01-22, Swift 6.2)
// Revalidation: STILL PRESENT in Swift 6.2.4 — file separation doesn't prevent Sequence Copyable requirement (2026-03-10)
// Revalidated: Swift 6.3 (2026-03-26) — STILL PRESENT
//
// Structure:
//   Container.swift           — base type with ~Copyable element
//   Container+Sequence.swift  — conditional Sequence conformance
//   main.swift                — test with non-Copyable element
//
// Expected: Poisoning persists despite file separation (module-level resolution)

struct Resource: ~Copyable {
    var value: Int
}

// This should compile but may fail due to poisoning from Container+Sequence.swift
var c = Container<Resource>(capacity: 4)
print("Container created: count = \(c.count)")
