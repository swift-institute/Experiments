// MARK: - Section-Based Test Discovery Verification
// Purpose: Determine why section-based discovery finds 0 tests in the
//          syntax-showcase. Four hypotheses tested:
//
//   H1:  hasFeature(SymbolLinkageMarkers) evaluates to false (without explicit enablement)
//   H1b: compiler(>=6.3) evaluates to false — Apple gates @section/@used behind 6.3
//   H2a: @section/@used (stable, 6.3) — not available in 6.2
//   H2b: @_section/@_used (underscored, experimental) — recognized but non-functional in 6.2
//
// Toolchain: Swift 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Section-based discovery is impossible on Swift 6.2.
//
//   H1:  CONFIRMED — hasFeature(SymbolLinkageMarkers) = false by default.
//         Evaluates to true only with .enableExperimentalFeature("SymbolLinkageMarkers").
//   H1b: CONFIRMED — compiler(>=6.3) = false. Our toolchain is 6.2.4.
//         Apple's swift-testing gates @section/@used behind #if compiler(>=6.3).
//   H2a: CONFIRMED — @section/@used (non-underscored) produce compile errors in 6.2:
//         "struct 'section' cannot be used as an attribute"
//         "unknown attribute 'used'"
//   H2b: CONFIRMED — @_section/@_used (underscored) are recognized when
//         SymbolLinkageMarkers is enabled, but EVERY variable declaration fails:
//         "global variable must be a compile-time constant to use @_section attribute"
//         This includes: UInt64 literals, tuples, struct inits, _const-annotated vars.
//         The compile-time constant evaluator needed for @_section does not exist in 6.2.
//
// Conclusion: Section placement requires Swift 6.3+. On 6.2, the @Test macro's
//             section record emission is dead code. The XCTest bridge (Option A)
//             is the only viable approach until the toolchain is upgraded.
//
// Date: 2026-03-01

import MachO

// ============================================================================
// MARK: - H1: hasFeature(SymbolLinkageMarkers)
// Result: CONFIRMED — NOT AVAILABLE (without explicit enablement in Package.swift)
// ============================================================================

#if hasFeature(SymbolLinkageMarkers)
let h1_result = "AVAILABLE (Package.swift has .enableExperimentalFeature)"
#else
let h1_result = "NOT AVAILABLE"
#endif
print("H1: hasFeature(SymbolLinkageMarkers) = \(h1_result)")

// ============================================================================
// MARK: - H1b: compiler(>=6.3)
// Result: CONFIRMED — 6.2.x, below 6.3 threshold
// ============================================================================

#if compiler(>=6.3)
let h1b_result = "YES (6.3+)"
#elseif compiler(>=6.2)
let h1b_result = "NO (6.2.x — below 6.3 threshold)"
#else
let h1b_result = "NO (below 6.2)"
#endif
print("H1b: compiler(>=6.3) = \(h1b_result)")

// ============================================================================
// MARK: - H2a & H2b: @section/@used and @_section/@_used
// These tests CANNOT be compiled — they are documented as compile errors above.
//
// H2a: @section("...") → "struct 'section' cannot be used as an attribute"
//      @used → "unknown attribute 'used'"
//
// H2b: @_section("...") → recognized, but:
//      @_used → recognized, but:
//      ANY variable (UInt64, tuple, struct) → "global variable must be a
//      compile-time constant to use @_section attribute"
//      Even with _const modifier → same error
//      Even with .enableExperimentalFeature("CompileTimeConst") → same error
// ============================================================================

print("H2a: @section/@used (stable) — NOT AVAILABLE in Swift 6.2 (compile error)")
print("H2b: @_section/@_used (underscored) — RECOGNIZED but NON-FUNCTIONAL")
print("     Every variable rejected: 'must be a compile-time constant'")

// ============================================================================
// MARK: - H3: Section Scanning (for reference — scans existing images)
// Result: No records from our code (expected, given H2 results).
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         May find Apple runtime records in system images.
// ============================================================================

func scanTestSections() -> Int {
    let imageCount = _dyld_image_count()
    var totalRecords = 0

    for i in 0..<imageCount {
        guard let header = _dyld_get_image_header(i) else { continue }

        var size: UInt = 0
        header.withMemoryRebound(to: mach_header_64.self, capacity: 1) { header64 in
            if let _ = getsectiondata(header64, "__DATA_CONST", "__swift5_tests", &size), size > 0 {
                let imageName = String(cString: _dyld_get_image_name(i))
                let shortName = imageName.split(separator: "/").last.map(String.init) ?? imageName
                print("H3: Found section in image '\(shortName)': \(size) bytes")
                totalRecords += 1
            }
        }
    }

    return totalRecords
}

let totalRecords = scanTestSections()
if totalRecords == 0 {
    print("H3: No __swift5_tests sections found in any loaded image")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("")
print("=== RESULTS ===")
print("H1  (SymbolLinkageMarkers default): \(h1_result)")
print("H1b (compiler>=6.3):                \(h1b_result)")
print("H2a (@section/@used stable):        NOT AVAILABLE — compile error in 6.2")
print("H2b (@_section/@_used underscored): RECOGNIZED but NON-FUNCTIONAL — no compile-time const support")
print("")
print("CONCLUSION: Section-based test discovery requires Swift 6.3+.")
print("            XCTest bridge is the only viable approach on 6.2.")
