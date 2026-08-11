// ===----------------------------------------------------------------------===//
//
// Syntax Showcase — Global Configuration
//
// Demonstrates how to configure snapshot recording and test
// execution at the global level via a custom entry point.
//
// ===----------------------------------------------------------------------===//

// MARK: - Option A: Environment Variable (zero code)
//
// Set SWIFT_SNAPSHOT_RECORD before running tests:
//
//   SWIFT_SNAPSHOT_RECORD=all swift test        # Record everything
//   SWIFT_SNAPSHOT_RECORD=never swift test      # CI mode — compare only
//   SWIFT_SNAPSHOT_RECORD=missing swift test    # Record new, compare existing
//   SWIFT_SNAPSHOT_RECORD=failed swift test     # Record failures for inspection

// MARK: - Option B: Programmatic Entry Point
//
// Override the test runner entry point to set snapshot recording
// for the entire test suite:
//
// ```swift
// import Testing
//
// @main
// struct TestRunner {
//     static func main() async {
//         await Test.Snapshot.withConfiguration(
//             .init(recording: .never)    // CI: never record, only compare
//         ) {
//             await Testing.main()
//         }
//     }
// }
// ```

// MARK: - Option C: Per-Type Configuration via #Tests
//
// Each type can override the recording mode independently:
//
// ```swift
// extension StableAPI {
//     #Tests(snapshots: .init(recording: .never))    // Locked down
// }
//
// extension NewFeature {
//     #Tests(snapshots: .init(recording: .all))      // Under active development
// }
//
// extension MatureType {
//     #Tests                                          // Default: .missing
// }
// ```

// MARK: - Recording Mode Reference
//
// ┌──────────┬──────────────┬───────────┬───────────────┐
// │ Mode     │ No Reference │ Match     │ Mismatch      │
// ├──────────┼──────────────┼───────────┼───────────────┤
// │ .never   │ Fail         │ Pass      │ Fail          │
// │ .missing │ Record+Pass  │ Pass      │ Fail          │
// │ .failed  │ Record+Pass  │ Pass      │ Record+Fail   │
// │ .all     │ Record+Pass  │ Record+Ok │ Record+Ok     │
// └──────────┴──────────────┴───────────┴───────────────┘
