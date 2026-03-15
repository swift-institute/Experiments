// MARK: - Trait-Gated Snapshot Strategy
// Purpose: Verify that a trait-gated dependency on test-primitives allows
//          the Test Support module to provide snapshot strategies
// Hypothesis: When "Snapshot Testing" trait is enabled, this file compiles
//             and the .rendered strategy is available to consumers
//
// Result: CONFIRMED - #if SNAPSHOT_TESTING activates when trait enabled; strategy compiles
// Date: 2026-03-14

#if SNAPSHOT_TESTING
import TestSnapshotPrimitives

extension SnapshotStrategy where Value: Rendering.View, Format == String {
    public static var rendered: SnapshotStrategy<Value, String> {
        SnapshotStrategy<Value, String> { value in
            value.body
        }
    }
}
#endif
