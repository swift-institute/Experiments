// MARK: - ~Copyable Cross-Module Propagation
// Purpose: Test ~Copyable constraint propagation across module boundaries
// Status: INVESTIGATION (2026-01-20, Swift 6.0)
// Revalidation: FIXED in Swift 6.2.4 — cross-module ~Copyable works (2026-03-10)
// Result: CONFIRMED — cross-module ~Copyable constraint propagation works in Swift 6.2.4
// Origin: noncopyable-cross-module-propagation
//
// Original structure:
//   Sources/Lib/Container.swift                         — library module with Container<Element: ~Copyable>
//   Sources/noncopyable-cross-module-propagation/main.swift — consumer using Container<LocalResource>
//
// The library code is in Sources/CrossModuleLib/Container.swift in this consolidated package.

import CrossModuleLib

enum V08_CrossModulePropagation {

    struct LocalResource: ~Copyable {
        var value: Int
        init(_ v: Int) { value = v }
        deinit { print("  LocalResource(\(value)) deinitialized") }
    }

    static func run() {
        // Can we use Container<LocalResource> from another module?
        var c = CrossModuleLib.Container<LocalResource>(capacity: 4)
        c.append(LocalResource(1))
        c.append(LocalResource(2))
        print("Cross-module container count: \(c.count)")
        print("Cross-module propagation: BUILD SUCCEEDED")
        _ = c
    }
}
