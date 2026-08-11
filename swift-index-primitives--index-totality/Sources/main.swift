// Status: SUPERSEDED -- Property.View as protocol-extension pattern shipped in swift-index-primitives + swift-property-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// ===----------------------------------------------------------------------===//
// Experiment: Index Totality + Property.View as Protocol Requirement
// ===----------------------------------------------------------------------===//

print("========================================")
print("Index Totality Experiment")
print("========================================\n")

// Run the Property.View protocol test (two-protocol pattern)
testPropertyViewProtocol()

print("\n")

// Run protocol extension pattern test (THE SOLUTION)
testProtocolExtensionPattern()

print("\n========================================")
print("Experiment Complete")
print("========================================")
