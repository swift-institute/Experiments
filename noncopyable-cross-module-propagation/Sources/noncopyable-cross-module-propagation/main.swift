// MARK: - ~Copyable Cross-Module Propagation
// Purpose: Test ~Copyable constraint propagation across module boundaries
// Status: INVESTIGATION (2026-01-20, Swift 6.0)
// Revalidation: FIXED in Swift 6.2.4 — cross-module ~Copyable works (2026-03-10)

import Lib

struct LocalResource: ~Copyable {
    var value: Int
    init(_ v: Int) { value = v }
    deinit { print("  LocalResource(\(value)) deinitialized") }
}

// Can we use Container<LocalResource> from another module?
var c = Container<LocalResource>(capacity: 4)
c.append(LocalResource(1))
c.append(LocalResource(2))
print("Cross-module container count: \(c.count)")
print("Cross-module propagation: BUILD SUCCEEDED")
